import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/pasajero.dart';
import '../../sesion.dart';
import '../../utils/formatos.dart';
import '../../utils/ui.dart';
import '../../utils/validadores.dart';
import '../../widgets/campo_texto.dart';
import 'resumen_reserva_screen.dart';
import 'reserva_flujo.dart';

class _FormPasajero {
  final String asiento;
  final nombres = TextEditingController();
  final apellidos = TextEditingController();
  final numero = TextEditingController();
  final fecha = TextEditingController();
  String tipo = 'cedula';
  DateTime? nacimiento;
  bool soyYo = false;

  _FormPasajero(this.asiento);

  void dispose() {
    nombres.dispose();
    apellidos.dispose();
    numero.dispose();
    fecha.dispose();
  }
}

class DatosPasajerosScreen extends StatefulWidget {
  final ReservaFlujo flujo;
  const DatosPasajerosScreen({super.key, required this.flujo});

  @override
  State<DatosPasajerosScreen> createState() => _DatosPasajerosScreenState();
}

class _DatosPasajerosScreenState extends State<DatosPasajerosScreen> {
  final _form = GlobalKey<FormState>();
  final _forms = <_FormPasajero>[];
  final _telefono = TextEditingController();
  final _correo = TextEditingController();

  ReservaFlujo get f => widget.flujo;

  @override
  void initState() {
    super.initState();
    final asientos = f.ordenados;
    // Datos de pasajeros que perdieron su asiento (edición): se reutilizan en los asientos nuevos
    final huerfanos = f.datos.entries.where((e) => !asientos.contains(e.key)).map((e) => e.value).toList();
    for (final a in asientos) {
      final fp = _FormPasajero(a);
      var p = f.datos[a];
      if (p == null && huerfanos.isNotEmpty) p = huerfanos.removeAt(0);
      if (p != null) {
        fp.nombres.text = p.nombres;
        fp.apellidos.text = p.apellidos;
        fp.numero.text = p.numeroDocumento;
        fp.tipo = p.tipoDocumento.isEmpty ? 'cedula' : p.tipoDocumento;
        fp.nacimiento = DateTime.tryParse(p.fechaNacimiento);
        if (fp.nacimiento != null) fp.fecha.text = Formatos.fecha(fp.nacimiento!);
      }
      _forms.add(fp);
    }
    _telefono.text = f.telefono;
    _correo.text = f.correo;
  }

  @override
  void dispose() {
    for (final fp in _forms) {
      fp.dispose();
    }
    _telefono.dispose();
    _correo.dispose();
    super.dispose();
  }

  void _soyYo(_FormPasajero fp, bool v) {
    final u = Sesion.instancia.usuario;
    setState(() {
      fp.soyYo = v;
      if (v && u != null) {
        fp.nombres.text = u.nombre;
        fp.apellidos.text = u.apellido;
        fp.tipo = 'cedula';
        fp.numero.text = u.cedula;
      }
    });
  }

  Future<void> _fechaNacimiento(_FormPasajero fp) async {
    final ref = f.vuelo.fechaDia;
    final d = await showDatePicker(
      context: context,
      locale: const Locale('es'),
      initialDate: fp.nacimiento ?? DateTime(ref.year - 30, 1, 1),
      firstDate: DateTime(ref.year - 111),
      lastDate: DateTime.now(),
      helpText: 'Fecha de nacimiento',
    );
    if (d != null) {
      setState(() {
        fp.nacimiento = d;
        fp.fecha.text = Formatos.fecha(d);
      });
    }
  }

  void _continuar() {
    if (!_form.currentState!.validate()) {
      mostrarMensaje(context, 'Revise los datos marcados en rojo');
      return;
    }
    final docs = <String>{};
    for (final fp in _forms) {
      final d = fp.numero.text.trim().toUpperCase();
      if (!docs.add(d)) {
        mostrarError(context, 'El documento $d está repetido en la reserva');
        return;
      }
    }
    final adultos = _forms.where((fp) => Validadores.edadA(fp.nacimiento!, f.vuelo.fechaDia) >= 18).length;
    if (adultos == 0) {
      mostrarError(context, 'Debe viajar al menos un adulto');
      return;
    }
    for (final fp in _forms) {
      f.datos[fp.asiento] = Pasajero(
        asiento: fp.asiento,
        nombres: Validadores.limpiar(fp.nombres.text),
        apellidos: Validadores.limpiar(fp.apellidos.text),
        tipoDocumento: fp.tipo,
        numeroDocumento: fp.tipo == 'pasaporte' ? fp.numero.text.trim().toUpperCase() : fp.numero.text.trim(),
        fechaNacimiento: Formatos.iso(fp.nacimiento!),
      );
    }
    // Descarta datos de asientos que ya no están en la selección
    f.datos.removeWhere((k, _) => !f.seleccion.contains(k));
    f.telefono = _telefono.text.trim();
    f.correo = _correo.text.trim().toLowerCase();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResumenReservaScreen(flujo: f)));
  }

  Widget _tarjeta(int i, _FormPasajero fp) {
    final a = f.asiento(fp.asiento);
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: true,
        maintainState: true,
        leading: CircleAvatar(child: Text(fp.asiento, style: const TextStyle(fontSize: 12))),
        title: Text('Pasajero ${i + 1} · Asiento ${fp.asiento}'),
        subtitle: Text('${Formatos.clase(a?.clase ?? '')}${a?.salidaEmergencia == true ? ' · Salida de emergencia' : ''} · ${Formatos.moneda(f.precioDe(fp.asiento))}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          if (i == 0)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: fp.soyYo,
              onChanged: (v) => _soyYo(fp, v ?? false),
              title: const Text('Soy yo quien viaja'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          CampoTexto(controller: fp.nombres, etiqueta: 'Nombres', icono: Icons.person_outline, validator: Validadores.nombre),
          const SizedBox(height: 12),
          CampoTexto(controller: fp.apellidos, etiqueta: 'Apellidos', icono: Icons.person_outline, validator: Validadores.nombre),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'cedula', label: Text('Cédula'), icon: Icon(Icons.badge_outlined)),
              ButtonSegment(value: 'pasaporte', label: Text('Pasaporte'), icon: Icon(Icons.travel_explore)),
            ],
            selected: {fp.tipo},
            onSelectionChanged: (s) => setState(() => fp.tipo = s.first),
          ),
          const SizedBox(height: 12),
          CampoTexto(
            key: ValueKey('doc-${fp.asiento}-${fp.tipo}'),
            controller: fp.numero,
            etiqueta: fp.tipo == 'cedula' ? 'Número de cédula' : 'Número de pasaporte',
            icono: Icons.numbers,
            teclado: fp.tipo == 'cedula' ? TextInputType.number : TextInputType.text,
            maxLength: fp.tipo == 'cedula' ? 10 : 15,
            formatos: fp.tipo == 'cedula' ? [FilteringTextInputFormatter.digitsOnly] : null,
            validator: (v) => Validadores.documento(fp.tipo, v),
          ),
          const SizedBox(height: 12),
          CampoTexto(
            controller: fp.fecha,
            etiqueta: 'Fecha de nacimiento',
            icono: Icons.cake_outlined,
            soloLectura: true,
            alTocar: () => _fechaNacimiento(fp),
            validator: (_) => Validadores.fechaNacimiento(fp.nacimiento, f.vuelo.fechaDia, salidaEmergencia: a?.salidaEmergencia ?? false),
            ayuda: 'La edad se calcula a la fecha del vuelo (${Formatos.fecha(f.vuelo.fecha)})',
          ),
          if (fp.nacimiento != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Edad en el vuelo: ${Validadores.edadA(fp.nacimiento!, f.vuelo.fechaDia)} años', style: t.textTheme.bodySmall),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(f.edicion ? 'Pasajeros (edición)' : 'Datos de los pasajeros')),
      body: Form(
        key: _form,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              for (var i = 0; i < _forms.length; i++) _tarjeta(i, _forms[i]),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Contacto', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    CampoTexto(
                      controller: _telefono,
                      etiqueta: 'Teléfono de contacto (09XXXXXXXX)',
                      icono: Icons.phone_outlined,
                      teclado: TextInputType.phone,
                      maxLength: 10,
                      formatos: [FilteringTextInputFormatter.digitsOnly],
                      validator: Validadores.telefono,
                    ),
                    const SizedBox(height: 12),
                    CampoTexto(controller: _correo, etiqueta: 'Correo de contacto', icono: Icons.email_outlined, teclado: TextInputType.emailAddress, validator: Validadores.correo),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _continuar,
                icon: const Icon(Icons.arrow_forward),
                label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Continuar al resumen')),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ),
    );
  }
}
