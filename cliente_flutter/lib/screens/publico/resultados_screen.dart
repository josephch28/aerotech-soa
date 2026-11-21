import 'package:flutter/material.dart';

import '../../models/aeropuerto.dart';
import '../../models/vuelo.dart';
import '../../services/vuelo_service.dart';
import '../../utils/formatos.dart';
import '../../widgets/barra_superior.dart';
import '../../widgets/buscador_vuelos.dart';
import '../../widgets/cargando.dart';
import '../../widgets/error_reintentar.dart';
import '../../widgets/vuelo_card.dart';
import '../cliente/detalle_vuelo_screen.dart';

/// Resultados de la búsqueda (pública): se puede modificar la búsqueda, ordenar y elegir un vuelo
/// sin haber iniciado sesión.
class ResultadosScreen extends StatefulWidget {
  final Aeropuerto? origen;
  final Aeropuerto? destino;
  final DateTime? fecha;
  final int pasajeros;

  const ResultadosScreen({super.key, this.origen, this.destino, this.fecha, this.pasajeros = 1});

  @override
  State<ResultadosScreen> createState() => _ResultadosScreenState();
}

class _ResultadosScreenState extends State<ResultadosScreen> {
  late Aeropuerto? _origen = widget.origen;
  late Aeropuerto? _destino = widget.destino;
  late DateTime? _fecha = widget.fecha;
  late int _pasajeros = widget.pasajeros;

  List<Aeropuerto> _aeropuertos = [];
  List<Vuelo>? _vuelos;
  List<DateTime> _fechasAlternativas = [];
  Object? _error;
  bool _cargando = true;
  String _orden = 'precio';
  int _peticion = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final mia = ++_peticion;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      if (_aeropuertos.isEmpty) _aeropuertos = await VueloService.aeropuertos();
      final r = await VueloService.buscar(
        origen: _origen?.codigo,
        destino: _destino?.codigo,
        fecha: _fecha == null ? null : Formatos.iso(_fecha!),
        pasajeros: _pasajeros,
      );
      var alternativas = <DateTime>[];
      if (r.isEmpty && _fecha != null) {
        // Sin vuelos ese día: se sugieren las otras fechas con vuelos en la misma ruta
        final otros = await VueloService.buscar(origen: _origen?.codigo, destino: _destino?.codigo, pasajeros: _pasajeros);
        alternativas = (otros.map((v) => v.fechaDia).toSet().toList()..sort());
      }
      if (mounted && mia == _peticion) {
        setState(() {
          _vuelos = r;
          _fechasAlternativas = alternativas;
        });
      }
    } catch (e) {
      if (mounted && mia == _peticion) setState(() => _error = e);
    } finally {
      if (mounted && mia == _peticion) setState(() => _cargando = false);
    }
  }

  void _nuevaBusqueda(Aeropuerto? o, Aeropuerto? d, DateTime? f, int n) {
    setState(() {
      _origen = o;
      _destino = d;
      _fecha = f;
      _pasajeros = n;
    });
    _cargar();
  }

  List<Vuelo> get _ordenados {
    final l = List.of(_vuelos ?? <Vuelo>[]);
    if (_orden == 'precio') {
      l.sort((a, b) => a.precio.compareTo(b.precio));
    } else {
      l.sort((a, b) => a.salida.compareTo(b.salida));
    }
    return l;
  }

  String get _titulo {
    if (_origen != null && _destino != null) return 'Vuelos de ${_origen!.ciudad} a ${_destino!.ciudad}';
    if (_destino != null) return 'Vuelos a ${_destino!.ciudad}';
    if (_origen != null) return 'Vuelos desde ${_origen!.ciudad}';
    return 'Vuelos disponibles';
  }

  Widget _cuerpo() {
    if (_error != null && _vuelos == null) return ErrorReintentar(error: _error!, alReintentar: _cargar);
    if (_cargando && _vuelos == null) return const Padding(padding: EdgeInsets.all(60), child: Cargando(mensaje: 'Buscando vuelos…'));
    final lista = _ordenados;
    if (lista.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          Icon(Icons.flight_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('No encontramos vuelos para esa búsqueda.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(_fechasAlternativas.isEmpty ? 'Prueba con otra ruta, otra fecha o menos pasajeros.' : 'Hay vuelos en esta ruta en otras fechas:'),
          if (_fechasAlternativas.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
              for (final f in _fechasAlternativas.take(12))
                ActionChip(avatar: const Icon(Icons.calendar_month, size: 18), label: Text(Formatos.fecha(f)), onPressed: () => _nuevaBusqueda(_origen, _destino, f, _pasajeros)),
            ]),
          ],
          if (_fecha != null) ...[
            const SizedBox(height: 14),
            TextButton(onPressed: () => _nuevaBusqueda(_origen, _destino, null, _pasajeros), child: const Text('Ver todas las fechas')),
          ],
        ]),
      );
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Text('${lista.length} ${lista.length == 1 ? 'vuelo' : 'vuelos'}', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          const Text('Ordenar: '),
          ChoiceChip(label: const Text('Más económico'), selected: _orden == 'precio', onSelected: (_) => setState(() => _orden = 'precio')),
          const SizedBox(width: 6),
          ChoiceChip(label: const Text('Más temprano'), selected: _orden == 'hora', onSelected: (_) => setState(() => _orden = 'hora')),
        ]),
      ),
      for (final v in lista)
        VueloCard(
          vuelo: v,
          alTocar: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetalleVueloScreen(vueloId: v.id, pasajeros: _pasajeros))),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SingleChildScrollView(
        child: Column(children: [
          const BarraSuperior(),
          Container(
            width: double.infinity,
            color: azulMarca,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: _aeropuertos.isEmpty
                    ? const SizedBox(height: 60)
                    : BuscadorVuelos(aeropuertos: _aeropuertos, origen: _origen, destino: _destino, fecha: _fecha, pasajeros: _pasajeros, alBuscar: _nuevaBusqueda),
              ),
            ),
          ),
          if (_cargando && _vuelos != null) const LinearProgressIndicator(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 40),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(_titulo, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: azulMarca)),
                  ),
                  if (_fecha != null)
                    Padding(padding: const EdgeInsets.fromLTRB(16, 2, 16, 0), child: Text('Salida: ${Formatos.fecha(_fecha!)} · $_pasajeros ${_pasajeros == 1 ? 'pasajero' : 'pasajeros'}')),
                  _cuerpo(),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
