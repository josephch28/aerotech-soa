import 'package:flutter/material.dart';

import '../screens/cliente/cliente_home.dart';
import '../services/auth_service.dart';
import '../sesion.dart';

const Color azulMarca = Color(0xFF0B1F5C);
const Color coral = Color(0xFFE5174B);

/// Barra superior de las páginas públicas (como la de LATAM o Avianca): logo, enlaces y acceso a la cuenta.
/// "Iniciar sesión" es opcional: se puede buscar y elegir asientos sin cuenta.
class BarraSuperior extends StatelessWidget {
  final VoidCallback? alOfertas;
  final VoidCallback? alDestinos;

  const BarraSuperior({super.key, this.alOfertas, this.alDestinos});

  static void irAInicio(BuildContext context) =>
      Navigator.of(context).pushNamedAndRemoveUntil('/inicio', (_) => false);

  Future<void> _salir(BuildContext context) async {
    await AuthService.logout();
    if (context.mounted) irAInicio(context);
  }

  void _misViajes(BuildContext context) {
    if (Sesion.instancia.activa && !Sesion.instancia.esAdmin) {
      ClienteHome.abrir(context, pestana: 1);
    } else {
      Navigator.of(context).pushNamed('/login');
    }
  }

  void _enlace(BuildContext context, VoidCallback? local) {
    if (local != null) {
      local();
    } else {
      irAInicio(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: azulMarca,
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Sesion.instancia,
          builder: (context, _) {
            final ancho = MediaQuery.sizeOf(context).width;
            final ancha = ancho >= 920;
            final s = Sesion.instancia;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: SizedBox(
                  height: 64,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      InkWell(
                        onTap: () => irAInicio(context),
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.flight_takeoff, color: Colors.white, size: 26),
                            SizedBox(width: 8),
                            Text('AeroTech', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                          ]),
                        ),
                      ),
                      const Spacer(),
                      if (ancha) ...[
                        _link('Ofertas', () => _enlace(context, alOfertas)),
                        _link('Destinos', () => _enlace(context, alDestinos)),
                        _link('Mis viajes', () => _misViajes(context)),
                        const SizedBox(width: 12),
                        if (!s.activa) ...[
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: Colors.white),
                            onPressed: () => Navigator.of(context).pushNamed('/registro'),
                            child: const Text('Crear cuenta'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
                            onPressed: () => Navigator.of(context).pushNamed('/login'),
                            child: const Text('Iniciar sesión'),
                          ),
                        ] else
                          _menuUsuario(context, s),
                      ] else
                        _menuCompacto(context, s),
                    ]),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _link(String texto, VoidCallback alTocar) => TextButton(
        style: TextButton.styleFrom(foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        onPressed: alTocar,
        child: Text(texto),
      );

  List<PopupMenuEntry<String>> _itemsCuenta(Sesion s) => [
        if (s.esAdmin)
          const PopupMenuItem(value: 'panel', child: ListTile(leading: Icon(Icons.admin_panel_settings), title: Text('Panel de administración'), dense: true))
        else ...const [
          PopupMenuItem(value: 'cuenta', child: ListTile(leading: Icon(Icons.person_outline), title: Text('Mi cuenta'), dense: true)),
          PopupMenuItem(value: 'reservas', child: ListTile(leading: Icon(Icons.confirmation_number_outlined), title: Text('Mis reservas'), dense: true)),
        ],
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'salir', child: ListTile(leading: Icon(Icons.logout), title: Text('Cerrar sesión'), dense: true)),
      ];

  void _accionCuenta(BuildContext context, String a) {
    switch (a) {
      case 'panel':
        Navigator.of(context).pushNamedAndRemoveUntil('/admin', (_) => false);
      case 'cuenta':
        ClienteHome.abrir(context, pestana: 2);
      case 'reservas':
        ClienteHome.abrir(context, pestana: 1);
      case 'salir':
        _salir(context);
    }
  }

  Widget _menuUsuario(BuildContext context, Sesion s) {
    final nombre = s.usuario?.nombre ?? 'Mi cuenta';
    return PopupMenuButton<String>(
      tooltip: 'Mi cuenta',
      onSelected: (a) => _accionCuenta(context, a),
      itemBuilder: (_) => _itemsCuenta(s),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 16, backgroundColor: Colors.white24, child: Text(nombre.isEmpty ? '?' : nombre[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
          const SizedBox(width: 8),
          Text('Hola, $nombre', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const Icon(Icons.arrow_drop_down, color: Colors.white),
        ]),
      ),
    );
  }

  Widget _menuCompacto(BuildContext context, Sesion s) {
    return PopupMenuButton<String>(
      tooltip: 'Menú',
      icon: const Icon(Icons.menu, color: Colors.white),
      onSelected: (a) {
        switch (a) {
          case 'ofertas':
            _enlace(context, alOfertas);
          case 'destinos':
            _enlace(context, alDestinos);
          case 'viajes':
            _misViajes(context);
          case 'login':
            Navigator.of(context).pushNamed('/login');
          case 'registro':
            Navigator.of(context).pushNamed('/registro');
          default:
            _accionCuenta(context, a);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'ofertas', child: Text('Ofertas')),
        const PopupMenuItem(value: 'destinos', child: Text('Destinos')),
        const PopupMenuItem(value: 'viajes', child: Text('Mis viajes')),
        const PopupMenuDivider(),
        if (!s.activa) ...const [
          PopupMenuItem(value: 'login', child: Text('Iniciar sesión')),
          PopupMenuItem(value: 'registro', child: Text('Crear cuenta')),
        ] else
          ..._itemsCuenta(s),
      ],
    );
  }
}
