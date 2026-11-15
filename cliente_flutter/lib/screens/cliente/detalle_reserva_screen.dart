import 'package:flutter/material.dart';

import '../../models/evento_historial.dart';
import '../../models/reserva.dart';
import '../../services/admin_service.dart';
import '../../services/reserva_service.dart';
import '../../sesion.dart';
import '../../utils/formatos.dart';
import '../../utils/ui.dart';
import '../../utils/validadores.dart';
import '../../widgets/cargando.dart';
import '../../widgets/error_reintentar.dart';
import '../../widgets/estado_chip.dart';
import 'comprobante_screen.dart';
import 'reserva_flujo.dart';
import 'seleccion_asientos_screen.dart';

/// Detalle de una reserva. Lo usan el cliente y el administrador (en modo admin no se edita y
/// la cancelación exige motivo).
class DetalleReservaScreen extends StatefulWidget {
  final int reservaId;
  const DetalleReservaScreen({super.key, required this.reservaId});

  @override
  State<DetalleReservaScreen> createState() => _DetalleReservaScreenState();
}

class _DetalleReservaScreenState extends State<DetalleReservaScreen> {
  Reserva? _reserva;
  List<EventoHistorial> _eventos = [];
  Object? _error;
  bool _ocupado = false;

  bool get _admin => Sesion.instancia.esAdmin;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final r = await ReservaService.detalle(widget.reservaId);
      final h = await ReservaService.historial(widget.reservaId);
      if (mounted) {
        setState(() {
          _reserva = r;
          _eventos = h;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _editar(Reserva r) async {
    final u = Sesion.instancia.usuario;
    final flujo = ReservaFlujo(r.vuelo!, original: r,
        telefono: r.telefonoContacto.isEmpty ? (u?.telefono ?? '') : r.telefonoContacto,
        correo: r.correoContacto.isEmpty ? (u?.correo ?? '') : r.correoContacto);
    await Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: '/seleccion'),
      builder: (_) => SeleccionAsientosScreen(flujo: flujo),
    ));
    if (mounted) _cargar();
  }

  Future<void> _cancelar(Reserva r) async {
    String? motivo;
    if (_admin) {
      motivo = await _pedirMotivo(r);
      if (motivo == null) return;
    } else {
      final ok = await confirmar(
        context,
        titulo: 'Cancelar reserva ${r.codigoReserva}',
        mensaje: 'Se liberarán ${r.cantidadAsientos} ${r.cantidadAsientos == 1 ? 'asiento' : 'asientos'} (${r.asientos.join(', ')}) '
            'y la reserva quedará cancelada. Esta acción no se puede deshacer.',
        aceptar: 'Cancelar reserva',
        peligro: true,
      );
      if (!ok) return;
    }
    setState(() => _ocupado = true);
    try {
      if (_admin) {
        await AdminService.cancelarReserva(r.id, motivo!);
      } else {
        await ReservaService.cancelar(r.id);
      }
      if (mounted) mostrarMensaje(context, 'Reserva cancelada');
      await _cargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<String?> _pedirMotivo(Reserva r) {
    final c = TextEditingController();
    final form = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Cancelar reserva ${r.codigoReserva}'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: c,
            maxLength: 200,
            maxLines: 3,
            validator: Validadores.motivo,
            decoration: const InputDecoration(labelText: 'Motivo de la cancelación'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Volver')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(d, c.text.trim());
            },
            child: const Text('Cancelar reserva'),
          ),
        ],
      ),
    );
  }

  /// Motivo por el que no se puede editar/cancelar.
  String? _motivoBloqueo(Reserva r) {
    if (!r.confirmada) return 'Reserva cancelada';
    final v = r.vuelo;
    if (v != null && v.estado != 'programado') return 'El vuelo fue cancelado';
    if (v != null && v.salida.difference(DateTime.now()).inHours < 3) return 'Faltan menos de 3 horas para el vuelo';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_reserva == null ? 'Reserva' : 'Reserva ${_reserva!.codigoReserva}'),
        actions: [IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: _cargar)],
      ),
      body: _error != null
          ? ErrorReintentar(error: _error!, alReintentar: _cargar)
          : _reserva == null
              ? const Cargando()
              : _contenido(Theme.of(context), _reserva!),
    );
  }

  Widget _contenido(ThemeData t, Reserva r) {
    final v = r.vuelo;
    final bloqueo = _motivoBloqueo(r);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  SelectableText(r.codigoReserva, style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 4, fontFamily: 'monospace')),
                  const Spacer(),
                  EstadoChip(r.estado),
                ]),
                if (v != null) ...[
                  const SizedBox(height: 8),
                  Text('${v.ciudadOrigen} (${v.origen}) → ${v.ciudadDestino} (${v.destino})', style: t.textTheme.titleMedium),
                  Text('${v.codigoVuelo} · ${Formatos.fecha(v.fecha)} · ${Formatos.hora(v.horaSalida)} – ${Formatos.hora(v.horaLlegada)} · ${v.modeloAvion}'),
                  if (v.estado != 'programado') Padding(padding: const EdgeInsets.only(top: 6), child: EstadoChip(v.estado)),
                ],
                if (r.fechaReserva != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Reservada: ${Formatos.fechaHora(r.fechaReserva)}', style: t.textTheme.bodySmall)),
                if (r.motivoCancelacion.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Icon(Icons.info_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Motivo: ${r.motivoCancelacion}')),
                    ]),
                  ),
              ]),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pasajeros', style: t.textTheme.titleMedium),
                const SizedBox(height: 6),
                for (final p in r.pasajeros)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: CircleAvatar(radius: 18, child: Text(p.asiento, style: const TextStyle(fontSize: 11))),
                    title: Text(p.nombreCompleto),
                    subtitle: Text('${Formatos.tipoDocumento(p.tipoDocumento)} ${p.numeroDocumento} · ${p.edad} años · ${Formatos.clase(p.clase)}'),
                    trailing: Text(Formatos.moneda(p.precio)),
                  ),
                const Divider(),
                _linea('Subtotal', Formatos.moneda(r.subtotal)),
                _linea('IVA ${ivaTexto()}', Formatos.moneda(r.iva)),
                _linea('Total', Formatos.moneda(r.total), fuerte: true),
                const Divider(),
                Text('Contacto: ${r.telefonoContacto} · ${r.correoContacto}', style: t.textTheme.bodySmall),
              ]),
            ),
          ),
          Wrap(spacing: 10, runSpacing: 10, children: [
            if (!_admin)
              FilledButton.icon(
                onPressed: r.puedeEditar && !_ocupado ? () => _editar(r) : null,
                icon: const Icon(Icons.edit),
                label: const Text('Editar reserva'),
              ),
            OutlinedButton.icon(
              onPressed: r.puedeCancelar && !_ocupado ? () => _cancelar(r) : null,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancelar reserva'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComprobanteScreen(reservaId: r.id, codigo: r.codigoReserva))),
              icon: const Icon(Icons.code),
              label: const Text('Comprobante XML'),
            ),
          ]),
          if (bloqueo != null && !(r.puedeEditar && r.puedeCancelar))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                Icon(Icons.lock_outline, size: 18, color: t.colorScheme.outline),
                const SizedBox(width: 6),
                Expanded(child: Text('No se puede ${_admin ? 'cancelar' : 'editar ni cancelar'}: $bloqueo', style: t.textTheme.bodySmall)),
              ]),
            ),
          const SizedBox(height: 20),
          Text('Historial', style: t.textTheme.titleMedium),
          const SizedBox(height: 8),
          _lineaTiempo(t),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  String ivaTexto() => '15 %';

  Widget _linea(String a, String b, {bool fuerte = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text(a, style: TextStyle(fontWeight: fuerte ? FontWeight.bold : null)),
          const Spacer(),
          Text(b, style: TextStyle(fontWeight: fuerte ? FontWeight.bold : null, fontSize: fuerte ? 16 : null)),
        ]),
      );

  String _descripcion(EventoHistorial e) {
    final d = e.detalle;
    String lista(dynamic x) => x is List ? x.join(', ') : '$x';
    switch (e.accion) {
      case 'creada':
        return 'Asientos ${lista(d['asientos'])} · Total ${Formatos.moneda((d['total'] as num?) ?? 0)}';
      case 'modificada':
        final a = (d['antes'] ?? {}) as Map, n = (d['despues'] ?? {}) as Map;
        return 'Asientos ${lista(a['asientos'])} → ${lista(n['asientos'])} · '
            'Total ${Formatos.moneda((a['total'] as num?) ?? 0)} → ${Formatos.moneda((n['total'] as num?) ?? 0)}';
      case 'cancelada':
        return '${d['motivo'] ?? ''}';
      default:
        return '';
    }
  }

  Widget _lineaTiempo(ThemeData t) {
    if (_eventos.isEmpty) return const Text('Sin eventos');
    final (iconos, colores) = (
      {'creada': Icons.add_circle, 'modificada': Icons.edit, 'cancelada': Icons.cancel},
      {'creada': Colors.green.shade600, 'modificada': Colors.blue.shade600, 'cancelada': Colors.red.shade600},
    );
    return Column(children: [
      for (var i = 0; i < _eventos.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 36,
              child: Column(children: [
                Icon(iconos[_eventos[i].accion] ?? Icons.circle, color: colores[_eventos[i].accion], size: 22),
                if (i < _eventos.length - 1) Expanded(child: Container(width: 2, color: t.colorScheme.outlineVariant)),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_eventos[i].accion[0].toUpperCase()}${_eventos[i].accion.substring(1)}',
                      style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  Text('${Formatos.fechaHora(_eventos[i].fecha)}${_eventos[i].usuario.isEmpty ? '' : ' · ${_eventos[i].usuario}'}', style: t.textTheme.bodySmall),
                  if (_descripcion(_eventos[i]).isNotEmpty) Text(_descripcion(_eventos[i])),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}
