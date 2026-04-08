import 'package:app1/screens/LoginPage.dart';
import 'package:app1/screens/home_screen.dart';
import 'package:app1/screens/Register.dart';
import 'package:app1/screens/forgot_password.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/home_providers.dart';
import 'theme/app_theme.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/local_cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive (offline storage)
  await Hive.initFlutter();

  // Initialize your cache service (open boxes, etc.)
  await LocalCacheService.init();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartStudy',

      // Themes
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,

      // Initial Route
      initialRoute: '/splash',

      //  Routes
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const MainScreen(),
        '/home': (context) => const HomeScreen(),
        '/register': (context) => const SignUpScreen(),
        '/forgot': (context) => const ForgotPasswordPage(),
      },
    );
  }
}
