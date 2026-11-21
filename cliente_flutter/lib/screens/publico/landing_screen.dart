import 'package:flutter/material.dart';

import '../../models/aeropuerto.dart';
import '../../models/vuelo.dart';
import '../../services/vuelo_service.dart';
import '../../sesion.dart';
import '../../utils/formatos.dart';
import '../../widgets/barra_superior.dart';
import '../../widgets/buscador_vuelos.dart';
import '../../widgets/error_reintentar.dart';
import '../cliente/detalle_vuelo_screen.dart';
import 'resultados_screen.dart';

/// Página de inicio pública (landing), inspirada en las de LATAM y Avianca:
/// barra superior, buscador en la portada, ofertas, destinos, beneficios e invitación a crear cuenta.
/// No exige iniciar sesión.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _scroll = ScrollController();
  final _claveOfertas = GlobalKey();
  final _claveDestinos = GlobalKey();

  List<Aeropuerto> _aeropuertos = [];
  List<Vuelo> _vuelos = [];
  Object? _error;
  bool _cargando = true;

  static const _colores = [
    [Color(0xFF1565C0), Color(0xFF42A5F5)],
    [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
    [Color(0xFF00695C), Color(0xFF26A69A)],
    [Color(0xFFEF6C00), Color(0xFFFFB74D)],
    [Color(0xFFAD1457), Color(0xFFEC407A)],
    [Color(0xFF283593), Color(0xFF7986CB)],
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await Future.wait([VueloService.aeropuertos(), VueloService.buscar()]);
      if (!mounted) return;
      setState(() {
        _aeropuertos = r[0] as List<Aeropuerto>;
        _vuelos = r[1] as List<Vuelo>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _ir(GlobalKey k) {
    final c = k.currentContext;
    if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
  }

  void _buscar(Aeropuerto? o, Aeropuerto? d, DateTime? f, int n) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultadosScreen(origen: o, destino: d, fecha: f, pasajeros: n)));
  }

  Widget _centrado(Widget hijo, {EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16)}) =>
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1200), child: Padding(padding: padding, child: hijo)));

  Widget _hero(BuildContext context) {
    final t = Theme.of(context);
    final ancho = MediaQuery.sizeOf(context).width;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [azulMarca, Color(0xFF1B4FA8)]),
      ),
      child: Stack(children: [
        for (final (x, y, s) in const [(0.08, 30.0, 90.0), (0.55, 120.0, 140.0), (0.88, 20.0, 70.0)])
          Positioned(left: ancho * x, top: y, child: Icon(Icons.flight, size: s, color: Colors.white.withValues(alpha: 0.06))),
        _centrado(
          Padding(
            padding: EdgeInsets.fromLTRB(0, ancho < 600 ? 28 : 52, 0, ancho < 600 ? 28 : 60),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Vuela por todo el Ecuador',
                  style: t.textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: ancho < 600 ? 30 : 44)),
              const SizedBox(height: 8),
              Text('Busca tu vuelo, elige tu asiento en el mapa del avión y reserva en minutos.',
                  style: t.textTheme.titleMedium?.copyWith(color: Colors.white70)),
              const SizedBox(height: 24),
              if (_aeropuertos.isEmpty && _cargando)
                const Card(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())))
              else if (_aeropuertos.isEmpty)
                const SizedBox.shrink()
              else
                BuscadorVuelos(aeropuertos: _aeropuertos, alBuscar: _buscar),
              const SizedBox(height: 14),
              Wrap(spacing: 18, runSpacing: 6, children: const [
                _Ventaja(Icons.lock_open, 'Sin registro para buscar y elegir asientos'),
                _Ventaja(Icons.event_seat, 'Mapa de asientos en tiempo real'),
                _Ventaja(Icons.edit_calendar, 'Cambia o cancela tu reserva'),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _titulo(String titulo, String subtitulo, {Key? key}) => Padding(
        key: key,
        padding: const EdgeInsets.fromLTRB(0, 44, 0, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: azulMarca)),
          const SizedBox(height: 4),
          Text(subtitulo, style: Theme.of(context).textTheme.bodyLarge),
        ]),
      );

  Widget _ofertas() {
    final lista = List.of(_vuelos)..sort((a, b) => a.precio.compareTo(b.precio));
    final top = lista.take(6).toList();
    return Wrap(spacing: 16, runSpacing: 16, children: [
      for (var i = 0; i < top.length; i++) _TarjetaOferta(vuelo: top[i], colores: _colores[i % _colores.length]),
    ]);
  }

  Widget _destinos() {
    final porDestino = <String, List<Vuelo>>{};
    for (final v in _vuelos) {
      porDestino.putIfAbsent(v.destino, () => []).add(v);
    }
    final entradas = porDestino.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
    return Wrap(spacing: 16, runSpacing: 16, children: [
      for (var i = 0; i < entradas.length && i < 6; i++)
        _TarjetaDestino(
          vuelos: entradas[i].value,
          colores: _colores[(i + 2) % _colores.length],
          alTocar: () {
            final a = _aeropuertos.where((x) => x.codigo == entradas[i].key).firstOrNull;
            if (a != null) _buscar(null, a, null, 1);
          },
        ),
    ]);
  }

  Widget _beneficios() {
    const items = [
      (Icons.airline_seat_recline_normal, 'Elige tu asiento', 'Mira el avión real, con clase ejecutiva, salidas de emergencia y asientos ocupados.'),
      (Icons.lock_open, 'Reserva sin trabas', 'Busca y arma tu viaje sin cuenta. Solo inicias sesión al confirmar.'),
      (Icons.edit_calendar, 'Cambia o cancela', 'Edita asientos y pasajeros o cancela hasta 3 horas antes del vuelo.'),
      (Icons.receipt_long, 'Comprobante digital', 'Descarga tu comprobante en XML y revisa el historial de tu reserva.'),
    ];
    return Wrap(spacing: 16, runSpacing: 16, children: [
      for (final (icono, titulo, texto) in items)
        SizedBox(
          width: 270,
          child: Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(backgroundColor: azulMarca.withValues(alpha: 0.1), child: Icon(icono, color: azulMarca)),
                const SizedBox(height: 12),
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(texto),
              ]),
            ),
          ),
        ),
    ]);
  }

  Widget _invitacion() {
    return ListenableBuilder(
      listenable: Sesion.instancia,
      builder: (context, _) {
        if (Sesion.instancia.activa) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(top: 44),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: azulMarca, borderRadius: BorderRadius.circular(18)),
          child: Wrap(spacing: 24, runSpacing: 16, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const SizedBox(
              width: 560,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Crea tu cuenta AeroTech', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                SizedBox(height: 6),
                Text('Guarda tus reservas, edítalas cuando quieras y descarga tus comprobantes. Necesitarás tu cuenta para confirmar una reserva.',
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
              ]),
            ),
            Wrap(spacing: 12, runSpacing: 10, children: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: coral, padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16)),
                onPressed: () => Navigator.of(context).pushNamed('/registro'),
                child: const Text('Crear cuenta'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16)),
                onPressed: () => Navigator.of(context).pushNamed('/login'),
                child: const Text('Iniciar sesión'),
              ),
            ]),
          ]),
        );
      },
    );
  }

  Widget _pie() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 56),
      color: azulMarca,
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: _centrado(
        Wrap(spacing: 40, runSpacing: 20, alignment: WrapAlignment.spaceBetween, children: const [
          SizedBox(
            width: 380,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.flight_takeoff, color: Colors.white), SizedBox(width: 8), Text('AeroTech', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))]),
              SizedBox(height: 8),
              Text('Sistema distribuido de reservas de vuelos. Proyecto académico de Aplicaciones Distribuidas (APE 4, servicios web con SOA).', style: TextStyle(color: Colors.white70)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tecnología', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('Flutter · Flask · PostgreSQL · Supabase · Render', style: TextStyle(color: Colors.white70)),
            Text('API REST con JWT y documentación en /docs', style: TextStyle(color: Colors.white70)),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        controller: _scroll,
        child: Column(children: [
          BarraSuperior(alOfertas: () => _ir(_claveOfertas), alDestinos: () => _ir(_claveDestinos)),
          _hero(context),
          _centrado(
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_error != null && _vuelos.isEmpty)
                Padding(padding: const EdgeInsets.only(top: 30), child: SizedBox(height: 220, child: ErrorReintentar(error: _error!, alReintentar: _cargar)))
              else ...[
                _titulo('Ofertas de vuelo', 'Los vuelos más económicos que salen próximamente.', key: _claveOfertas),
                if (_cargando && _vuelos.isEmpty) const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())) else _ofertas(),
                _titulo('Destinos más buscados', 'Descubre a dónde puedes volar desde AeroTech.', key: _claveDestinos),
                if (_cargando && _vuelos.isEmpty) const SizedBox(height: 120) else _destinos(),
              ],
              _titulo('Reservar es fácil', 'Todo lo que necesitas para viajar tranquilo.'),
              _beneficios(),
              _invitacion(),
            ]),
          ),
          _pie(),
        ]),
      ),
    );
  }
}

class _Ventaja extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Ventaja(this.icono, this.texto);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icono, size: 18, color: Colors.white70),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ]);
}

class _TarjetaOferta extends StatelessWidget {
  final Vuelo vuelo;
  final List<Color> colores;
  const _TarjetaOferta({required this.vuelo, required this.colores});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SizedBox(
      width: 280,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetalleVueloScreen(vueloId: vuelo.id))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              height: 96,
              decoration: BoxDecoration(gradient: LinearGradient(colors: colores, begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Stack(children: [
                Positioned(right: -10, bottom: -14, child: Icon(Icons.flight, size: 96, color: Colors.white.withValues(alpha: 0.15))),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(vuelo.origen, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Icon(Icons.arrow_forward, color: Colors.white)),
                    Text(vuelo.destino, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${vuelo.ciudadOrigen} a ${vuelo.ciudadDestino}', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${Formatos.fecha(vuelo.fecha)} · ${Formatos.hora(vuelo.horaSalida)} · ${Formatos.duracion(vuelo.duracionMinutos)}', style: t.textTheme.bodySmall),
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(child: Text('Quedan ${vuelo.asientosDisponibles}', style: t.textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('desde', style: t.textTheme.bodySmall),
                    Text(Formatos.moneda(vuelo.precio), style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: azulMarca)),
                  ]),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _TarjetaDestino extends StatelessWidget {
  final List<Vuelo> vuelos;
  final List<Color> colores;
  final VoidCallback alTocar;
  const _TarjetaDestino({required this.vuelos, required this.colores, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    final v = vuelos.first;
    final desde = vuelos.map((x) => x.precio).reduce((a, b) => a < b ? a : b);
    return SizedBox(
      width: 280,
      height: 172,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alTocar,
          child: Ink(
            decoration: BoxDecoration(gradient: LinearGradient(colors: colores, begin: Alignment.bottomLeft, end: Alignment.topRight)),
            child: Stack(children: [
              Positioned(right: -8, top: -8, child: Icon(Icons.location_on, size: 110, color: Colors.white.withValues(alpha: 0.18))),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(v.ciudadDestino, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  Text('${vuelos.length} ${vuelos.length == 1 ? 'vuelo' : 'vuelos'} disponibles', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text('Desde ${Formatos.moneda(desde)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
