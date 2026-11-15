import 'package:flutter/material.dart';

import '../../models/aeropuerto.dart';
import '../../models/vuelo.dart';
import '../../services/vuelo_service.dart';
import '../../utils/formatos.dart';
import '../../utils/ui.dart';
import '../../widgets/cargando.dart';
import '../../widgets/error_reintentar.dart';
import '../../widgets/vacio.dart';
import '../../widgets/vuelo_card.dart';
import 'detalle_vuelo_screen.dart';

class BuscarVuelosScreen extends StatefulWidget {
  const BuscarVuelosScreen({super.key});

  @override
  State<BuscarVuelosScreen> createState() => _BuscarVuelosScreenState();
}

class _BuscarVuelosScreenState extends State<BuscarVuelosScreen> {
  List<Aeropuerto> _aeropuertos = [];
  Aeropuerto? _origen, _destino;
  DateTime? _fecha;
  int _pasajeros = 1;

  List<Vuelo>? _vuelos;
  Object? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _inicio();
  }

  Future<void> _inicio() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      _aeropuertos = await VueloService.aeropuertos();
      await _buscar(mostrarCarga: false);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _buscar({bool mostrarCarga = true}) async {
    if (_origen != null && _origen == _destino) {
      mostrarError(context, 'El origen y el destino deben ser distintos');
      return;
    }
    if (mostrarCarga) setState(() => _cargando = true);
    try {
      final r = await VueloService.buscar(
        origen: _origen?.codigo,
        destino: _destino?.codigo,
        fecha: _fecha == null ? null : Formatos.iso(_fecha!),
        pasajeros: _pasajeros,
      );
      if (mounted) {
        setState(() {
          _vuelos = r;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
        mostrarError(context, e);
      }
    } finally {
      if (mounted && mostrarCarga) setState(() => _cargando = false);
    }
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context,
      locale: const Locale('es'),
      initialDate: _fecha ?? hoy,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: DateTime(hoy.year + 2),
      helpText: 'Fecha del vuelo',
    );
    if (f != null) setState(() => _fecha = f);
  }

  void _intercambiar() => setState(() {
        final t = _origen;
        _origen = _destino;
        _destino = t;
      });

  Widget _selector(String etiqueta, Aeropuerto? valor, ValueChanged<Aeropuerto?> alCambiar) {
    return DropdownButtonFormField<Aeropuerto?>(
      key: ValueKey('$etiqueta-${valor?.codigo}'),
      initialValue: valor,
      isExpanded: true,
      decoration: InputDecoration(labelText: etiqueta, prefixIcon: const Icon(Icons.location_on_outlined)),
      items: [
        const DropdownMenuItem<Aeropuerto?>(value: null, child: Text('Cualquiera')),
        ..._aeropuertos.map((a) => DropdownMenuItem<Aeropuerto?>(value: a, child: Text('${a.ciudad} (${a.codigo})'))),
      ],
      onChanged: alCambiar,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final filtros = Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Expanded(child: _selector('Origen', _origen, (v) => setState(() => _origen = v))),
            IconButton(tooltip: 'Intercambiar', icon: const Icon(Icons.swap_horiz), onPressed: _intercambiar),
            Expanded(child: _selector('Destino', _destino, (v) => setState(() => _destino = v))),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: ancho > 600 ? 240 : double.infinity,
              child: OutlinedButton.icon(
                onPressed: _elegirFecha,
                icon: const Icon(Icons.calendar_month),
                label: Text(_fecha == null ? 'Cualquier fecha' : Formatos.fecha(_fecha!)),
              ),
            ),
            if (_fecha != null)
              IconButton(tooltip: 'Quitar fecha', icon: const Icon(Icons.close), onPressed: () => setState(() => _fecha = null)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.people_outline),
              IconButton(
                tooltip: 'Menos pasajeros',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _pasajeros > 1 ? () => setState(() => _pasajeros--) : null,
              ),
              Text('$_pasajeros ${_pasajeros == 1 ? 'pasajero' : 'pasajeros'}'),
              IconButton(
                tooltip: 'Más pasajeros',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _pasajeros < 9 ? () => setState(() => _pasajeros++) : null,
              ),
            ]),
            FilledButton.icon(onPressed: _cargando ? null : () => _buscar(), icon: const Icon(Icons.search), label: const Text('Buscar')),
          ]),
        ]),
      ),
    );

    Widget cuerpo;
    if (_cargando && _vuelos == null) {
      cuerpo = const Cargando(mensaje: 'Buscando vuelos…');
    } else if (_error != null && _vuelos == null) {
      cuerpo = ErrorReintentar(error: _error!, alReintentar: _inicio);
    } else if (_vuelos!.isEmpty) {
      cuerpo = const Vacio('No hay vuelos disponibles con esos criterios.\nPruebe con otra fecha o ruta.', icono: Icons.flight_outlined);
    } else {
      cuerpo = RefreshIndicator(
        onRefresh: () => _buscar(mostrarCarga: false),
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: _vuelos!.length,
          itemBuilder: (_, i) {
            final v = _vuelos![i];
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: VueloCard(
                  vuelo: v,
                  alTocar: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetalleVueloScreen(vueloId: v.id, pasajeros: _pasajeros))),
                ),
              ),
            );
          },
        ),
      );
    }

    return Column(children: [
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: filtros)),
      if (_cargando && _vuelos != null) const LinearProgressIndicator(),
      Expanded(child: cuerpo),
    ]);
  }
}
