import 'package:flutter/material.dart';

import '../../models/avion.dart';
import '../../services/admin_service.dart';
import '../../utils/ui.dart';
import '../../widgets/cargando.dart';
import '../../widgets/error_reintentar.dart';
import '../../widgets/vacio.dart';
import 'avion_form_screen.dart';

class FlotaScreen extends StatefulWidget {
  const FlotaScreen({super.key});

  @override
  State<FlotaScreen> createState() => _FlotaScreenState();
}

class _FlotaScreenState extends State<FlotaScreen> {
  List<Avion>? _aviones;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final a = await AdminService.aviones();
      a.sort((x, y) => y.id.compareTo(x.id)); // los más recientes primero
      if (mounted) setState(() => _aviones = a);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _abrir([Avion? a]) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => AvionFormScreen(avion: a)));
    if (ok == true) _cargar();
  }

  Future<void> _cambiarEstado(Avion a, bool activo) async {
    try {
      await AdminService.estadoAvion(a.id, activo);
      if (mounted) mostrarMensaje(context, 'Avión ${a.matricula} ${activo ? 'activado' : 'desactivado'}');
    } catch (e) {
      if (mounted) mostrarError(context, e); // p. ej. 409: tiene vuelos programados
    }
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget cuerpo;
    if (_error != null && _aviones == null) {
      cuerpo = ErrorReintentar(error: _error!, alReintentar: _cargar);
    } else if (_aviones == null) {
      cuerpo = const Cargando();
    } else if (_aviones!.isEmpty) {
      cuerpo = const Vacio('No hay aviones registrados.', icono: Icons.airplanemode_inactive);
    } else {
      cuerpo = RefreshIndicator(
        onRefresh: _cargar,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          itemCount: _aviones!.length,
          itemBuilder: (_, i) {
            final a = _aviones![i];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: a.activo ? t.colorScheme.primaryContainer : Colors.grey.shade300,
                  child: Icon(Icons.airplanemode_active, color: a.activo ? t.colorScheme.primary : Colors.grey),
                ),
                title: Text('${a.modelo} · ${a.matricula}', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${a.capacidad} asientos · ${a.configuracion}${a.configuracionEjecutiva != null ? ' (ejecutiva ${a.configuracionEjecutiva})' : ''} · '
                    '${a.filas} filas (${a.filasEjecutiva} ejecutivas)\n'
                    'Vuelos futuros: ${a.vuelosFuturos}${a.filasSalida.isEmpty ? '' : ' · Salidas: filas ${a.filasSalida.join(', ')}'}'),
                isThreeLine: true,
                onTap: () => _abrir(a),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(a.activo ? 'Activo' : 'Inactivo', style: t.textTheme.bodySmall),
                  Switch(value: a.activo, onChanged: (v) => _cambiarEstado(a, v)),
                  IconButton(tooltip: 'Editar / ver mapa', icon: const Icon(Icons.edit), onPressed: () => _abrir(a)),
                ]),
              ),
            );
          },
        ),
      );
    }
    return Scaffold(
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: cuerpo)),
      floatingActionButton: FloatingActionButton.extended(heroTag: null, onPressed: () => _abrir(), icon: const Icon(Icons.add), label: const Text('Nuevo avión')),
    );
  }
}
