import 'package:app1/screens/LoginPage.dart';
import 'package:app1/screens/home_screen.dart';
import 'package:app1/screens/Register.dart';
import 'package:app1/screens/forgot_password.dart';
import 'package:app1/screens/offline_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'providers/home_providers.dart';
import 'theme/app_theme.dart';
import 'services/local_cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await LocalCacheService.init();
  runApp(const ProviderScope(child: MyApp()));
}

// ─────────────────────────────────────────────────────────────────────────────
// Root App
// ─────────────────────────────────────────────────────────────────────────────

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,

      home: const ConnectivityGate(),
      routes: {
        '/login': (context) => const MainScreen(),
        '/home': (context) => const HomeScreen(),
        '/register': (context) => const SignUpScreen(),
        '/forgot': (context) => const ForgotPasswordPage(),
        '/offline': (context) => const OfflineScreen(),
      },
    );
  }
}

class ConnectivityGate extends StatefulWidget {
  const ConnectivityGate({super.key});

  @override
  State<ConnectivityGate> createState() => _ConnectivityGateState();
}

class _ConnectivityGateState extends State<ConnectivityGate> {
  late final Stream<List<ConnectivityResult>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = Connectivity().onConnectivityChanged;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SplashScreen();

        final isOffline = snapshot.data!.every(
          (r) => r == ConnectivityResult.none,
        );

        if (isOffline) return const OfflineScreen();

        return const SplashScreen();
      },
    );
  }
}
