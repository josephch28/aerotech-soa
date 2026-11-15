import 'package:flutter/material.dart';

import '../../models/aeropuerto.dart';
import '../../models/vuelo.dart';
import '../../services/admin_service.dart';
import '../../services/vuelo_service.dart';
import '../../utils/formatos.dart';
import '../../utils/ui.dart';
import '../../utils/validadores.dart';
import '../../widgets/cargando.dart';
import '../../widgets/error_reintentar.dart';
import '../../widgets/estado_chip.dart';
import '../../widgets/vacio.dart';
import 'manifiesto_screen.dart';
import 'vuelo_form_screen.dart';

class VuelosAdminScreen extends StatefulWidget {
  const VuelosAdminScreen({super.key});

  @override
  State<VuelosAdminScreen> createState() => _VuelosAdminScreenState();
}

class _VuelosAdminScreenState extends State<VuelosAdminScreen> {
  List<Aeropuerto> _aeropuertos = [];
  String? _estado;
  DateTime? _desde, _hasta;
  Aeropuerto? _origen, _destino;

  List<Vuelo>? _vuelos;
  Object? _error;
  bool _cargando = false;
  int _peticion = 0; // descarta respuestas atrasadas

  @override
  void initState() {
    super.initState();
    _inicio();
  }

  Future<void> _inicio() async {
    try {
      _aeropuertos = await VueloService.aeropuertos();
    } catch (_) {}
    await _cargar();
  }

  Future<void> _cargar() async {
    final mia = ++_peticion;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final v = await AdminService.vuelos(
        estado: _estado,
        desde: _desde == null ? null : Formatos.iso(_desde!),
        hasta: _hasta == null ? null : Formatos.iso(_hasta!),
        origen: _origen?.codigo,
        destino: _destino?.codigo,
      );
      if (mounted && mia == _peticion) setState(() => _vuelos = v);
    } catch (e) {
      if (mounted && mia == _peticion) setState(() => _error = e);
    } finally {
      if (mounted && mia == _peticion) setState(() => _cargando = false);
    }
  }

  Future<void> _fecha(bool desde) async {
    final base = desde ? _desde : _hasta;
    final f = await showDatePicker(
      context: context,
      locale: const Locale('es'),
      initialDate: base ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (f != null) {
      setState(() => desde ? _desde = f : _hasta = f);
      _cargar();
    }
  }

  Future<void> _nuevo() async {
    final creado = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const VueloFormScreen()));
    if (creado == true) _cargar();
  }

  Future<void> _editar(Vuelo v) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => VueloFormScreen(vuelo: v)));
    if (ok == true) _cargar();
  }

  Future<void> _cancelar(Vuelo v) async {
    int afectadas = 0;
    try {
      afectadas = (await AdminService.reservas(vueloId: v.id, estado: 'confirmada')).length;
    } catch (e) {
      if (mounted) mostrarError(context, e);
      return;
    }
    if (!mounted) return;
    final c = TextEditingController();
    final form = GlobalKey<FormState>();
    final motivo = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 36),
        title: Text('Cancelar vuelo ${v.codigoVuelo}'),
        content: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(afectadas == 0
                ? 'El vuelo no tiene reservas confirmadas.'
                : 'Se cancelarán $afectadas ${afectadas == 1 ? 'reserva' : 'reservas'} y se liberarán sus asientos. Esta acción no se puede deshacer.'),
            const SizedBox(height: 12),
            TextFormField(
              controller: c,
              maxLength: 200,
              maxLines: 2,
              validator: Validadores.motivo,
              decoration: const InputDecoration(labelText: 'Motivo (obligatorio)'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Volver')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(d, c.text.trim());
            },
            child: const Text('Cancelar vuelo'),
          ),
        ],
      ),
    );
    if (motivo == null || !mounted) return;
    try {
      final n = await AdminService.cancelarVuelo(v.id, motivo);
      if (mounted) mostrarMensaje(context, 'Vuelo cancelado. Reservas afectadas: $n');
      _cargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Widget _selector(String etiqueta, Aeropuerto? valor, ValueChanged<Aeropuerto?> alCambiar) => SizedBox(
        width: 190,
        child: DropdownButtonFormField<Aeropuerto?>(
          key: ValueKey('$etiqueta-${valor?.codigo}'),
          initialValue: valor,
          isExpanded: true,
          decoration: InputDecoration(labelText: etiqueta, isDense: true),
          items: [
            const DropdownMenuItem<Aeropuerto?>(value: null, child: Text('Todos')),
            ..._aeropuertos.map((a) => DropdownMenuItem<Aeropuerto?>(value: a, child: Text('${a.ciudad} (${a.codigo})', overflow: TextOverflow.ellipsis))),
          ],
          onChanged: (v) {
            alCambiar(v);
            _cargar();
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final filtros = Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String?>(
            initialValue: _estado,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Estado', isDense: true),
            items: const [
              DropdownMenuItem(value: null, child: Text('Todos')),
              DropdownMenuItem(value: 'programado', child: Text('Programado')),
              DropdownMenuItem(value: 'cancelado', child: Text('Cancelado')),
            ],
            onChanged: (v) {
              setState(() => _estado = v);
              _cargar();
            },
          ),
        ),
        OutlinedButton.icon(onPressed: () => _fecha(true), icon: const Icon(Icons.calendar_month, size: 18), label: Text(_desde == null ? 'Desde' : 'Desde ${Formatos.fecha(_desde!)}')),
        OutlinedButton.icon(onPressed: () => _fecha(false), icon: const Icon(Icons.calendar_month, size: 18), label: Text(_hasta == null ? 'Hasta' : 'Hasta ${Formatos.fecha(_hasta!)}')),
        if (_desde != null || _hasta != null)
          IconButton(
            tooltip: 'Quitar fechas',
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _desde = null;
                _hasta = null;
              });
              _cargar();
            },
          ),
        _selector('Origen', _origen, (v) => setState(() => _origen = v)),
        _selector('Destino', _destino, (v) => setState(() => _destino = v)),
        IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: _cargando ? null : _cargar),
      ]),
    );

    Widget lista;
    if (_error != null && _vuelos == null) {
      lista = ErrorReintentar(error: _error!, alReintentar: _cargar);
    } else if (_vuelos == null) {
      lista = const Cargando();
    } else if (_vuelos!.isEmpty) {
      lista = const Vacio('No hay vuelos con esos filtros.', icono: Icons.flight_outlined);
    } else {
      lista = ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
        itemCount: _vuelos!.length,
        itemBuilder: (_, i) {
          final v = _vuelos![i];
          final programado = v.estado == 'programado';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(v.codigoVuelo, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: t.colorScheme.primary)),
                  const SizedBox(width: 10),
                  Text('${v.origen} → ${v.destino}', style: t.textTheme.titleMedium),
                  const Spacer(),
                  EstadoChip(v.estado),
                  PopupMenuButton<String>(
                    tooltip: 'Acciones',
                    onSelected: (a) {
                      switch (a) {
                        case 'editar':
                          _editar(v);
                        case 'manifiesto':
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ManifiestoScreen(vuelo: v)));
                        case 'cancelar':
                          _cancelar(v);
                      }
                    },
                    itemBuilder: (_) => [
                      if (programado) const PopupMenuItem(value: 'editar', child: ListTile(leading: Icon(Icons.edit), title: Text('Editar'), dense: true)),
                      const PopupMenuItem(value: 'manifiesto', child: ListTile(leading: Icon(Icons.list_alt), title: Text('Ver manifiesto'), dense: true)),
                      if (programado) PopupMenuItem(value: 'cancelar', child: ListTile(leading: Icon(Icons.cancel, color: Colors.red.shade700), title: const Text('Cancelar vuelo'), dense: true)),
                    ],
                  ),
                ]),
                Text('${Formatos.fecha(v.fecha)} · ${Formatos.hora(v.horaSalida)} – ${Formatos.hora(v.horaLlegada)} · ${v.modeloAvion} (${v.matricula})', style: t.textTheme.bodySmall),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Ocupación ${v.ocupacion.toStringAsFixed(1)} % · ${v.capacidad - v.asientosDisponibles}/${v.capacidad} asientos', style: t.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: (v.ocupacion / 100).clamp(0, 1).toDouble(), minHeight: 8, borderRadius: BorderRadius.circular(4)),
                    ]),
                  ),
                  const SizedBox(width: 20),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Ingresos', style: t.textTheme.bodySmall),
                    Text(Formatos.moneda(v.ingresos), style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                ]),
              ]),
            ),
          );
        },
      );
    }

    return Scaffold(
      body: Column(children: [
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: filtros)),
        if (_cargando && _vuelos != null) const LinearProgressIndicator(),
        Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: lista))),
      ]),
      floatingActionButton: FloatingActionButton.extended(heroTag: null, onPressed: _nuevo, icon: const Icon(Icons.add), label: const Text('Nuevo vuelo')),
    );
  }
}
