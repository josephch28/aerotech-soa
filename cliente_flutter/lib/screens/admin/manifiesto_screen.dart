import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/json_util.dart';
import '../../models/mapa_asientos.dart';
import '../../models/vuelo.dart';
import '../../services/admin_service.dart';
import '../../services/vuelo_service.dart';
import '../../utils/formatos.dart';
import '../../utils/ui.dart';
import '../../widgets/cargando.dart';
import '../../widgets/error_reintentar.dart';
import '../../widgets/mapa_asientos/mapa_asientos.dart';
import '../../widgets/vacio.dart';

class ManifiestoScreen extends StatefulWidget {
  final Vuelo vuelo;
  const ManifiestoScreen({super.key, required this.vuelo});

  @override
  State<ManifiestoScreen> createState() => _ManifiestoScreenState();
}

class _ManifiestoScreenState extends State<ManifiestoScreen> {
  Map<String, dynamic>? _manifiesto;
  MapaAsientos? _mapa;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final r = await Future.wait([AdminService.manifiesto(widget.vuelo.id), VueloService.mapa(widget.vuelo.id)]);
      if (mounted) {
        setState(() {
          _manifiesto = r[0] as Map<String, dynamic>;
          _mapa = r[1] as MapaAsientos;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  List<Map<String, dynamic>> get _pasajeros => ((_manifiesto?['pasajeros'] ?? []) as List).map((e) => e as Map<String, dynamic>).toList();

  Future<void> _copiar() async {
    final v = widget.vuelo;
    final b = StringBuffer('Manifiesto ${v.codigoVuelo} · ${v.origen} → ${v.destino} · ${Formatos.fecha(v.fecha)} ${Formatos.hora(v.horaSalida)}\n');
    b.writeln('Asiento\tClase\tNombre\tDocumento\tEdad\tReserva\tTitular');
    for (final p in _pasajeros) {
      b.writeln('${p['asiento']}\t${Formatos.clase('${p['clase']}')}\t${p['nombre']}\t${p['documento']}\t${p['edad']}\t${p['codigo_reserva']}\t${p['titular']}');
    }
    await Clipboard.setData(ClipboardData(text: b.toString()));
    if (mounted) mostrarMensaje(context, 'Manifiesto copiado al portapapeles');
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vuelo;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Manifiesto ${v.codigoVuelo}'),
          actions: [
            IconButton(tooltip: 'Copiar como texto', icon: const Icon(Icons.copy), onPressed: _manifiesto == null ? null : _copiar),
            IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: _cargar),
          ],
          bottom: const TabBar(tabs: [Tab(icon: Icon(Icons.airline_seat_recline_normal), text: 'Mapa'), Tab(icon: Icon(Icons.people), text: 'Pasajeros')]),
        ),
        body: _error != null
            ? ErrorReintentar(error: _error!, alReintentar: _cargar)
            : _manifiesto == null
                ? const Cargando()
                : Column(children: [
                    Container(
                      width: double.infinity,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      padding: const EdgeInsets.all(12),
                      child: Text('${v.ciudadOrigen} (${v.origen}) → ${v.ciudadDestino} (${v.destino}) · ${Formatos.fecha(v.fecha)} · '
                          '${Formatos.hora(v.horaSalida)} · ${v.modeloAvion} · ${_pasajeros.length} pasajeros'),
                    ),
                    Expanded(
                      child: TabBarView(children: [
                        MapaAvion(mapa: _mapa!, soloLectura: true, mostrarEncabezado: false),
                        _tabla(),
                      ]),
                    ),
                  ]),
      ),
    );
  }

  Widget _tabla() {
    final p = _pasajeros;
    if (p.isEmpty) return const Vacio('Este vuelo aún no tiene pasajeros confirmados.', icono: Icons.people_outline);
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Asiento')),
            DataColumn(label: Text('Clase')),
            DataColumn(label: Text('Nombre')),
            DataColumn(label: Text('Documento')),
            DataColumn(label: Text('Edad'), numeric: true),
            DataColumn(label: Text('Reserva')),
            DataColumn(label: Text('Titular')),
          ],
          rows: [
            for (final f in p)
              DataRow(cells: [
                DataCell(Text('${f['asiento']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(Formatos.clase('${f['clase']}'))),
                DataCell(Text('${f['nombre']}')),
                DataCell(Text('${Formatos.tipoDocumento('${f['tipo_documento']}')} ${f['documento']}')),
                DataCell(Text('${entero(f['edad'])}')),
                DataCell(Text('${f['codigo_reserva']}', style: const TextStyle(fontFamily: 'monospace'))),
                DataCell(Text('${f['titular']}')),
              ]),
          ],
        ),
      ),
    );
  }
}
