import 'package:flutter/material.dart';

import '../../models/vuelo.dart';
import '../../services/vuelo_service.dart';
import '../../sesion.dart';
import '../../utils/formatos.dart';
import '../../widgets/cargando.dart';
import '../../widgets/error_reintentar.dart';
import '../../widgets/estado_chip.dart';
import 'reserva_flujo.dart';
import 'seleccion_asientos_screen.dart';

class DetalleVueloScreen extends StatefulWidget {
  final int vueloId;
  final int pasajeros;
  const DetalleVueloScreen({super.key, required this.vueloId, this.pasajeros = 1});

  @override
  State<DetalleVueloScreen> createState() => _DetalleVueloScreenState();
}

class _DetalleVueloScreenState extends State<DetalleVueloScreen> {
  Vuelo? _vuelo;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final v = await VueloService.detalle(widget.vueloId);
      if (mounted) setState(() => _vuelo = v);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _elegir(Vuelo v) {
    final u = Sesion.instancia.usuario;
    final flujo = ReservaFlujo(v, telefono: u?.telefono ?? '', correo: u?.correo ?? '');
    Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: '/seleccion'),
      builder: (_) => SeleccionAsientosScreen(flujo: flujo),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del vuelo')),
      body: _error != null
          ? ErrorReintentar(error: _error!, alReintentar: _cargar)
          : _vuelo == null
              ? const Cargando()
              : _contenido(t, _vuelo!),
    );
  }

  Widget _contenido(ThemeData t, Vuelo v) {
    final disponible = v.estado == 'programado' && v.asientosDisponibles > 0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                Row(children: [
                  Text(v.codigoVuelo, style: t.textTheme.titleMedium?.copyWith(color: t.colorScheme.primary, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  EstadoChip(v.estado),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  _punto(t, v.origen, v.ciudadOrigen, Formatos.hora(v.horaSalida), CrossAxisAlignment.start),
                  Expanded(
                    child: Column(children: [
                      Text(Formatos.duracion(v.duracionMinutos)),
                      Row(children: [
                        const Expanded(child: Divider()),
                        Icon(Icons.flight, color: t.colorScheme.primary),
                        const Expanded(child: Divider()),
                      ]),
                      Text(Formatos.fecha(v.fecha), style: t.textTheme.bodySmall),
                    ]),
                  ),
                  _punto(t, v.destino, v.ciudadDestino, Formatos.hora(v.horaLlegada), CrossAxisAlignment.end),
                ]),
              ]),
            ),
          ),
          Card(
            child: Column(children: [
              ListTile(leading: const Icon(Icons.airplanemode_active), title: const Text('Avión'), subtitle: Text('${v.modeloAvion} · ${v.matricula}')),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.event_seat), title: const Text('Asientos libres'), trailing: Text('${v.asientosDisponibles}', style: t.textTheme.titleMedium)),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.airline_seat_recline_normal), title: const Text('Clase económica'), trailing: Text(Formatos.moneda(v.precio), style: t.textTheme.titleMedium)),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.workspace_premium, color: Color(0xFFC9A227)),
                title: const Text('Clase ejecutiva'),
                trailing: Text(Formatos.moneda(v.precioEjecutiva), style: t.textTheme.titleMedium),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: disponible ? () => _elegir(v) : null,
            icon: const Icon(Icons.event_seat),
            label: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(disponible ? 'Elegir asientos' : 'Sin asientos disponibles')),
          ),
        ]),
      ),
    );
  }

  Widget _punto(ThemeData t, String codigo, String ciudad, String hora, CrossAxisAlignment a) => Column(
        crossAxisAlignment: a,
        children: [
          Text(codigo, style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(ciudad),
          Text(hora, style: t.textTheme.titleMedium),
        ],
      );
}
