import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/avion.dart';
import '../../models/mapa_asientos.dart';
import '../../services/admin_service.dart';
import '../../services/api_client.dart';
import '../../utils/ui.dart';
import '../../utils/validadores.dart';
import '../../utils/vista_previa.dart';
import '../../widgets/campo_texto.dart';
import '../../widgets/mapa_asientos/mapa_asientos.dart';
import 'vuelo_form_screen.dart' show UpperCaseTextFormatter;

/// Crear o editar un avión, con vista previa en vivo del mapa de asientos.
class AvionFormScreen extends StatefulWidget {
  final Avion? avion;
  const AvionFormScreen({super.key, this.avion});

  @override
  State<AvionFormScreen> createState() => _AvionFormScreenState();
}

class _AvionFormScreenState extends State<AvionFormScreen> {
  final _form = GlobalKey<FormState>();
  final _modelo = TextEditingController();
  final _matricula = TextEditingController(text: 'HC-');
  final _config = TextEditingController();
  final _configEj = TextEditingController();
  final _filas = TextEditingController();
  final _filasEj = TextEditingController(text: '0');
  final _nuevaSalida = TextEditingController();
  final Set<int> _salidas = {};
  Map<String, String> _errores = {};
  bool _guardando = false;

  MapaAsientos? _preview;
  String _claveVista = '';

  Avion? get _a => widget.avion;

  @override
  void initState() {
    super.initState();
    final a = _a;
    if (a != null) {
      _modelo.text = a.modelo;
      _matricula.text = a.matricula;
      _config.text = a.configuracion;
      _configEj.text = a.configuracionEjecutiva ?? '';
      _filas.text = '${a.filas}';
      _filasEj.text = '${a.filasEjecutiva}';
      _salidas.addAll(a.filasSalida);
    } else {
      // Valores de ejemplo para ver la vista previa desde el inicio
      _config.text = 'ABC-DEF';
      _filas.text = '20';
    }
    _actualizarVista();
  }

  @override
  void dispose() {
    for (final c in [_modelo, _matricula, _config, _configEj, _filas, _filasEj, _nuevaSalida]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _nFilas => int.tryParse(_filas.text) ?? 0;
  int get _nFilasEj => int.tryParse(_filasEj.text) ?? 0;

  /// Recalcula la vista previa solo si cambió algún dato que la afecta.
  void _actualizarVista() {
    final clave = '${_modelo.text}|${_matricula.text}|${_config.text}|${_configEj.text}|${_filas.text}|${_filasEj.text}|${(_salidas.toList()..sort()).join(',')}';
    if (clave == _claveVista) return;
    _claveVista = clave;
    _preview = construirVistaPrevia(
      modelo: _modelo.text,
      matricula: _matricula.text,
      configuracion: _config.text,
      configuracionEjecutiva: _configEj.text,
      filas: _nFilas,
      filasEjecutiva: _nFilasEj,
      filasSalida: _salidas.toList(),
    );
  }

  void _cambio() => setState(() {
        _errores = {};
        _actualizarVista();
      });

  void _agregarSalida() {
    final n = int.tryParse(_nuevaSalida.text);
    if (n == null || n < 1 || n > _nFilas) {
      mostrarError(context, 'Ingrese una fila entre 1 y ${_nFilas == 0 ? 'el total de filas' : _nFilas}');
      return;
    }
    _nuevaSalida.clear();
    setState(() {
      _salidas.add(n);
      _actualizarVista();
    });
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    if (_preview == null) {
      mostrarError(context, 'La configuración del avión no es válida');
      return;
    }
    final datos = {
      'modelo': _modelo.text.trim(),
      'matricula': _matricula.text.trim().toUpperCase(),
      'configuracion': _config.text.trim().toUpperCase(),
      'configuracion_ejecutiva': _configEj.text.trim().isEmpty ? null : _configEj.text.trim().toUpperCase(),
      'filas': _nFilas,
      'filas_ejecutiva': _nFilasEj,
      'filas_salida': (_salidas.toList()..sort()),
    };
    setState(() => _guardando = true);
    try {
      if (_a == null) {
        await AdminService.crearAvion(datos);
      } else {
        await AdminService.editarAvion(_a!.id, datos);
      }
      if (mounted) {
        mostrarMensaje(context, _a == null ? 'Avión creado' : 'Avión actualizado');
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errores = e.campos);
        mostrarError(context, e);
      }
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _formulario(ThemeData t) {
    final soloDigitos = [FilteringTextInputFormatter.digitsOnly];
    return Form(
      key: _form,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        CampoTexto(
          controller: _modelo,
          etiqueta: 'Modelo (ej. Airbus A320)',
          icono: Icons.airplanemode_active,
          validator: (v) => (v ?? '').trim().length >= 2 ? null : 'Ingrese el modelo',
          errorServidor: _errores['modelo'],
          alCambiar: _cambio,
        ),
        const SizedBox(height: 12),
        CampoTexto(
          controller: _matricula,
          etiqueta: 'Matrícula (HC-XXX)',
          icono: Icons.tag,
          maxLength: 8,
          formatos: [UpperCaseTextFormatter()],
          validator: Validadores.matricula,
          errorServidor: _errores['matricula'],
          alCambiar: _cambio,
        ),
        const SizedBox(height: 12),
        CampoTexto(
          controller: _config,
          etiqueta: 'Configuración económica (ej. ABC-DEF)',
          icono: Icons.view_column_outlined,
          maxLength: 10,
          formatos: [UpperCaseTextFormatter()],
          validator: (v) => Validadores.configuracionAvion(v),
          errorServidor: _errores['configuracion'],
          alCambiar: _cambio,
          ayuda: 'Letras A-K por grupo; el guion es el pasillo',
        ),
        const SizedBox(height: 12),
        CampoTexto(
          controller: _configEj,
          etiqueta: 'Configuración ejecutiva (opcional, ej. AC-DF)',
          icono: Icons.workspace_premium_outlined,
          maxLength: 10,
          formatos: [UpperCaseTextFormatter()],
          validator: (v) => Validadores.configuracionAvion(v, opcional: true),
          errorServidor: _errores['configuracion_ejecutiva'],
          alCambiar: _cambio,
        ),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: CampoTexto(
              controller: _filas,
              etiqueta: 'Filas (5-60)',
              icono: Icons.table_rows_outlined,
              teclado: TextInputType.number,
              maxLength: 2,
              formatos: soloDigitos,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n != null && n >= 5 && n <= 60 ? null : 'Entre 5 y 60';
              },
              errorServidor: _errores['filas'],
              alCambiar: _cambio,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CampoTexto(
              controller: _filasEj,
              etiqueta: 'Filas ejecutivas',
              icono: Icons.workspace_premium,
              teclado: TextInputType.number,
              maxLength: 2,
              formatos: soloDigitos,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n != null && n >= 0 && n < _nFilas ? null : 'Menor que el total de filas';
              },
              errorServidor: _errores['filas_ejecutiva'],
              alCambiar: _cambio,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Text('Filas de salida de emergencia', style: t.textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final f in (_salidas.toList()..sort()))
            InputChip(
              label: Text('Fila $f'),
              avatar: Icon(Icons.exit_to_app, size: 16, color: Colors.red.shade700),
              onDeleted: () => setState(() {
                _salidas.remove(f);
                _actualizarVista();
              }),
            ),
          if (_salidas.isEmpty) Text('Ninguna', style: t.textTheme.bodySmall),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          SizedBox(
            width: 140,
            child: TextField(
              controller: _nuevaSalida,
              keyboardType: TextInputType.number,
              inputFormatters: soloDigitos,
              maxLength: 2,
              onSubmitted: (_) => _agregarSalida(),
              decoration: const InputDecoration(labelText: 'Número de fila', counterText: '', isDense: true),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.tonalIcon(onPressed: _agregarSalida, icon: const Icon(Icons.add), label: const Text('Agregar')),
        ]),
        if (_a != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('La estructura (configuración, filas y salidas) solo se puede cambiar si el avión aún no tiene vuelos.', style: t.textTheme.bodySmall),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: _guardando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
          label: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_a == null ? 'Crear avión' : 'Guardar cambios')),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _vistaPrevia(ThemeData t) {
    final p = _preview;
    return Column(children: [
      Container(
        width: double.infinity,
        color: t.colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Icon(Icons.visibility_outlined),
          const SizedBox(width: 8),
          const Text('Vista previa'),
          const Spacer(),
          if (p != null)
            Chip(
              avatar: const Icon(Icons.event_seat, size: 16),
              label: Text('Capacidad total: ${p.resumen.total} asientos'),
              visualDensity: VisualDensity.compact,
            ),
        ]),
      ),
      Expanded(
        child: p == null
            ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Complete una configuración válida para ver el avión.\nEj.: ABC-DEF, 20 filas.', textAlign: TextAlign.center)))
            : MapaAvion(mapa: p, soloLectura: true, mostrarEncabezado: false),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ancha = MediaQuery.sizeOf(context).width > 950;
    return Scaffold(
      appBar: AppBar(title: Text(_a == null ? 'Nuevo avión' : 'Editar ${_a!.matricula}')),
      body: ancha
          ? Row(children: [
              SizedBox(width: 440, child: _formulario(t)),
              const VerticalDivider(width: 1),
              Expanded(child: _vistaPrevia(t)),
            ])
          : DefaultTabController(
              length: 2,
              child: Column(children: [
                const TabBar(tabs: [Tab(text: 'Datos'), Tab(text: 'Vista previa')]),
                Expanded(child: TabBarView(children: [_formulario(t), _vistaPrevia(t)])),
              ]),
            ),
    );
  }
}
