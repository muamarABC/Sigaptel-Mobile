import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'screens/login_page.dart';
import 'screens/menu_page.dart';
import 'screens/profile_page.dart';
import 'screens/survey_page.dart';
import 'screens/data_page.dart';
import 'screens/map_page.dart';
import 'screens/survey_detail_page.dart';
import 'screens/speedtest_settings_page.dart';
import 'providers/auth_provider.dart';
import 'providers/survey_provider.dart';
import 'providers/api_survey_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SigaptelApp(configError: AppConfig.validationError));
}

class SigaptelApp extends StatelessWidget {
  final String? configError;

  const SigaptelApp({super.key, this.configError});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SurveyProvider()),
        ChangeNotifierProvider(create: (_) => ApiSurveyProvider()),
      ],
      child: MaterialApp(
        title: 'SIGAPTEL',
        theme: ThemeData.light().copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
          inputDecorationTheme: const InputDecorationTheme(
            labelStyle: TextStyle(color: Colors.black87),
            hintStyle: TextStyle(color: Colors.black54),
          ),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: Colors.blueAccent,
            selectionColor: Colors.blueAccent,
            selectionHandleColor: Colors.blueAccent,
          ),
        ),
        home: configError == null
          ? const _AuthGate()
          : _ConfigErrorPage(message: configError!),
        routes: {
          LoginPage.routeName: (_) => const LoginPage(),
          MenuPage.routeName: (_) => const MenuPage(),
          ProfilePage.routeName: (_) => const ProfilePage(),
          SurveyPage.routeName: (_) => const SurveyPage(),
          DataPage.routeName: (_) => const DataPage(),
          MapPage.routeName: (_) => const MapPage(),
          SurveyDetailPage.routeName: (_) => const SurveyDetailPage(),
          SpeedtestSettingsPage.routeName: (_) => const SpeedtestSettingsPage(),
        },
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isRestoring) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (auth.isLoggedIn) {
          return const MenuPage();
        }

        return const LoginPage();
      },
    );
  }
}

class _ConfigErrorPage extends StatelessWidget {
  final String message;

  const _ConfigErrorPage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'Aplikasi Belum Dikonfigurasi',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Minta kode akses dan endpoint API dari pemilik proyek.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

