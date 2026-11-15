import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/reserva_service.dart';
import '../../utils/ui.dart';
import '../../widgets/cargando.dart';
import '../../widgets/error_reintentar.dart';

/// Comprobante en XML con resaltado simple de etiquetas, fuente monoespaciada y fondo oscuro.
class ComprobanteScreen extends StatefulWidget {
  final int reservaId;
  final String codigo;
  const ComprobanteScreen({super.key, required this.reservaId, required this.codigo});

  @override
  State<ComprobanteScreen> createState() => _ComprobanteScreenState();
}

class _ComprobanteScreenState extends State<ComprobanteScreen> {
  String? _xml;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final x = await ReservaService.facturaXml(widget.reservaId);
      if (mounted) setState(() => _xml = x);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: _xml ?? ''));
    if (mounted) mostrarMensaje(context, 'Comprobante copiado al portapapeles');
  }

  Future<void> _guardar() async {
    try {
      final base = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '.';
      final dir = Directory('$base${Platform.pathSeparator}Downloads');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final archivo = File('${dir.path}${Platform.pathSeparator}comprobante_${widget.codigo}.xml');
      await archivo.writeAsString(_xml ?? '', flush: true);
      if (mounted) mostrarMensaje(context, 'Guardado en ${archivo.path}');
    } catch (e) {
      if (mounted) mostrarError(context, 'No se pudo guardar el archivo');
    }
  }

  /// Colorea `<etiquetas>` y su contenido.
  List<TextSpan> _resaltar(String xml) {
    const estiloBase = TextStyle(fontFamily: 'monospace', fontSize: 13.5, height: 1.5);
    final etiqueta = estiloBase.copyWith(color: const Color(0xFF7CC4FF));
    final atributo = estiloBase.copyWith(color: const Color(0xFFFFB86C));
    final contenido = estiloBase.copyWith(color: const Color(0xFFA6E3A1));
    final cabecera = estiloBase.copyWith(color: const Color(0xFF8A94A6));
    final spans = <TextSpan>[];
    final re = RegExp(r'(<\?.*?\?>)|(<[^>]+>)|([^<]+)', dotAll: true);
    for (final m in re.allMatches(xml)) {
      if (m.group(1) != null) {
        spans.add(TextSpan(text: m.group(1), style: cabecera));
      } else if (m.group(2) != null) {
        final tag = m.group(2)!;
        final i = tag.indexOf(' ');
        if (i < 0) {
          spans.add(TextSpan(text: tag, style: etiqueta));
        } else {
          spans.add(TextSpan(text: tag.substring(0, i), style: etiqueta));
          spans.add(TextSpan(text: tag.substring(i, tag.length - 1), style: atributo));
          spans.add(TextSpan(text: '>', style: etiqueta));
        }
      } else {
        final txt = m.group(3)!;
        spans.add(TextSpan(text: txt, style: txt.trim().isEmpty ? estiloBase : contenido));
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comprobante ${widget.codigo}'),
        actions: [
          IconButton(tooltip: 'Copiar', icon: const Icon(Icons.copy), onPressed: _xml == null ? null : _copiar),
          if (!kIsWeb) IconButton(tooltip: 'Guardar en Descargas', icon: const Icon(Icons.download), onPressed: _xml == null ? null : _guardar),
        ],
      ),
      body: _error != null
          ? ErrorReintentar(error: _error!, alReintentar: _cargar)
          : _xml == null
              ? const Cargando()
              : Container(
                  color: const Color(0xFF1E1F29),
                  width: double.infinity,
                  height: double.infinity,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SelectableText.rich(TextSpan(children: _resaltar(_xml!))),
                    ),
                  ),
                ),
    );
  }
}
