import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/usuario.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/usuario_service.dart';
import '../../utils/ui.dart';
import '../../utils/validadores.dart';
import '../../widgets/cargando.dart';
import '../../widgets/error_reintentar.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  Usuario? _u;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final u = await UsuarioService.perfil();
      if (mounted) setState(() => _u = u);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _editar() async {
    final u = _u!;
    final nombre = TextEditingController(text: u.nombre);
    final apellido = TextEditingController(text: u.apellido);
    final telefono = TextEditingController(text: u.telefono);
    final form = GlobalKey<FormState>();
    Map<String, String> errores = {};
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: const Text('Editar perfil'),
          content: Form(
            key: form,
            child: SizedBox(
              width: 380,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(controller: nombre, validator: Validadores.nombre, decoration: InputDecoration(labelText: 'Nombre', errorText: errores['nombre'])),
                const SizedBox(height: 12),
                TextFormField(controller: apellido, validator: Validadores.nombre, decoration: InputDecoration(labelText: 'Apellido', errorText: errores['apellido'])),
                const SizedBox(height: 12),
                TextFormField(
                  controller: telefono,
                  validator: Validadores.telefono,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: 'Teléfono', counterText: '', errorText: errores['telefono']),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                try {
                  await UsuarioService.editarPerfil(nombre: nombre.text, apellido: apellido.text, telefono: telefono.text);
                  if (d.mounted) Navigator.pop(d, true);
                } on ApiException catch (e) {
                  setD(() => errores = e.campos);
                  if (d.mounted) mostrarError(d, e);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _cargar();
      if (mounted) mostrarMensaje(context, 'Perfil actualizado');
    }
  }

  Future<void> _cambiarPassword() async {
    final actual = TextEditingController();
    final nueva = TextEditingController();
    final repetir = TextEditingController();
    final form = GlobalKey<FormState>();
    Map<String, String> errores = {};
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: const Text('Cambiar contraseña'),
          content: Form(
            key: form,
            child: SizedBox(
              width: 380,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: actual,
                  obscureText: true,
                  validator: (v) => Validadores.obligatorio(v, 'Ingrese su contraseña actual'),
                  decoration: InputDecoration(labelText: 'Contraseña actual', errorText: errores['password_actual']),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nueva,
                  obscureText: true,
                  validator: Validadores.password,
                  decoration: InputDecoration(labelText: 'Contraseña nueva', errorText: errores['password_nueva']),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: repetir,
                  obscureText: true,
                  validator: (v) => Validadores.confirmar(v, nueva.text),
                  decoration: const InputDecoration(labelText: 'Repetir contraseña nueva'),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                try {
                  await UsuarioService.cambiarPassword(actual.text, nueva.text);
                  if (d.mounted) Navigator.pop(d, true);
                } on ApiException catch (e) {
                  setD(() => errores = e.campos);
                  if (d.mounted) mostrarError(d, e);
                }
              },
              child: const Text('Cambiar'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) mostrarMensaje(context, 'Contraseña actualizada');
  }

  Future<void> _cerrarSesion() async {
    await AuthService.logout();
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/inicio', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorReintentar(error: _error!, alReintentar: _cargar);
    final u = _u;
    if (u == null) return const Cargando();
    final t = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: t.colorScheme.primaryContainer,
                  child: Text('${u.nombre[0]}${u.apellido[0]}'.toUpperCase(), style: t.textTheme.headlineSmall),
                ),
                const SizedBox(height: 12),
                Text(u.nombreCompleto, style: t.textTheme.titleLarge),
                Text(u.correo, style: t.textTheme.bodyMedium),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _estadistica(t, '${u.totalReservas}', 'Reservas totales')),
                  Expanded(child: _estadistica(t, '${u.reservasActivas}', 'Reservas activas')),
                ]),
              ]),
            ),
          ),
          Card(
            child: Column(children: [
              ListTile(leading: const Icon(Icons.badge_outlined), title: const Text('Cédula'), subtitle: Text(u.cedula)),
              ListTile(leading: const Icon(Icons.phone_outlined), title: const Text('Teléfono'), subtitle: Text(u.telefono)),
            ]),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(onPressed: _editar, icon: const Icon(Icons.edit), label: const Text('Editar datos')),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(onPressed: _cambiarPassword, icon: const Icon(Icons.lock_reset), label: const Text('Cambiar contraseña')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _cerrarSesion,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ]),
      ),
    );
  }

  Widget _estadistica(ThemeData t, String n, String etiqueta) => Column(children: [
        Text(n, style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: t.colorScheme.primary)),
        Text(etiqueta, style: t.textTheme.bodySmall),
      ]);
}
