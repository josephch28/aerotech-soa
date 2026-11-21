import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/dashboard.dart';
import '../../models/json_util.dart';
import '../../services/reporte_service.dart';
import '../../utils/formatos.dart';
import '../../widgets/cargando.dart';
import '../../widgets/error_reintentar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Dashboard? _d;
  Object? _error;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final d = await ReporteService.dashboard();
      if (mounted) setState(() => _d = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Widget _kpi(IconData icono, String valor, String etiqueta, Color color) {
    return SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icono, color: color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(valor, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _tarjeta(String titulo, Widget hijo, {double alto = 260}) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            SizedBox(height: alto, child: hijo),
          ]),
        ),
      );

  Widget _graficoOcupacion(Dashboard d) {
    final datos = d.ocupacionPorVuelo;
    if (datos.isEmpty) return const Center(child: Text('Sin vuelos próximos'));
    final t = Theme.of(context);
    return BarChart(BarChartData(
      maxY: 100,
      alignment: BarChartAlignment.spaceAround,
      gridData: const FlGridData(drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, gi, rod, ri) {
            final v = datos[group.x];
            return BarTooltipItem('${v['codigo_vuelo']} · ${v['ruta']}\n${rod.toY.toStringAsFixed(1)} %', const TextStyle(color: Colors.white, fontSize: 12));
          },
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36, interval: 25, getTitlesWidget: (v, m) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 10)))),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (v, m) {
              final i = v.toInt();
              if (i < 0 || i >= datos.length) return const SizedBox.shrink();
              return Padding(padding: const EdgeInsets.only(top: 6), child: Text('${datos[i]['codigo_vuelo']}', style: const TextStyle(fontSize: 9)));
            },
          ),
        ),
      ),
      barGroups: [
        for (var i = 0; i < datos.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: numero(datos[i]['ocupacion']), width: 16, color: t.colorScheme.primary, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
          ]),
      ],
    ));
  }

  Widget _graficoReservas(Dashboard d) {
    final datos = d.reservasPorDia;
    if (datos.isEmpty) return const Center(child: Text('Aún no hay reservas en los últimos 14 días'));
    final t = Theme.of(context);
    final maxR = datos.map((e) => numero(e['reservas'])).fold<double>(1, (a, b) => b > a ? b : a);
    return LineChart(LineChartData(
      minY: 0,
      maxY: maxR + 1,
      gridData: const FlGridData(drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots.map((s) {
            final v = datos[s.x.toInt()];
            return LineTooltipItem('${Formatos.fecha(v['fecha'])}\n${entero(v['reservas'])} reservas · ${Formatos.moneda(numero(v['ingresos']))}', const TextStyle(color: Colors.white, fontSize: 12));
          }).toList(),
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: maxR <= 5 ? 1 : null, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)))),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            interval: 1,
            getTitlesWidget: (v, m) {
              final i = v.toInt();
              if (i < 0 || i >= datos.length || v != i.toDouble()) return const SizedBox.shrink();
              final f = DateTime.tryParse('${datos[i]['fecha']}');
              return Padding(padding: const EdgeInsets.only(top: 6), child: Text(f == null ? '' : '${f.day}/${f.month}', style: const TextStyle(fontSize: 9)));
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [for (var i = 0; i < datos.length; i++) FlSpot(i.toDouble(), numero(datos[i]['reservas']))],
          isCurved: false, // líneas rectas: la curva suavizada bajaba de 0 entre días con pocos datos
          color: t.colorScheme.primary,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: true, color: t.colorScheme.primary.withValues(alpha: 0.12)),
        ),
      ],
    ));
  }

  Widget _rutasTop(Dashboard d) {
    if (d.rutasTop.isEmpty) return const Center(child: Text('Sin datos'));
    final maxP = d.rutasTop.map((e) => numero(e['pasajeros'])).fold<double>(1, (a, b) => b > a ? b : a);
    return ListView(children: [
      for (var i = 0; i < d.rutasTop.length; i++)
        ListTile(
          dense: true,
          leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
          title: Text('${d.rutasTop[i]['ruta']}'),
          subtitle: LinearProgressIndicator(value: numero(d.rutasTop[i]['pasajeros']) / maxP, minHeight: 6, borderRadius: BorderRadius.circular(3)),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${entero(d.rutasTop[i]['pasajeros'])} pasajeros', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(Formatos.moneda(numero(d.rutasTop[i]['ingresos'])), style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _d == null) return ErrorReintentar(error: _error!, alReintentar: _cargar);
    final d = _d;
    if (d == null) return const Cargando(mensaje: 'Cargando indicadores…');
    final ancho = MediaQuery.sizeOf(context).width;
    final dosColumnas = ancho > 1100;
    final graficos = [
      _tarjeta('Ocupación por vuelo (próximos 10)', _graficoOcupacion(d)),
      _tarjeta('Reservas por día (últimos 14 días)', _graficoReservas(d)),
    ];
    return Stack(children: [
      RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Text('Resumen general', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            OutlinedButton.icon(onPressed: _cargando ? null : _cargar, icon: const Icon(Icons.refresh), label: const Text('Actualizar')),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 4, runSpacing: 4, children: [
            _kpi(Icons.flight, '${d.vuelosProgramados}', 'Vuelos programados', Colors.blue.shade700),
            _kpi(Icons.confirmation_number, '${d.reservasConfirmadas}', 'Reservas confirmadas', Colors.green.shade700),
            _kpi(Icons.people, '${d.pasajeros}', 'Pasajeros', Colors.indigo.shade600),
            _kpi(Icons.attach_money, Formatos.moneda(d.ingresos), 'Ingresos', Colors.teal.shade700),
            _kpi(Icons.event_seat, '${d.ocupacionPromedio.toStringAsFixed(1)} %', 'Ocupación promedio', Colors.orange.shade800),
            _kpi(Icons.person, '${d.usuariosClientes}', 'Clientes', Colors.purple.shade600),
          ]),
          const SizedBox(height: 8),
          if (dosColumnas)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final g in graficos) Expanded(child: g)])
          else
            ...graficos,
          _tarjeta('Rutas más vendidas', _rutasTop(d), alto: 230),
        ]),
      ),
      if (_cargando) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator()),
    ]);
  }
}
