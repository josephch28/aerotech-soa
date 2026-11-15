import 'package:flutter/material.dart';

import '../../models/reserva.dart';
import '../../services/reserva_service.dart';
import '../../utils/formatos.dart';
import '../../widgets/cargando.dart';
import '../../widgets/error_reintentar.dart';
import '../../widgets/estado_chip.dart';
import '../../widgets/vacio.dart';
import 'detalle_reserva_screen.dart';

class MisReservasScreen extends StatelessWidget {
  /// Se incrementa para pedir que las listas se recarguen (al volver a la pestaña o tras un cambio).
  static final ValueNotifier<int> recargar = ValueNotifier(0);
  const MisReservasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        const TabBar(tabs: [Tab(text: 'Activas'), Tab(text: 'Canceladas')]),
        const Expanded(
          child: TabBarView(children: [
            _ListaReservas(estado: 'confirmada'),
            _ListaReservas(estado: 'cancelada'),
          ]),
        ),
      ]),
    );
  }
}

class _ListaReservas extends StatefulWidget {
  final String estado;
  const _ListaReservas({required this.estado});

  @override
  State<_ListaReservas> createState() => _ListaReservasState();
}

class _ListaReservasState extends State<_ListaReservas> with AutomaticKeepAliveClientMixin {
  List<Reserva>? _reservas;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    MisReservasScreen.recargar.addListener(_cargar);
    _cargar();
  }

  @override
  void dispose() {
    MisReservasScreen.recargar.removeListener(_cargar);
    super.dispose();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _error = null);
    try {
      final r = await ReservaService.mias(estado: widget.estado);
      if (mounted) setState(() => _reservas = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null && _reservas == null) return ErrorReintentar(error: _error!, alReintentar: _cargar);
    if (_reservas == null) return const Cargando();
    if (_reservas!.isEmpty) {
      return Vacio(widget.estado == 'confirmada' ? 'No tiene reservas activas.\nBusque un vuelo para reservar.' : 'No tiene reservas canceladas.',
          icono: Icons.confirmation_number_outlined);
    }
    final t = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _reservas!.length,
        itemBuilder: (_, i) {
          final r = _reservas![i];
          final v = r.vuelo;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetalleReservaScreen(reservaId: r.id)));
                    MisReservasScreen.recargar.value++;
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(r.codigoReserva,
                            style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 3, fontFamily: 'monospace')),
                        const Spacer(),
                        EstadoChip(r.estado),
                      ]),
                      const SizedBox(height: 6),
                      if (v != null) ...[
                        Text('${v.ciudadOrigen} (${v.origen}) → ${v.ciudadDestino} (${v.destino})', style: t.textTheme.titleSmall),
                        Text('${v.codigoVuelo} · ${Formatos.fecha(v.fecha)} · ${Formatos.hora(v.horaSalida)}', style: t.textTheme.bodySmall),
                      ],
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 4, children: [for (final a in r.asientos) Chip(label: Text(a), visualDensity: VisualDensity.compact)]),
                      const SizedBox(height: 6),
                      Row(children: [
                        Text('${r.cantidadAsientos} ${r.cantidadAsientos == 1 ? 'asiento' : 'asientos'}', style: t.textTheme.bodySmall),
                        const Spacer(),
                        Text(Formatos.moneda(r.total), style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ]),
                    ]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
