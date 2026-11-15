import 'package:flutter/material.dart';

import 'buscar_vuelos_screen.dart';
import 'mis_reservas_screen.dart';
import 'perfil_screen.dart';

/// Pantalla principal del cliente: pestañas Vuelos / Mis reservas / Perfil
/// (NavigationRail si el ancho supera 800 px, NavigationBar si no).
class ClienteHome extends StatefulWidget {
  /// Pestaña activa; otras pantallas pueden cambiarla (por ejemplo "Ir a mis reservas").
  static final ValueNotifier<int> pestana = ValueNotifier(0);

  static void irAReservas() {
    pestana.value = 1;
    MisReservasScreen.recargar.value++;
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

  @override
  void initState() {
    super.initState();
    ClienteHome.pestana.value = 0;
  }

  void _cambiar(int i) {
    if (i == 1) MisReservasScreen.recargar.value++;
    ClienteHome.pestana.value = i;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ClienteHome.pestana,
      builder: (context, i, _) {
        final ancho = MediaQuery.sizeOf(context).width;
        final cuerpo = IndexedStack(index: i, children: const [BuscarVuelosScreen(), MisReservasScreen(), PerfilScreen()]);
        return Scaffold(
          appBar: AppBar(
            title: Row(children: [
              const Icon(Icons.flight_takeoff),
              const SizedBox(width: 8),
              Text(_destinos[i].$3),
            ]),
          ),
          body: ancho > 800
              ? Row(children: [
                  NavigationRail(
                    selectedIndex: i,
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
                  selectedIndex: i,
                  onDestinationSelected: _cambiar,
                  destinations: [for (final d in _destinos) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3)],
                ),
        );
      },
    );
  }
}
