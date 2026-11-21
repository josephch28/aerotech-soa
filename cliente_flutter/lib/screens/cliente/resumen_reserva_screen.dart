import 'package:flutter/material.dart';

import '../../config.dart';
import '../../models/pasajero.dart';
import '../../models/reserva.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/reserva_service.dart';
import '../../sesion.dart';
import '../../utils/formatos.dart';
import '../../utils/ui.dart';
import 'cliente_home.dart';
import 'comprobante_screen.dart';
import '../../widgets/pasos_reserva.dart';
import 'reserva_flujo.dart';

class ResumenReservaScreen extends StatefulWidget {
  final ReservaFlujo flujo;
  const ResumenReservaScreen({super.key, required this.flujo});

  @override
  State<ResumenReservaScreen> createState() => _ResumenReservaScreenState();
}

class _ResumenReservaScreenState extends State<ResumenReservaScreen> {
  bool _enviando = false;
  ReservaFlujo get f => widget.flujo;

  List<Pasajero> get _pasajeros => f.ordenados.map((c) => f.datos[c]!).toList();

  /// Si todavía no hay sesión, aquí (y no antes) se pide iniciar sesión o crear la cuenta: es el último paso,
  /// justo antes de confirmar. Los asientos y datos ya escritos se conservan en [ReservaFlujo].
  Future<bool> _asegurarSesion() async {
    if (Sesion.instancia.activa) return true;
    final r = await Navigator.of(context).pushNamed('/login', arguments: {'retorno': true});
    if (!mounted) return false;
    if (r != true || !Sesion.instancia.activa) return false;
    if (Sesion.instancia.esAdmin) {
      await AuthService.logout();
      if (mounted) {
        setState(() {});
        mostrarError(context, 'Las cuentas de administrador no pueden reservar. Inicie sesión con una cuenta de cliente.');
      }
      return false;
    }
    setState(() {});
    mostrarMensaje(context, 'Sesión iniciada como ${Sesion.instancia.usuario?.nombre}. Revisa el resumen y confirma tu reserva.');
    return false; // vuelve al resumen; el usuario confirma con la sesión ya abierta
  }

  Future<void> _confirmar() async {
    if (!Sesion.instancia.activa) {
      await _asegurarSesion();
      return;
    }
    setState(() => _enviando = true);
    try {
      if (f.edicion) {
        final r = await ReservaService.editar(f.original!.id, _pasajeros, f.telefono, f.correo);
        if (!mounted) return;
        await _exito(r.reserva, titulo: 'Reserva actualizada', diferencia: r.diferencia);
      } else {
        final r = await ReservaService.crear(f.vuelo.id, _pasajeros, f.telefono, f.correo);
        if (!mounted) return;
        await _exito(r, titulo: '¡Reserva confirmada!');
      }
    } on ApiException catch (e) {
      final ocupados = (e.extra['asientos_no_disponibles'] as List?)?.map((x) => '$x').toList();
      if (e.codigo == 409 && ocupados != null && ocupados.isNotEmpty) {
        // Quita de la selección los asientos tomados y vuelve al mapa. Los datos de los pasajeros se conservan
        // (también los del asiento perdido: se reasignan al asiento nuevo en la pantalla de pasajeros).
        for (final c in ocupados) {
          f.seleccion.remove(c);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            content: Text('Otro usuario acaba de reservar ${ocupados.join(', ')}. '
                'Elija otro${ocupados.length > 1 ? 's' : ''} asiento${ocupados.length > 1 ? 's' : ''}; sus datos se conservaron.'),
          ));
          Navigator.of(context).popUntil(ModalRoute.withName('/seleccion'));
          f.recargarMapa.value++;
        }
      } else if (mounted) {
        mostrarError(context, e);
      }
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _exito(Reserva r, {required String titulo, double? diferencia}) async {
    final accion = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: Icon(Icons.check_circle, color: Colors.green.shade600, size: 48),
        title: Text(titulo, textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Código de reserva'),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(color: Theme.of(c).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
            child: SelectableText(r.codigoReserva,
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: 6, fontFamily: 'monospace')),
          ),
          const SizedBox(height: 12),
          Text('Asientos: ${r.asientos.join(', ')}'),
          Text('Total: ${Formatos.moneda(r.total)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (diferencia != null) Text('Diferencia: ${Formatos.monedaConSigno(diferencia)}'),
        ]),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton.icon(onPressed: () => Navigator.pop(c, 'xml'), icon: const Icon(Icons.code), label: const Text('Ver comprobante XML')),
          FilledButton.icon(onPressed: () => Navigator.pop(c, 'mis'), icon: const Icon(Icons.list_alt), label: const Text('Ir a mis reservas')),
        ],
      ),
    );
    if (!mounted) return;
    // Termina el flujo: se limpia la pila y se abre «Mis reservas»
    ClienteHome.abrirLimpiando(context, pestana: 1);
    if (accion == 'xml') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => ComprobanteScreen(reservaId: r.id, codigo: r.codigoReserva)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final v = f.vuelo;
    final pas = _pasajeros;
    return Scaffold(
      appBar: AppBar(title: Text(f.edicion ? 'Resumen de cambios' : 'Resumen de la reserva')),
      body: Column(children: [
        const PasosReserva(actual: 3),
        Expanded(child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (!Sesion.instancia.activa)
              Card(
                color: t.colorScheme.primaryContainer.withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    const Icon(Icons.lock_person_outlined, size: 30),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('¡Casi listo! Para confirmar tu reserva inicia sesión o crea tu cuenta. '
                          'Tus asientos y los datos de los pasajeros se conservan.'),
                    ),
                  ]),
                ),
              ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.flight_takeoff),
                title: Text('${v.codigoVuelo} · ${v.origen} → ${v.destino}'),
                subtitle: Text('${Formatos.fecha(v.fecha)} · ${Formatos.hora(v.horaSalida)} · ${v.modeloAvion}'),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Row(children: [
                    Expanded(flex: 3, child: Text('Pasajero', style: t.textTheme.labelLarge)),
                    Expanded(child: Text('Asiento', style: t.textTheme.labelLarge)),
                    Expanded(flex: 2, child: Text('Clase', style: t.textTheme.labelLarge)),
                    Text('Precio', style: t.textTheme.labelLarge),
                  ]),
                  const Divider(),
                  for (final p in pas)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text(p.nombreCompleto, overflow: TextOverflow.ellipsis)),
                        Expanded(child: Text(p.asiento, style: const TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text(Formatos.clase(f.asiento(p.asiento)?.clase ?? ''))),
                        Text(Formatos.moneda(f.precioDe(p.asiento))),
                      ]),
                    ),
                  const Divider(),
                  _linea('Subtotal', Formatos.moneda(f.subtotal)),
                  _linea('IVA ${ivaPorcentaje.toStringAsFixed(0)} %', Formatos.moneda(f.iva)),
                  _linea(f.edicion ? 'Nuevo total' : 'Total', Formatos.moneda(f.total), fuerte: true),
                  if (f.edicion) ...[
                    _linea('Total anterior', Formatos.moneda(f.original!.total)),
                    _linea('Diferencia', Formatos.monedaConSigno(f.total - f.original!.total),
                        fuerte: true, color: f.total - f.original!.total > 0 ? Colors.red.shade700 : Colors.green.shade700),
                  ],
                ]),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.contact_phone_outlined),
                title: const Text('Contacto'),
                subtitle: Text('${f.telefono}\n${f.correo}'),
                isThreeLine: true,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _enviando ? null : _confirmar,
              icon: _enviando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(f.edicion ? 'Guardar cambios' : (Sesion.instancia.activa ? 'Confirmar reserva' : 'Iniciar sesión para confirmar')),
              ),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      )),
      ]),
    );
  }

  Widget _linea(String a, String b, {bool fuerte = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(a, style: TextStyle(fontWeight: fuerte ? FontWeight.bold : null)),
          const Spacer(),
          Text(b, style: TextStyle(fontWeight: fuerte ? FontWeight.bold : null, fontSize: fuerte ? 16 : null, color: color)),
        ]),
      );
}
