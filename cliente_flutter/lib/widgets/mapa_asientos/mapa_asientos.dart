import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/asiento.dart';
import '../../models/mapa_asientos.dart';
import '../../utils/formatos.dart';
import 'asiento_widget.dart';
import 'fuselaje_painter.dart';
import 'leyenda_asientos.dart';

/// Mapa de asientos que simula el avión real (vista superior, nariz arriba).
/// Se reutiliza en la selección del cliente, en el manifiesto y en la vista previa del administrador.
class MapaAvion extends StatefulWidget {
  final MapaAsientos mapa;
  final Set<String> seleccionados;
  final Set<String> propios; // "Tus asientos" en modo edición
  final bool soloLectura;
  final void Function(Asiento asiento)? alTocar;
  final bool mostrarEncabezado;

  const MapaAvion({
    super.key,
    required this.mapa,
    this.seleccionados = const {},
    this.propios = const {},
    this.soloLectura = false,
    this.alTocar,
    this.mostrarEncabezado = true,
  });

  @override
  State<MapaAvion> createState() => _MapaAvionState();
}

class _MapaAvionState extends State<MapaAvion> {
  static const double _anchoSeparador = 28; // pasillo
  static const double _margenLateral = 44; // espacio para las etiquetas de salida
  static const double _altoSeccion = 62;
  static const double _altoEco = 46, _altoEj = 52, _extraSalida = 16;

  final _controlador = TransformationController();
  Size? _viewport;
  late _Disposicion _d;

  @override
  void initState() {
    super.initState();
    _d = _Disposicion.calcular(widget.mapa);
  }

  @override
  void didUpdateWidget(covariant MapaAvion old) {
    super.didUpdateWidget(old);
    if (old.mapa != widget.mapa) {
      _d = _Disposicion.calcular(widget.mapa);
      WidgetsBinding.instance.addPostFrameCallback((_) => _centrar());
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _centrar() {
    final vp = _viewport;
    if (vp == null || !mounted) return;
    final escala = math.min(1.0, vp.width / _d.anchoTotal);
    final m = Matrix4.diagonal3Values(escala, escala, 1);
    m.setTranslationRaw(math.max(0, (vp.width - _d.anchoTotal * escala) / 2), 0, 0);
    _controlador.value = m;
  }

  void _zoom(double factor) {
    final vp = _viewport ?? const Size(400, 400);
    final actual = _controlador.value.getMaxScaleOnAxis();
    final nuevo = (actual * factor).clamp(0.3, 2.5);
    final f = nuevo / actual;
    final centro = Offset(vp.width / 2, vp.height / 2);
    final m = _controlador.value.clone();
    m.translateByDouble(centro.dx, centro.dy, 0, 1);
    m.scaleByDouble(f, f, 1, 1);
    m.translateByDouble(-centro.dx, -centro.dy, 0, 1);
    _controlador.value = m;
  }

  EstadoVisual _estado(Asiento a) {
    final sel = widget.seleccionados.contains(a.codigo);
    final propio = widget.propios.contains(a.codigo);
    if (propio) return sel ? EstadoVisual.propio : EstadoVisual.disponible; // soltado: vuelve a disponible
    if (a.ocupado) return EstadoVisual.ocupado;
    return sel ? EstadoVisual.seleccionado : EstadoVisual.disponible;
  }

  String _posicion(String letra, List<String> grupos) {
    final todas = grupos.join();
    if (letra == todas[0] || letra == todas[todas.length - 1]) return 'Ventana';
    for (var i = 0; i < grupos.length; i++) {
      final g = grupos[i];
      if ((letra == g[0] && i > 0) || (letra == g[g.length - 1] && i < grupos.length - 1)) return 'Pasillo';
    }
    return 'Centro';
  }

  Widget _fila(int fila, _Disposicion d) {
    final ej = fila <= widget.mapa.filasEjecutiva;
    final grupos = ej ? d.gruposEj : d.gruposEco;
    final porLetra = d.porFila[fila] ?? {};
    final salida = widget.mapa.filasSalida.contains(fila);
    final seatsRow = <Widget>[];
    for (var gi = 0; gi < grupos.length; gi++) {
      if (gi > 0) {
        seatsRow.add(SizedBox(
          width: _anchoSeparador,
          child: Center(child: Text('$fila', style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade400, fontWeight: FontWeight.w600))),
        ));
      }
      for (final letra in grupos[gi].split('')) {
        final a = porLetra[letra];
        seatsRow.add(a == null
            ? SizedBox(width: ej ? 50 : 40)
            : AsientoWidget(
                asiento: a,
                estado: _estado(a),
                posicion: _posicion(letra, grupos),
                alTocar: widget.soloLectura || widget.alTocar == null ? null : () => widget.alTocar!(a),
              ));
      }
    }
    Widget etiqueta() => SizedBox(
          width: _margenLateral,
          child: salida
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.exit_to_app, size: 13, color: Colors.red.shade700),
                  Text('SALIDA', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                ])
              : null,
        );
    return Padding(
      padding: EdgeInsets.only(top: salida ? _extraSalida : 0),
      child: SizedBox(
        height: ej ? _altoEj : _altoEco,
        child: Row(children: [
          etiqueta(),
          Expanded(child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: seatsRow))),
          etiqueta(),
        ]),
      ),
    );
  }

  Widget _seccion(String titulo, Color fondo, Color texto, List<String> grupos, double anchoAsiento) {
    return SizedBox(
      height: _altoSeccion,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(children: [
          Container(
            height: 24,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(8)),
            child: Text(titulo, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, color: texto)),
          ),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var gi = 0; gi < grupos.length; gi++) ...[
              if (gi > 0) const SizedBox(width: _anchoSeparador),
              for (final l in grupos[gi].split(''))
                SizedBox(
                  width: anchoAsiento + 4,
                  child: Center(child: Text(l, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade600))),
                ),
            ],
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mapa;
    final d = _d;
    final w = d.anchoCabina;
    final nariz = w * 0.85, cola = w * 0.9;
    const topPad = 0.0;

    // Construye las filas y calcula la posición vertical de cada una
    final hijos = <Widget>[];
    final centros = <double>[];
    double y = nariz + 24 + topPad;
    double? yPrimeraSalida;
    final inicioY = y;
    for (var fila = 1; fila <= m.filas; fila++) {
      final ej = fila <= m.filasEjecutiva;
      if (fila == 1 && m.filasEjecutiva > 0) {
        hijos.add(_seccion('CLASE EJECUTIVA', doradoClaro, const Color(0xFF7A5C00), d.gruposEj, 46));
        y += _altoSeccion;
      }
      if (fila == m.filasEjecutiva + 1) {
        hijos.add(_seccion('CLASE ECONÓMICA', const Color(0xFFDCEBFA), const Color(0xFF1B4F8A), d.gruposEco, 36));
        y += _altoSeccion;
      }
      final salida = m.filasSalida.contains(fila);
      if (salida) yPrimeraSalida ??= y;
      final alto = ej ? _altoEj : _altoEco;
      y += salida ? _extraSalida : 0;
      centros.add(y + alto / 2);
      y += alto;
      hijos.add(_fila(fila, d));
    }
    final largoFilas = y - inicioY;
    final yAlas = yPrimeraSalida != null ? yPrimeraSalida - 10 : inicioY + largoFilas * 0.4;
    final alto = math.max(y + cola + 20, yAlas + w * 0.8);

    final cabina = SizedBox(
      width: d.anchoTotal,
      height: alto,
      child: Stack(children: [
        Positioned(
          left: d.margenAlas,
          top: 0,
          width: w,
          height: alto,
          child: CustomPaint(painter: FuselajePainter(yAlas: yAlas, centrosFilas: centros)),
        ),
        // Cabina del piloto (decorativa)
        Positioned(
          left: d.margenAlas,
          top: nariz * 0.42,
          width: w,
          child: Column(children: [
            Icon(Icons.airline_seat_flat, size: 30, color: Colors.blueGrey.shade400),
            Text('CABINA', style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.blueGrey.shade500, fontWeight: FontWeight.bold)),
          ]),
        ),
        Positioned(
          left: d.margenAlas,
          top: nariz + 24,
          width: w,
          child: Column(children: hijos),
        ),
        // Servicios de la cola (decorativos)
        Positioned(
          left: d.margenAlas,
          top: y + cola * 0.12,
          width: w,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.wc, size: 22, color: Colors.blueGrey.shade400),
            const SizedBox(width: 6),
            Text('Baños · Galley', style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade500)),
          ]),
        ),
      ]),
    );

    return Column(children: [
      if (widget.mostrarEncabezado) _encabezado(context),
      Expanded(
        child: LayoutBuilder(builder: (context, c) {
          if (_viewport?.width != c.maxWidth) {
            // Primera vez o cambio de ancho: ajusta el zoom para que el avión quepa y quede centrado
            _viewport = Size(c.maxWidth, c.maxHeight);
            WidgetsBinding.instance.addPostFrameCallback((_) => _centrar());
          } else {
            _viewport = Size(c.maxWidth, c.maxHeight);
          }
          return Stack(children: [
            Positioned.fill(
              child: ClipRect(
                child: InteractiveViewer(
                  transformationController: _controlador,
                  constrained: false,
                  minScale: 0.3,
                  maxScale: 2.5,
                  boundaryMargin: const EdgeInsets.all(160),
                  child: cabina,
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(children: [
                FloatingActionButton.small(heroTag: null, tooltip: 'Acercar', onPressed: () => _zoom(1.25), child: const Icon(Icons.add)),
                const SizedBox(height: 6),
                FloatingActionButton.small(heroTag: null, tooltip: 'Alejar', onPressed: () => _zoom(0.8), child: const Icon(Icons.remove)),
                const SizedBox(height: 6),
                FloatingActionButton.small(heroTag: null, tooltip: 'Centrar', onPressed: _centrar, child: const Icon(Icons.center_focus_strong)),
              ]),
            ),
          ]);
        }),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: LeyendaAsientos(mostrarPropios: widget.propios.isNotEmpty, mostrarSeleccion: !widget.soloLectura),
      ),
    ]);
  }

  Widget _encabezado(BuildContext context) {
    final m = widget.mapa;
    final t = Theme.of(context);
    final titulo = m.vueloId == null
        ? '${m.modelo} · ${m.matricula}'
        : '${m.codigoVuelo} · ${m.origen} → ${m.destino} · ${Formatos.fecha(m.fecha)} ${Formatos.hora(m.horaSalida)}';
    return Container(
      width: double.infinity,
      color: t.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            if (m.vueloId != null) Text('${m.modelo} · ${m.matricula}', style: t.textTheme.bodySmall),
          ]),
        ),
        Chip(
          avatar: const Icon(Icons.event_seat, size: 16),
          label: Text('${m.resumen.disponibles} de ${m.resumen.total} libres'),
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }
}

/// Medidas calculadas del avión (ancho de cabina, grupos de asientos, asientos por fila).
class _Disposicion {
  final List<String> gruposEco, gruposEj;
  final double anchoCabina, margenAlas, anchoTotal;
  final Map<int, Map<String, Asiento>> porFila;

  _Disposicion(this.gruposEco, this.gruposEj, this.anchoCabina, this.margenAlas, this.anchoTotal, this.porFila);

  static _Disposicion calcular(MapaAsientos m) {
    final eco = m.configuracion.split('-');
    final ej = (m.configuracionEjecutiva ?? m.configuracion).split('-');
    final ecoW = eco.join().length * 40 + (eco.length - 1) * _MapaAvionState._anchoSeparador;
    final ejW = ej.join().length * 50 + (ej.length - 1) * _MapaAvionState._anchoSeparador;
    final cabina = math.max(ecoW, ejW) + _MapaAvionState._margenLateral * 2;
    final alas = cabina * 1.15;
    final porFila = <int, Map<String, Asiento>>{};
    for (final a in m.asientos) {
      porFila.putIfAbsent(a.fila, () => {})[a.columna] = a;
    }
    return _Disposicion(eco, ej, cabina, alas, cabina + alas * 2, porFila);
  }
}
