import 'package:flutter/material.dart';

import '../../models/json_util.dart';
import '../../models/vuelo.dart';
import '../../services/admin_service.dart';
import '../../utils/formatos.dart';
import '../../widgets/cargando.dart';
import '../../widgets/error_reintentar.dart';
import '../../widgets/estado_chip.dart';
import '../../widgets/vacio.dart';
import '../cliente/detalle_reserva_screen.dart';

class ReservasAdminScreen extends StatefulWidget {
  const ReservasAdminScreen({super.key});

  @override
  State<ReservasAdminScreen> createState() => _ReservasAdminScreenState();
}

class _ReservasAdminScreenState extends State<ReservasAdminScreen> {
  final _busqueda = TextEditingController();
  String? _estado;
  Vuelo? _vuelo;
  List<Vuelo> _vuelos = [];

  List<Map<String, dynamic>>? _reservas;
  Object? _error;
  bool _cargando = false;
  int _peticion = 0; // descarta respuestas atrasadas

  @override
  void initState() {
    super.initState();
    _inicio();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _inicio() async {
    try {
      _vuelos = await AdminService.vuelos();
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
      // El buscador sirve para código de reserva (6 caracteres) o correo
      final texto = _busqueda.text.trim();
      final esCodigo = texto.length == 6 && !texto.contains('@');
      final r = await AdminService.reservas(
        estado: _estado,
        vueloId: _vuelo?.id,
        codigo: esCodigo ? texto : null,
        correo: !esCodigo && texto.isNotEmpty ? texto : null,
      );
      if (mounted && mia == _peticion) setState(() => _reservas = r);
    } catch (e) {
      if (mounted && mia == _peticion) setState(() => _error = e);
    } finally {
      if (mounted && mia == _peticion) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final filtros = Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: _busqueda,
            onSubmitted: (_) => _cargar(),
            decoration: InputDecoration(
              labelText: 'Código de reserva o correo',
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _busqueda.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _busqueda.clear();
                        _cargar();
                      },
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        FilledButton.icon(onPressed: _cargando ? null : _cargar, icon: const Icon(Icons.search), label: const Text('Buscar')),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String?>(
            initialValue: _estado,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Estado', isDense: true),
            items: const [
              DropdownMenuItem(value: null, child: Text('Todas')),
              DropdownMenuItem(value: 'confirmada', child: Text('Confirmadas')),
              DropdownMenuItem(value: 'cancelada', child: Text('Canceladas')),
            ],
            onChanged: (v) {
              setState(() => _estado = v);
              _cargar();
            },
          ),
        ),
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<Vuelo?>(
            initialValue: _vuelo,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Vuelo', isDense: true),
            items: [
              const DropdownMenuItem<Vuelo?>(value: null, child: Text('Todos los vuelos')),
              for (final v in _vuelos) DropdownMenuItem<Vuelo?>(value: v, child: Text('${v.codigoVuelo} · ${v.origen}→${v.destino} · ${Formatos.fecha(v.fecha)}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              setState(() => _vuelo = v);
              _cargar();
            },
          ),
        ),
        IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: _cargando ? null : _cargar),
      ]),
    );

    Widget lista;
    if (_error != null && _reservas == null) {
      lista = ErrorReintentar(error: _error!, alReintentar: _cargar);
    } else if (_reservas == null) {
      lista = const Cargando();
    } else if (_reservas!.isEmpty) {
      lista = const Vacio('No se encontraron reservas.', icono: Icons.confirmation_number_outlined);
    } else {
      lista = ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        itemCount: _reservas!.length,
        itemBuilder: (_, i) {
          final r = _reservas![i];
          return Card(
            child: ListTile(
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetalleReservaScreen(reservaId: entero(r['id']))));
                _cargar();
              },
              title: Row(children: [
                Text('${r['codigo_reserva']}', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'monospace')),
                const SizedBox(width: 10),
                EstadoChip('${r['estado']}'),
              ]),
              subtitle: Text('${r['usuario']} · ${r['correo']}\n${r['codigo_vuelo']} · ${r['origen']} → ${r['destino']} · ${Formatos.fecha(r['fecha'])} · ${entero(r['cantidad_asientos'])} asientos'
                  '${(r['motivo_cancelacion'] ?? '').toString().isEmpty ? '' : '\nMotivo: ${r['motivo_cancelacion']}'}'),
              isThreeLine: true,
              trailing: Text(Formatos.moneda(numero(r['total'])), style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
          );
        },
      );
    }

    return Column(children: [
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: filtros)),
      if (_cargando && _reservas != null) const LinearProgressIndicator(),
      Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: lista))),
    ]);
  }
}
