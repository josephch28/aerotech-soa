import 'package:flutter/material.dart';

import '../../models/asiento.dart';
import '../../services/vuelo_service.dart';
import '../../utils/formatos.dart';
import '../../utils/ui.dart';
import '../../widgets/cargando.dart';
import '../../widgets/error_reintentar.dart';
import '../../widgets/mapa_asientos/mapa_asientos.dart';
import '../../widgets/pasos_reserva.dart';
import 'datos_pasajeros_screen.dart';
import 'reserva_flujo.dart';

class SeleccionAsientosScreen extends StatefulWidget {
  final ReservaFlujo flujo;
  const SeleccionAsientosScreen({super.key, required this.flujo});

  @override
  State<SeleccionAsientosScreen> createState() => _SeleccionAsientosScreenState();
}

class _SeleccionAsientosScreenState extends State<SeleccionAsientosScreen> {
  Object? _error;
  bool _cargando = true;
  bool _avisoSalida = false; // el diálogo de salida de emergencia se muestra solo la primera vez

  ReservaFlujo get f => widget.flujo;

  @override
  void initState() {
    super.initState();
    f.recargarMapa.addListener(_cargar);
    _cargar();
  }

  @override
  void dispose() {
    f.recargarMapa.removeListener(_cargar);
    super.dispose();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final m = await VueloService.mapa(f.vuelo.id);
      if (!mounted) return;
      setState(() {
        f.mapa = m;
        // Quita de la selección los asientos que ya no están libres (y no son propios)
        f.seleccion.removeWhere((c) {
          final a = f.asiento(c);
          return a == null || (a.ocupado && !f.propios.contains(c));
        });
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _tocar(Asiento a) async {
    final sel = f.seleccion;
    if (sel.contains(a.codigo)) {
      setState(() => sel.remove(a.codigo));
      return;
    }
    if (sel.length >= 9) {
      mostrarMensaje(context, 'Máximo 9 asientos por reserva');
      return;
    }
    if (a.salidaEmergencia && !_avisoSalida) {
      _avisoSalida = true;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: Icon(Icons.exit_to_app, color: Colors.red.shade700, size: 36),
          title: const Text('Asiento de salida de emergencia'),
          content: const Text('Quien ocupe este asiento debe:\n\n'
              '• Ser mayor de 15 años.\n'
              '• Estar dispuesto a ayudar en una evacuación.\n'
              '• Poder abrir la salida de emergencia si fuera necesario.\n\n'
              'Los asientos de salida tienen más espacio para las piernas.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Entendido'))],
        ),
      );
      if (!mounted) return;
    }
    setState(() => sel.add(a.codigo));
  }

  void _continuar() {
    if (f.seleccion.isEmpty) {
      mostrarMensaje(context, 'Seleccione al menos un asiento');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DatosPasajerosScreen(flujo: f)));
  }

  Widget _panel(ThemeData t, {required bool lateral}) {
    final seats = f.ordenados;
    final resumen = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (lateral) ...[
        Text(f.edicion ? 'Editar reserva ${f.original!.codigoReserva}' : 'Su selección', style: t.textTheme.titleMedium),
        const SizedBox(height: 8),
      ],
      Text(seats.isEmpty ? 'Ningún asiento seleccionado' : 'Asientos: ${seats.join(', ')}', style: t.textTheme.bodyLarge),
      const SizedBox(height: 4),
      Text('Total parcial ${Formatos.moneda(f.subtotal)}', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      if (f.edicion) Text('Total anterior (con IVA): ${Formatos.moneda(f.original!.total)}', style: t.textTheme.bodySmall),
      if (lateral) ...[
        const SizedBox(height: 8),
        for (final c in seats)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Text(c, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(Formatos.clase(f.asiento(c)?.clase ?? '')),
              const Spacer(),
              Text(Formatos.moneda(f.precioDe(c))),
            ]),
          ),
      ],
    ]);
    final boton = FilledButton.icon(
      onPressed: seats.isEmpty ? null : _continuar,
      icon: const Icon(Icons.arrow_forward),
      label: const Text('Continuar'),
    );
    if (lateral) {
      return Container(
        width: 320,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: t.colorScheme.surfaceContainerLow, border: Border(left: BorderSide(color: t.dividerColor))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: SingleChildScrollView(child: resumen)),
          const SizedBox(height: 12),
          boton,
        ]),
      );
    }
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(seats.isEmpty ? 'Ningún asiento seleccionado' : 'Asientos: ${seats.join(', ')}', overflow: TextOverflow.ellipsis),
                Text('Total parcial ${Formatos.moneda(f.subtotal)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
            ),
            boton,
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ancho = MediaQuery.sizeOf(context).width;
    final ancha = ancho > 900;
    Widget cuerpo;
    if (_error != null && f.mapa == null) {
      cuerpo = ErrorReintentar(error: _error!, alReintentar: _cargar);
    } else if (f.mapa == null) {
      cuerpo = const Cargando(mensaje: 'Cargando mapa de asientos…');
    } else {
      final mapa = MapaAvion(
        mapa: f.mapa!,
        seleccionados: f.seleccion.toSet(),
        propios: f.propios,
        alTocar: _tocar,
      );
      cuerpo = ancha
          ? Row(children: [Expanded(child: mapa), _panel(t, lateral: true)])
          : Column(children: [Expanded(child: mapa), _panel(t, lateral: false)]);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(f.edicion ? 'Editar asientos · ${f.vuelo.codigoVuelo}' : 'Elegir asientos · ${f.vuelo.codigoVuelo}'),
        actions: [IconButton(tooltip: 'Recargar mapa', icon: const Icon(Icons.refresh), onPressed: _cargando ? null : _cargar)],
        bottom: _cargando && f.mapa != null ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator()) : null,
      ),
      body: Column(children: [const PasosReserva(actual: 1), Expanded(child: cuerpo)]),
    );
  }
}
