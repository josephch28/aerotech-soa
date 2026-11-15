import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/aeropuerto.dart';
import '../../models/avion.dart';
import '../../models/vuelo.dart';
import '../../services/admin_service.dart';
import '../../services/api_client.dart';
import '../../services/vuelo_service.dart';
import '../../utils/formatos.dart';
import '../../utils/ui.dart';
import '../../utils/validadores.dart';
import '../../widgets/campo_texto.dart';
import '../../widgets/cargando.dart';
import '../../widgets/error_reintentar.dart';

/// Crear o editar un vuelo (si se pasa [vuelo] es edición).
class VueloFormScreen extends StatefulWidget {
  final Vuelo? vuelo;
  const VueloFormScreen({super.key, this.vuelo});

  @override
  State<VueloFormScreen> createState() => _VueloFormScreenState();
}

class _VueloFormScreenState extends State<VueloFormScreen> {
  final _form = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  final _precio = TextEditingController();
  final _precioEj = TextEditingController();

  List<Avion> _aviones = [];
  List<Aeropuerto> _aeropuertos = [];
  Avion? _avion;
  Aeropuerto? _origen, _destino;
  DateTime? _fecha;
  TimeOfDay? _salida, _llegada;
  bool _avionBloqueado = false; // en edición, el avión no se puede cambiar si el vuelo tiene reservas
  Map<String, String> _errores = {};

  bool _cargando = true;
  bool _guardando = false;
  Object? _errorCarga;

  Vuelo? get _v => widget.vuelo;
  bool get _edicion => _v != null;
  bool get _sinEjecutiva => (_avion?.filasEjecutiva ?? 0) == 0 && _avion != null;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _codigo.dispose();
    _precio.dispose();
    _precioEj.dispose();
    super.dispose();
  }

  TimeOfDay _hora(String s) {
    final p = s.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final todos = await AdminService.aviones();
      _aeropuertos = await VueloService.aeropuertos();
      final v = _v;
      // En edición se mantiene el avión actual aunque estuviera inactivo
      _aviones = todos.where((a) => a.activo || (v != null && a.matricula == v.matricula)).toList();
      if (v != null) {
        _codigo.text = v.codigoVuelo;
        _avion = _aviones.where((a) => a.matricula == v.matricula).firstOrNull;
        _origen = _aeropuertos.where((a) => a.codigo == v.origen).firstOrNull;
        _destino = _aeropuertos.where((a) => a.codigo == v.destino).firstOrNull;
        _fecha = v.fechaDia;
        _salida = _hora(v.horaSalida);
        _llegada = _hora(v.horaLlegada);
        _precio.text = v.precio.toStringAsFixed(2);
        _precioEj.text = v.precioEjecutiva.toStringAsFixed(2);
        final reservas = await AdminService.reservas(vueloId: v.id);
        _avionBloqueado = reservas.isNotEmpty;
      }
    } catch (e) {
      _errorCarga = e;
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  int? get _duracion {
    if (_salida == null || _llegada == null) return null;
    return (_llegada!.hour * 60 + _llegada!.minute) - (_salida!.hour * 60 + _salida!.minute);
  }

  String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context,
      locale: const Locale('es'),
      initialDate: _fecha != null && !_fecha!.isBefore(DateTime(hoy.year, hoy.month, hoy.day)) ? _fecha! : hoy,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: DateTime(hoy.year + 3),
    );
    if (f != null) setState(() => _fecha = f);
  }

  Future<void> _elegirHora(bool salida) async {
    final h = await showTimePicker(
      context: context,
      initialTime: (salida ? _salida : _llegada) ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (h != null) setState(() => salida ? _salida = h : _llegada = h);
  }

  String? _validarAdicional() {
    if (_avion == null) return 'Seleccione un avión';
    if (_origen == null || _destino == null) return 'Seleccione origen y destino';
    if (_origen == _destino) return 'El origen y el destino deben ser distintos';
    if (_fecha == null) return 'Seleccione la fecha';
    if (_salida == null || _llegada == null) return 'Seleccione las horas de salida y llegada';
    final d = _duracion!;
    if (d <= 0) return 'La hora de llegada debe ser posterior a la salida';
    if (d > 300) return 'La duración del vuelo no puede superar 5 horas';
    final cambiaHorario = !_edicion || _fecha != _v!.fechaDia || _hhmm(_salida!) != _v!.horaSalida;
    if (cambiaHorario) {
      final salida = DateTime(_fecha!.year, _fecha!.month, _fecha!.day, _salida!.hour, _salida!.minute);
      final ahora = DateTime.now();
      if (_fecha!.isBefore(DateTime(ahora.year, ahora.month, ahora.day))) return 'La fecha no puede ser pasada';
      if (salida.isBefore(ahora.add(const Duration(hours: 2))) && _fecha!.year == ahora.year && _fecha!.month == ahora.month && _fecha!.day == ahora.day) {
        return 'Si el vuelo es hoy, debe salir al menos 2 horas después de la hora actual';
      }
    }
    return null;
  }

  Future<void> _guardar() async {
    setState(() => _errores = {});
    if (!_form.currentState!.validate()) return;
    final problema = _validarAdicional();
    if (problema != null) {
      mostrarError(context, problema);
      return;
    }
    final precio = double.parse(_precio.text.replaceAll(',', '.'));
    final precioEj = _sinEjecutiva ? precio : double.parse(_precioEj.text.replaceAll(',', '.'));
    final datos = {
      'codigo_vuelo': _codigo.text.trim().toUpperCase(),
      'avion_id': _avion!.id,
      'origen': _origen!.codigo,
      'destino': _destino!.codigo,
      'fecha': Formatos.iso(_fecha!),
      'hora_salida': _hhmm(_salida!),
      'hora_llegada': _hhmm(_llegada!),
      'precio': precio,
      'precio_ejecutiva': precioEj,
    };
    setState(() => _guardando = true);
    try {
      if (_edicion) {
        await AdminService.editarVuelo(_v!.id, datos);
        if (mounted) mostrarMensaje(context, 'Vuelo actualizado');
      } else {
        final n = await AdminService.crearVuelo(datos);
        if (mounted) mostrarMensaje(context, 'Vuelo creado con $n asientos');
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      // 409 (solapamiento, código duplicado) y otros: SnackBar; 400: además marca los campos
      if (mounted) {
        setState(() => _errores = e.campos);
        mostrarError(context, e.campos.isEmpty ? e : '${e.mensaje}: ${e.campos.values.join(' · ')}');
      }
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _selectorHora(String etiqueta, TimeOfDay? valor, bool salida) => Expanded(
        child: OutlinedButton.icon(
          onPressed: () => _elegirHora(salida),
          icon: const Icon(Icons.schedule),
          label: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(valor == null ? etiqueta : '$etiqueta ${_hhmm(valor)}')),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_edicion ? 'Editar vuelo ${_v!.codigoVuelo}' : 'Nuevo vuelo')),
      body: _errorCarga != null
          ? ErrorReintentar(error: _errorCarga!, alReintentar: _cargarDatos)
          : _cargando
              ? const Cargando()
              : Form(
                  key: _form,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: ListView(padding: const EdgeInsets.all(16), children: [
                        CampoTexto(
                          controller: _codigo,
                          etiqueta: 'Código de vuelo (AT123)',
                          icono: Icons.confirmation_number_outlined,
                          maxLength: 6,
                          formatos: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')), UpperCaseTextFormatter()],
                          validator: Validadores.codigoVuelo,
                          errorServidor: _errores['codigo_vuelo'],
                          alCambiar: () => setState(() => _errores.remove('codigo_vuelo')),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<Avion>(
                          initialValue: _avion,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Avión',
                            prefixIcon: const Icon(Icons.airplanemode_active),
                            helperText: _avionBloqueado ? 'No se puede cambiar el avión: el vuelo ya tiene reservas' : null,
                          ),
                          items: [for (final a in _aviones) DropdownMenuItem(value: a, child: Text('${a.modelo} · ${a.matricula} · ${a.capacidad} asientos${a.activo ? '' : ' (inactivo)'}', overflow: TextOverflow.ellipsis))],
                          onChanged: _avionBloqueado ? null : (a) => setState(() => _avion = a),
                          validator: (a) => a == null ? 'Seleccione un avión' : null,
                        ),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: DropdownButtonFormField<Aeropuerto>(
                              initialValue: _origen,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Origen', prefixIcon: Icon(Icons.flight_takeoff)),
                              items: [for (final a in _aeropuertos) DropdownMenuItem(value: a, child: Text('${a.ciudad} (${a.codigo})', overflow: TextOverflow.ellipsis))],
                              onChanged: (a) => setState(() => _origen = a),
                              validator: (a) => a == null ? 'Obligatorio' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<Aeropuerto>(
                              initialValue: _destino,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Destino', prefixIcon: Icon(Icons.flight_land)),
                              items: [for (final a in _aeropuertos) DropdownMenuItem(value: a, child: Text('${a.ciudad} (${a.codigo})', overflow: TextOverflow.ellipsis))],
                              onChanged: (a) => setState(() => _destino = a),
                              validator: (a) => a == null ? 'Obligatorio' : (a == _origen ? 'Debe ser distinto del origen' : null),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _elegirFecha,
                          icon: const Icon(Icons.calendar_month),
                          label: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(_fecha == null ? 'Fecha del vuelo' : 'Fecha: ${Formatos.fecha(_fecha!)}')),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [_selectorHora('Salida', _salida, true), const SizedBox(width: 12), _selectorHora('Llegada', _llegada, false)]),
                        if (_duracion != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _duracion! <= 0 ? 'La llegada debe ser posterior a la salida' : 'Duración: ${Formatos.duracion(_duracion!)}${_duracion! > 300 ? ' (máximo 5 h)' : ''}',
                              style: t.textTheme.bodyMedium?.copyWith(color: _duracion! <= 0 || _duracion! > 300 ? Colors.red.shade700 : t.colorScheme.primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                        const SizedBox(height: 14),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: CampoTexto(
                              controller: _precio,
                              etiqueta: 'Precio económica (\$)',
                              icono: Icons.attach_money,
                              teclado: const TextInputType.numberWithOptions(decimal: true),
                              validator: Validadores.precio,
                              errorServidor: _errores['precio'],
                              alCambiar: () => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CampoTexto(
                              controller: _sinEjecutiva ? (TextEditingController(text: _precio.text)) : _precioEj,
                              etiqueta: 'Precio ejecutiva (\$)',
                              icono: Icons.workspace_premium,
                              soloLectura: _sinEjecutiva,
                              ayuda: _sinEjecutiva ? 'El avión no tiene clase ejecutiva' : null,
                              teclado: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) {
                                if (_sinEjecutiva) return null;
                                final base = Validadores.precio(v);
                                if (base != null) return base;
                                final p = double.tryParse(_precio.text.replaceAll(',', '.'));
                                final e = double.parse(v!.replaceAll(',', '.'));
                                return p != null && e < p ? 'Debe ser mayor o igual al precio económico' : null;
                              },
                              errorServidor: _errores['precio_ejecutiva'],
                            ),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _guardando ? null : _guardar,
                          icon: _guardando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                          label: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_edicion ? 'Guardar cambios' : 'Crear vuelo')),
                        ),
                        const SizedBox(height: 24),
                      ]),
                    ),
                  ),
                ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue nuevo) =>
      nuevo.copyWith(text: nuevo.text.toUpperCase());
}
