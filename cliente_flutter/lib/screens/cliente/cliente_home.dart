import 'package:flutter/material.dart';

import 'buscar_vuelos_screen.dart';
import 'mis_reservas_screen.dart';
import 'perfil_screen.dart';

/// «Mi cuenta» del cliente: pestañas Vuelos / Mis reservas / Perfil
/// (NavigationRail si el ancho supera 800 px, NavigationBar si no).
class ClienteHome extends StatefulWidget {
  static int _pestanaInicial = 0;

  /// Abre «Mi cuenta» en la pestaña indicada (0 Vuelos, 1 Mis reservas, 2 Perfil).
  static void abrir(BuildContext context, {int pestana = 0}) {
    _pestanaInicial = pestana;
    Navigator.of(context).pushNamed('/cliente');
  }

  /// Igual que [abrir] pero descarta la pila de pantallas (por ejemplo al terminar una reserva).
  static void abrirLimpiando(BuildContext context, {int pestana = 0}) {
    _pestanaInicial = pestana;
    Navigator.of(context).pushNamedAndRemoveUntil('/cliente', (_) => false);
  }

  const ClienteHome({super.key});

  @override
  State<ClienteHome> createState() => _ClienteHomeState();
}

class _ClienteHomeState extends State<ClienteHome> {
  static const _destinos = [
    (Icons.flight_outlined, Icons.flight, 'Vuelos'),
    (Icons.confirmation_number_outlined, Icons.confirmation_number, 'Mis reservas'),
    (Icons.person_outline, Icons.person, 'Perfil'),
  ];

  late int _i;

  @override
  void initState() {
    super.initState();
    _i = ClienteHome._pestanaInicial;
    ClienteHome._pestanaInicial = 0;
  }

  void _cambiar(int i) {
    if (i == 1) MisReservasScreen.recargar.value++;
    setState(() => _i = i);
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final cuerpo = IndexedStack(index: _i, children: const [BuscarVuelosScreen(), MisReservasScreen(), PerfilScreen()]);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Ir al inicio',
          icon: const Icon(Icons.home_outlined),
          onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/inicio', (_) => false),
        ),
        title: Row(children: [
          const Icon(Icons.flight_takeoff),
          const SizedBox(width: 8),
          Text(_destinos[_i].$3),
        ]),
      ),
      body: ancho > 800
          ? Row(children: [
              NavigationRail(
                selectedIndex: _i,
                onDestinationSelected: _cambiar,
                labelType: NavigationRailLabelType.all,
                destinations: [for (final d in _destinos) NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3))],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: cuerpo),
            ])
          : cuerpo,
      bottomNavigationBar: ancho > 800
          ? null
          : NavigationBar(
              selectedIndex: _i,
              onDestinationSelected: _cambiar,
              destinations: [for (final d in _destinos) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3)],
            ),
    );
  }
}
