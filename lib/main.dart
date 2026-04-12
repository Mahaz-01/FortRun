import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env_config.dart';
import 'utils/theme.dart';
import 'services/auth_service.dart';
import 'services/location_service.dart';
import 'services/database_service.dart';
import 'services/game_engine.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_shell.dart';

/// ============================================================
/// FortRun — main.dart
/// Territory-based running app for Islamabad, Pakistan.
///
/// Initialization order:
///   1. Load .env (API keys, Supabase credentials)
///   2. Initialize Supabase client
///   3. Launch app with Provider tree
/// ============================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load environment variables from env asset
  await dotenv.load(fileName: 'env');

  // 2. Initialize Supabase
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );

  runApp(const FortRunApp());
}

class FortRunApp extends StatelessWidget {
  const FortRunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
        Provider(create: (_) => DatabaseService()),
        Provider(create: (_) => GameEngine()),
      ],
      child: MaterialApp(
        title: 'FortRun',
        debugShowCheckedModeBanner: false,
        theme: FortRunTheme.darkTheme,
        home: const AuthGate(),
      ),
    );
  }
}

/// Auth gate: if logged in → HomeShell, else → LoginScreen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    if (authService.isLoggedIn) {
      return const HomeShell();
    }
    return const LoginScreen();
  }
}
