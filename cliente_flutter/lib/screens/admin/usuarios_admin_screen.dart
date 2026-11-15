import 'package:flutter/material.dart';

import '../../models/usuario.dart';
import '../../services/admin_service.dart';
import '../../sesion.dart';
import '../../utils/ui.dart';
import '../../widgets/cargando.dart';
import '../../widgets/error_reintentar.dart';
import '../../widgets/vacio.dart';

class UsuariosAdminScreen extends StatefulWidget {
  const UsuariosAdminScreen({super.key});

  @override
  State<UsuariosAdminScreen> createState() => _UsuariosAdminScreenState();
}

class _UsuariosAdminScreenState extends State<UsuariosAdminScreen> {
  final _busqueda = TextEditingController();
  String? _rol;
  bool? _activo;
  List<Usuario>? _usuarios;
  Object? _error;
  bool _cargando = false;
  int _peticion = 0; // descarta respuestas atrasadas cuando hay varias búsquedas seguidas

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final mia = ++_peticion;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final u = await AdminService.usuarios(rol: _rol, activo: _activo, buscar: _busqueda.text.trim());
      if (mounted && mia == _peticion) setState(() => _usuarios = u);
    } catch (e) {
      if (mounted && mia == _peticion) setState(() => _error = e);
    } finally {
      if (mounted && mia == _peticion) setState(() => _cargando = false);
    }
  }

  Future<void> _cambiarActivo(Usuario u, bool activo) async {
    final ok = await confirmar(
      context,
      titulo: activo ? 'Activar usuario' : 'Desactivar usuario',
      mensaje: activo
          ? '¿Permitir que ${u.nombreCompleto} vuelva a iniciar sesión?'
          : '${u.nombreCompleto} no podrá iniciar sesión y su sesión actual se cerrará de inmediato.',
      aceptar: activo ? 'Activar' : 'Desactivar',
      peligro: !activo,
    );
    if (!ok || !mounted) return;
    try {
      await AdminService.modificarUsuario(u.id, activo: activo);
      if (mounted) mostrarMensaje(context, 'Usuario ${activo ? 'activado' : 'desactivado'}');
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
    _cargar();
  }

  Future<void> _cambiarRol(Usuario u, String rol) async {
    if (rol == u.rol) return;
    final ok = await confirmar(
      context,
      titulo: 'Cambiar rol',
      mensaje: '${u.nombreCompleto} pasará de ${u.rol} a $rol. El cambio se aplica de inmediato.',
      aceptar: 'Cambiar',
    );
    if (!ok || !mounted) return;
    try {
      await AdminService.modificarUsuario(u.id, rol: rol);
      if (mounted) mostrarMensaje(context, 'Rol actualizado');
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final yo = Sesion.instancia.usuario?.id;
    final filtros = Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: _busqueda,
            onSubmitted: (_) => _cargar(),
            decoration: const InputDecoration(labelText: 'Buscar por nombre, correo o cédula', isDense: true, prefixIcon: Icon(Icons.search)),
          ),
        ),
        FilledButton.icon(onPressed: _cargando ? null : _cargar, icon: const Icon(Icons.search), label: const Text('Buscar')),
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<String?>(
            initialValue: _rol,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Rol', isDense: true),
            items: const [
              DropdownMenuItem(value: null, child: Text('Todos')),
              DropdownMenuItem(value: 'cliente', child: Text('Cliente')),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
            ],
            onChanged: (v) {
              setState(() => _rol = v);
              _cargar();
            },
          ),
        ),
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<bool?>(
            initialValue: _activo,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Estado', isDense: true),
            items: const [
              DropdownMenuItem(value: null, child: Text('Todos')),
              DropdownMenuItem(value: true, child: Text('Activos')),
              DropdownMenuItem(value: false, child: Text('Inactivos')),
            ],
            onChanged: (v) {
              setState(() => _activo = v);
              _cargar();
            },
          ),
        ),
        IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: _cargando ? null : _cargar),
      ]),
    );

    Widget lista;
    if (_error != null && _usuarios == null) {
      lista = ErrorReintentar(error: _error!, alReintentar: _cargar);
    } else if (_usuarios == null) {
      lista = const Cargando();
    } else if (_usuarios!.isEmpty) {
      lista = const Vacio('No se encontraron usuarios.', icono: Icons.people_outline);
    } else {
      lista = ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        itemCount: _usuarios!.length,
        itemBuilder: (_, i) {
          final u = _usuarios![i];
          final soyYo = u.id == yo;
          return Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: u.esAdmin ? Colors.red.shade100 : t.colorScheme.primaryContainer,
                  child: Icon(u.esAdmin ? Icons.admin_panel_settings : Icons.person, color: u.esAdmin ? Colors.red.shade700 : t.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${u.nombreCompleto}${soyYo ? '  (usted)' : ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${u.correo} · CI ${u.cedula}', style: t.textTheme.bodySmall),
                    Text('${u.totalReservas} reservas', style: t.textTheme.bodySmall),
                  ]),
                ),
                DropdownButton<String>(
                  value: u.rol,
                  underline: const SizedBox.shrink(),
                  items: const [DropdownMenuItem(value: 'cliente', child: Text('Cliente')), DropdownMenuItem(value: 'admin', child: Text('Admin'))],
                  onChanged: soyYo ? null : (r) => _cambiarRol(u, r!),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: soyYo ? 'No puede desactivarse a sí mismo' : (u.activo ? 'Desactivar' : 'Activar'),
                  child: Switch(value: u.activo, onChanged: soyYo ? null : (v) => _cambiarActivo(u, v)),
                ),
              ]),
            ),
          );
        },
      );
    }

    return Column(children: [
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: filtros)),
      if (_cargando && _usuarios != null) const LinearProgressIndicator(),
      Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: lista))),
    ]);
  }
}
