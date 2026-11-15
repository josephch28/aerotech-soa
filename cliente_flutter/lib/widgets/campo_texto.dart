import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TextFormField estándar. Muestra el error que devolvió el backend (`campos`) mientras el usuario
/// no vuelva a escribir en el campo.
class CampoTexto extends StatelessWidget {
  final TextEditingController controller;
  final String etiqueta;
  final IconData? icono;
  final String? Function(String?)? validator;
  final String? errorServidor;
  final VoidCallback? alCambiar;
  final TextInputType? teclado;
  final bool oculto;
  final Widget? sufijo;
  final int? maxLength;
  final List<TextInputFormatter>? formatos;
  final bool soloLectura;
  final VoidCallback? alTocar;
  final TextInputAction? accion;
  final ValueChanged<String>? alEnviar;
  final String? ayuda;

  const CampoTexto({
    super.key,
    required this.controller,
    required this.etiqueta,
    this.icono,
    this.validator,
    this.errorServidor,
    this.alCambiar,
    this.teclado,
    this.oculto = false,
    this.sufijo,
    this.maxLength,
    this.formatos,
    this.soloLectura = false,
    this.alTocar,
    this.accion,
    this.alEnviar,
    this.ayuda,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: teclado,
      obscureText: oculto,
      maxLength: maxLength,
      inputFormatters: formatos,
      readOnly: soloLectura,
      onTap: alTocar,
      textInputAction: accion,
      onFieldSubmitted: alEnviar,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onChanged: (_) => alCambiar?.call(),
      decoration: InputDecoration(
        labelText: etiqueta,
        helperText: ayuda,
        prefixIcon: icono == null ? null : Icon(icono),
        suffixIcon: sufijo,
        counterText: '',
        errorText: errorServidor,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
