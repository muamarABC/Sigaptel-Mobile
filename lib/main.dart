import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
import 'providers/api_starlink_provider.dart';
import 'providers/api_vsat_provider.dart';
import 'providers/vsat_pending_provider.dart';
import 'screens/starlink_page.dart';
import 'screens/vsat_page.dart';

void main() {
  runApp(const SigaptelApp());
}

class SigaptelApp extends StatelessWidget {
  const SigaptelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SurveyProvider()),
        ChangeNotifierProvider(create: (_) => ApiSurveyProvider()),
        ChangeNotifierProvider(create: (_) => ApiStarlinkProvider()),
        ChangeNotifierProvider(create: (_) => ApiVsatProvider()),
        ChangeNotifierProvider(create: (_) => VsatPendingProvider()),
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
        home: const _AuthGate(),
        routes: {
          LoginPage.routeName: (_) => const LoginPage(),
          MenuPage.routeName: (_) => const MenuPage(),
          ProfilePage.routeName: (_) => const ProfilePage(),
          SurveyPage.routeName: (_) => const SurveyPage(),
          DataPage.routeName: (_) => const DataPage(),
          MapPage.routeName: (_) => const MapPage(),
          SurveyDetailPage.routeName: (_) => const SurveyDetailPage(),
          SpeedtestSettingsPage.routeName: (_) => const SpeedtestSettingsPage(),
          StarlinkPage.routeName: (_) => const StarlinkPage(),
          VsatPage.routeName: (_) => const VsatPage(),
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

