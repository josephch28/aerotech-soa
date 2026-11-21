import 'package:flutter/material.dart';

import '../models/aeropuerto.dart';
import '../utils/formatos.dart';
import 'barra_superior.dart';

/// Tarjeta de búsqueda estilo aerolínea: origen ⇄ destino, fecha, pasajeros y botón Buscar.
class BuscadorVuelos extends StatefulWidget {
  final List<Aeropuerto> aeropuertos;
  final Aeropuerto? origen;
  final Aeropuerto? destino;
  final DateTime? fecha;
  final int pasajeros;
  final void Function(Aeropuerto origen, Aeropuerto destino, DateTime? fecha, int pasajeros) alBuscar;

  const BuscadorVuelos({
    super.key,
    required this.aeropuertos,
    required this.alBuscar,
    this.origen,
    this.destino,
    this.fecha,
    this.pasajeros = 1,
  });

  @override
  State<BuscadorVuelos> createState() => _BuscadorVuelosState();
}

class _BuscadorVuelosState extends State<BuscadorVuelos> {
  Aeropuerto? _origen, _destino;
  DateTime? _fecha;
  late int _pasajeros;
  String? _error;

  @override
  void initState() {
    super.initState();
    _origen = widget.origen;
    _destino = widget.destino;
    _fecha = widget.fecha;
    _pasajeros = widget.pasajeros;
  }

  @override
  void didUpdateWidget(covariant BuscadorVuelos old) {
    super.didUpdateWidget(old);
    if (old.origen != widget.origen || old.destino != widget.destino || old.fecha != widget.fecha || old.pasajeros != widget.pasajeros) {
      _origen = widget.origen;
      _destino = widget.destino;
      _fecha = widget.fecha;
      _pasajeros = widget.pasajeros;
    }
  }

  void _intercambiar() => setState(() {
        final t = _origen;
        _origen = _destino;
        _destino = t;
      });

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context,
      locale: const Locale('es'),
      initialDate: _fecha ?? hoy,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: DateTime(hoy.year + 2),
      helpText: 'Fecha de salida',
    );
    if (f != null) setState(() => _fecha = f);
  }

  Future<void> _elegirPasajeros() async {
    var n = _pasajeros;
    final r = await showDialog<int>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Pasajeros'),
          content: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            IconButton.outlined(onPressed: n > 1 ? () => setD(() => n--) : null, icon: const Icon(Icons.remove)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text('$n', style: Theme.of(c).textTheme.headlineMedium)),
            IconButton.outlined(onPressed: n < 9 ? () => setD(() => n++) : null, icon: const Icon(Icons.add)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, n), child: const Text('Listo')),
          ],
        ),
      ),
    );
    if (r != null) setState(() => _pasajeros = r);
  }

  void _buscar() {
    if (_origen == null || _destino == null) {
      setState(() => _error = 'Seleccione el origen y el destino');
      return;
    }
    if (_origen == _destino) {
      setState(() => _error = 'El origen y el destino deben ser distintos');
      return;
    }
    setState(() => _error = null);
    widget.alBuscar(_origen!, _destino!, _fecha, _pasajeros);
  }

  Widget _aeropuerto(String etiqueta, IconData icono, Aeropuerto? valor, ValueChanged<Aeropuerto?> alCambiar) {
    return DropdownButtonFormField<Aeropuerto>(
      key: ValueKey('$etiqueta-${valor?.codigo}'),
      initialValue: valor,
      isExpanded: true,
      decoration: InputDecoration(labelText: etiqueta, prefixIcon: Icon(icono), border: const OutlineInputBorder()),
      items: [for (final a in widget.aeropuertos) DropdownMenuItem(value: a, child: Text('${a.ciudad} (${a.codigo})', overflow: TextOverflow.ellipsis))],
      onChanged: alCambiar,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fecha = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56), alignment: Alignment.centerLeft),
      onPressed: _elegirFecha,
      icon: const Icon(Icons.calendar_month),
      label: Text(_fecha == null ? 'Cualquier fecha' : Formatos.fecha(_fecha!)),
    );
    final pasajeros = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56), alignment: Alignment.centerLeft),
      onPressed: _elegirPasajeros,
      icon: const Icon(Icons.people_outline),
      label: Text('$_pasajeros ${_pasajeros == 1 ? 'pasajero' : 'pasajeros'}'),
    );
    final buscar = FilledButton.icon(
      style: FilledButton.styleFrom(backgroundColor: coral, minimumSize: const Size(0, 56), padding: const EdgeInsets.symmetric(horizontal: 28)),
      onPressed: _buscar,
      icon: const Icon(Icons.search),
      label: const Text('Buscar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    );
    final intercambio = IconButton.filledTonal(tooltip: 'Intercambiar origen y destino', onPressed: _intercambiar, icon: const Icon(Icons.swap_horiz));

    return Card(
      elevation: 6,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(builder: (context, c) {
          final ancha = c.maxWidth >= 860;
          final campos = ancha
              ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(flex: 3, child: _aeropuerto('Origen', Icons.flight_takeoff, _origen, (v) => setState(() => _origen = v))),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: intercambio),
                  Expanded(flex: 3, child: _aeropuerto('Destino', Icons.flight_land, _destino, (v) => setState(() => _destino = v))),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: fecha),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: pasajeros),
                  const SizedBox(width: 12),
                  buscar,
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _aeropuerto('Origen', Icons.flight_takeoff, _origen, (v) => setState(() => _origen = v)),
                  Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: intercambio)),
                  _aeropuerto('Destino', Icons.flight_land, _destino, (v) => setState(() => _destino = v)),
                  const SizedBox(height: 12),
                  fecha,
                  const SizedBox(height: 12),
                  pasajeros,
                  const SizedBox(height: 14),
                  buscar,
                ]);
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            campos,
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(children: [
                  Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                  const SizedBox(width: 6),
                  Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                ]),
              ),
          ]);
        }),
      ),
    );
  }
}
