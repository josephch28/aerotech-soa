import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/admin/admin_home.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/registro_screen.dart';
import 'screens/cliente/cliente_home.dart';
import 'services/api_client.dart';
import 'services/usuario_service.dart';
import 'sesion.dart';
import 'widgets/cargando.dart';
import 'widgets/error_reintentar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await Sesion.instancia.cargar();
  runApp(const AeroTechApp());
}

class AeroTechApp extends StatelessWidget {
  const AeroTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AeroTech',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/registro': (_) => const RegistroScreen(),
        '/cliente': (_) => const ClienteHome(),
        '/admin': (_) => const AdminHome(),
      },
      // Aviso global cuando el servidor tarda en responder (p. ej. Render despertando).
      builder: (context, child) => Stack(children: [
        child ?? const SizedBox.shrink(),
        ValueListenableBuilder<bool>(
          valueListenable: ApiClient.conexionLenta,
          builder: (_, lento, _) => lento
              ? Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: Colors.orange.shade800,
                    child: const SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(children: [
                          SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text('Conectando con el servidor (puede tardar hasta 1 min)…',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

/// Decide la ruta inicial: sin token → Login; con token guardado se valida con GET /api/usuarios/perfil
/// y se enruta según el rol que devuelve el servidor.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    // Se decide después del primer frame: navegar durante initState provoca errores del Navigator.
    WidgetsBinding.instance.addPostFrameCallback((_) => _decidir());
  }

  Future<void> _decidir() async {
    if (!mounted) return;
    setState(() => _error = null);
    if (!Sesion.instancia.activa) return _ir('/login');
    try {
      await UsuarioService.perfil();
      _ir(Sesion.instancia.rutaInicio);
    } catch (e) {
      // Un 401 ya cerró la sesión y navegó a Login; otros errores permiten reintentar.
      if (mounted && Sesion.instancia.activa) setState(() => _error = e);
    }
  }

  void _ir(String ruta) {
    if (mounted) Navigator.of(context).pushReplacementNamed(ruta);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _error == null
          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.flight_takeoff, size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              const Text('AeroTech', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              const Cargando(),
            ])
          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              ErrorReintentar(error: _error!, alReintentar: _decidir),
              TextButton(
                onPressed: () async {
                  await Sesion.instancia.cerrar();
                  _ir('/login');
                },
                child: const Text('Cerrar sesión'),
              ),
            ]),
    );
  }
}
