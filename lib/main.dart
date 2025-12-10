import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'theme/app_theme.dart';
import 'screens/login.dart';
import 'screens/dashboard.dart';
import 'screens/nfc_reader.dart';
import 'screens/manual_ticket.dart';
import 'screens/sync_center.dart';
import 'screens/reports.dart';
import 'screens/settings.dart';
import 'screens/registered_cards.dart';

void main() {
  // Initialize database factory for web/desktop platforms
  if (kIsWeb) {
    // Initialize for web using IndexedDB
    databaseFactory = databaseFactoryFfiWeb;
  } else {
    // Initialize for desktop (Windows, Linux, macOS)
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  runApp(
    const ProviderScope(
      child: CityGoApp(),
    ),
  );
}

class CityGoApp extends StatelessWidget {
  const CityGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CityGo Supervisor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/sync': (context) => const SyncCenterScreen(),
        '/reports': (context) => const ReportsScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/registered-cards': (context) => const RegisteredCardsScreen(),
      },
     
      onGenerateRoute: (settings) {
        if (settings.name == '/nfc-reader') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => NFCReaderScreen(
              busId: args['busId'] as String,
              isTapIn: args['isTapIn'] as bool,
            ),
          );
        } else if (settings.name == '/manual-ticket') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => ManualTicketScreen(
              busId: args['busId'] as String,
            ),
          );
        }
        return null;
      },
    );
  }
}
