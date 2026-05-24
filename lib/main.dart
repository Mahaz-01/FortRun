import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env_config.dart';
import 'utils/theme.dart';
import 'services/auth_service.dart';
import 'services/location_service.dart';
import 'services/database_service.dart';
import 'services/game_engine.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_shell.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar overlay
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: FortRunTheme.cardDark,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await dotenv.load(fileName: 'env');

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
        home: const _AppEntry(),
      ),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _splashDone = false;
  bool _onboardingDone = false;
  bool _checkedOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('onboarding_done') ?? false;
    if (mounted) setState(() { _onboardingDone = done; _checkedOnboarding = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return SplashScreen(onDone: () {
        if (mounted) setState(() => _splashDone = true);
      });
    }

    if (_checkedOnboarding && !_onboardingDone) {
      return OnboardingScreen(
        onDone: () {
          if (mounted) setState(() => _onboardingDone = true);
        },
      );
    }

    final auth = context.watch<AuthService>();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      child: auth.isLoggedIn
          ? const HomeShell(key: ValueKey('home'))
          : const LoginScreen(key: ValueKey('login')),
    );
  }
}
