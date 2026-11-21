import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../sesion.dart';
import 'dashboard_screen.dart';
import 'flota_screen.dart';
import 'reservas_admin_screen.dart';
import 'usuarios_admin_screen.dart';
import 'vuelos_admin_screen.dart';

/// Panel del administrador: NavigationRail en pantallas anchas, Drawer en las angostas.
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  static const _secciones = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    (Icons.flight_outlined, Icons.flight, 'Vuelos'),
    (Icons.airplanemode_active_outlined, Icons.airplanemode_active, 'Flota'),
    (Icons.confirmation_number_outlined, Icons.confirmation_number, 'Reservas'),
    (Icons.people_outline, Icons.people, 'Usuarios'),
  ];

  int _i = 0;
  final List<Widget?> _paginas = List.filled(5, null); // se crean al visitarlas y conservan su estado

  Widget _pagina(int i) => _paginas[i] ??= switch (i) {
        0 => const DashboardScreen(),
        1 => const VuelosAdminScreen(),
        2 => const FlotaScreen(),
        3 => const ReservasAdminScreen(),
        _ => const UsuariosAdminScreen(),
      };

  Future<void> _salir() async {
    await AuthService.logout();
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/inicio', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final ancha = MediaQuery.sizeOf(context).width > 800;
    final u = Sesion.instancia.usuario;
    final cuerpo = IndexedStack(index: _i, children: [for (var k = 0; k < _secciones.length; k++) k == _i || _paginas[k] != null ? _pagina(k) : const SizedBox.shrink()]);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Text(_secciones[_i].$3),
          const SizedBox(width: 12),
          Chip(
            label: const Text('ADMIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
            backgroundColor: Colors.red.shade700,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            side: BorderSide.none,
          ),
        ]),
        actions: [
          if (ancha && u != null) Padding(padding: const EdgeInsets.only(right: 8), child: Center(child: Text(u.nombreCompleto))),
          IconButton(tooltip: 'Cerrar sesión', icon: const Icon(Icons.logout), onPressed: _salir),
        ],
      ),
      drawer: ancha
          ? null
          : Drawer(
              child: SafeArea(
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings, size: 36),
                    title: Text(u?.nombreCompleto ?? 'Administrador'),
                    subtitle: Text(u?.correo ?? ''),
                  ),
                  const Divider(),
                  for (var k = 0; k < _secciones.length; k++)
                    ListTile(
                      leading: Icon(_i == k ? _secciones[k].$2 : _secciones[k].$1),
                      title: Text(_secciones[k].$3),
                      selected: _i == k,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _i = k);
                      },
                    ),
                  const Spacer(),
                  const Divider(),
                  ListTile(leading: const Icon(Icons.logout), title: const Text('Cerrar sesión'), onTap: _salir),
                ]),
              ),
            ),
      body: ancha
          ? Row(children: [
              NavigationRail(
                selectedIndex: _i,
                onDestinationSelected: (k) => setState(() => _i = k),
                labelType: NavigationRailLabelType.all,
                destinations: [for (final s in _secciones) NavigationRailDestination(icon: Icon(s.$1), selectedIcon: Icon(s.$2), label: Text(s.$3))],
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: IconButton(tooltip: 'Cerrar sesión', icon: const Icon(Icons.logout), onPressed: _salir),
                    ),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: cuerpo),
            ])
          : cuerpo,
    );
  }
}
