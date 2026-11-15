import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../sesion.dart';
import '../../utils/ui.dart';
import '../../utils/validadores.dart';
import '../../widgets/campo_texto.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _password = TextEditingController();
  bool _ver = false;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    // Si venimos de una expulsión (token revocado / cuenta desactivada) se muestra el motivo una vez
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final aviso = avisoLogin.value;
      if (aviso != null && mounted) {
        avisoLogin.value = null;
        mostrarError(context, aviso);
      }
    });
  }

  @override
  void dispose() {
    _correo.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await AuthService.login(_correo.text, _password.text);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(Sesion.instancia.rutaInicio, (_) => false);
    } catch (e) {
      mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _form,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: t.colorScheme.primaryContainer,
                  child: Icon(Icons.flight_takeoff, size: 44, color: t.colorScheme.primary),
                ),
                const SizedBox(height: 16),
                Text('AeroTech – Reservas de vuelos',
                    textAlign: TextAlign.center, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 28),
                CampoTexto(
                  controller: _correo,
                  etiqueta: 'Correo electrónico',
                  icono: Icons.email_outlined,
                  teclado: TextInputType.emailAddress,
                  accion: TextInputAction.next,
                  validator: Validadores.correo,
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  controller: _password,
                  etiqueta: 'Contraseña',
                  icono: Icons.lock_outline,
                  oculto: !_ver,
                  accion: TextInputAction.done,
                  alEnviar: (_) => _entrar(),
                  validator: (v) => Validadores.obligatorio(v, 'Ingrese su contraseña'),
                  sufijo: IconButton(
                    tooltip: _ver ? 'Ocultar contraseña' : 'Mostrar contraseña',
                    icon: Icon(_ver ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _ver = !_ver),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _cargando ? null : _entrar,
                    child: _cargando
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Text('Iniciar sesión'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _cargando ? null : () => Navigator.of(context).pushNamed('/registro'),
                  child: const Text('¿No tiene cuenta? Crear cuenta'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
