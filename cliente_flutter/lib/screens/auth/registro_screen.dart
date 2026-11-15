import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/usuario_service.dart';
import '../../sesion.dart';
import '../../utils/ui.dart';
import '../../utils/validadores.dart';
import '../../widgets/campo_texto.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _form = GlobalKey<FormState>();
  final _c = {for (final k in ['nombre', 'apellido', 'cedula', 'telefono', 'correo', 'password', 'confirmar']) k: TextEditingController()};
  Map<String, String> _errores = {}; // errores devueltos por el backend, por campo
  bool _ver = false;
  bool _cargando = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _limpiarError(String campo) {
    if (_errores.containsKey(campo)) setState(() => _errores = {..._errores}..remove(campo));
  }

  Future<void> _registrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _errores = {};
    });
    try {
      await UsuarioService.registrar(
        nombre: _c['nombre']!.text,
        apellido: _c['apellido']!.text,
        cedula: _c['cedula']!.text,
        telefono: _c['telefono']!.text,
        correo: _c['correo']!.text,
        password: _c['password']!.text,
      );
      await AuthService.login(_c['correo']!.text, _c['password']!.text);
      if (!mounted) return;
      mostrarMensaje(context, 'Cuenta creada. ¡Bienvenido a AeroTech!');
      Navigator.of(context).pushNamedAndRemoveUntil(Sesion.instancia.rutaInicio, (_) => false);
    } on ApiException catch (e) {
      final errores = {...e.campos};
      if (e.codigo == 409) {
        // Duplicados: el backend responde sin `campos`; se asigna al campo correspondiente.
        if (e.mensaje.contains('correo')) errores['correo'] = e.mensaje;
        if (e.mensaje.contains('cédula')) errores['cedula'] = e.mensaje;
      }
      setState(() => _errores = errores);
      mostrarError(context, e);
    } catch (e) {
      mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Widget _campo(String clave, String etiqueta, IconData icono, String? Function(String?) validador,
      {TextInputType? teclado, int? maxLength, List<TextInputFormatter>? formatos, bool oculto = false, Widget? sufijo}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: CampoTexto(
        controller: _c[clave]!,
        etiqueta: etiqueta,
        icono: icono,
        validator: validador,
        errorServidor: _errores[clave],
        alCambiar: () => _limpiarError(clave),
        teclado: teclado,
        maxLength: maxLength,
        formatos: formatos,
        oculto: oculto,
        sufijo: sufijo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final soloDigitos = [FilteringTextInputFormatter.digitsOnly];
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Form(
              key: _form,
              child: Column(children: [
                _campo('nombre', 'Nombre', Icons.person_outline, Validadores.nombre),
                _campo('apellido', 'Apellido', Icons.person_outline, Validadores.nombre),
                _campo('cedula', 'Cédula', Icons.badge_outlined, Validadores.cedula,
                    teclado: TextInputType.number, maxLength: 10, formatos: soloDigitos),
                _campo('telefono', 'Teléfono celular (09XXXXXXXX)', Icons.phone_outlined, Validadores.telefono,
                    teclado: TextInputType.phone, maxLength: 10, formatos: soloDigitos),
                _campo('correo', 'Correo electrónico', Icons.email_outlined, Validadores.correo,
                    teclado: TextInputType.emailAddress),
                _campo('password', 'Contraseña', Icons.lock_outline, Validadores.password,
                    oculto: !_ver,
                    sufijo: IconButton(
                      tooltip: _ver ? 'Ocultar contraseña' : 'Mostrar contraseña',
                      icon: Icon(_ver ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _ver = !_ver),
                    )),
                _campo('confirmar', 'Confirmar contraseña', Icons.lock_outline,
                    (v) => Validadores.confirmar(v, _c['password']!.text),
                    oculto: !_ver),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _cargando ? null : _registrar,
                    child: _cargando
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Text('Crear cuenta'),
                  ),
                ),
                TextButton(
                  onPressed: _cargando ? null : () => Navigator.of(context).pop(),
                  child: const Text('¿Ya tiene cuenta? Iniciar sesión'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
