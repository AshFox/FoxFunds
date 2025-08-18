import 'package:flutter/material.dart';
import 'package:foxfunds/themes/app_theme.dart';
import 'package:foxfunds/services/auto_pay_service.dart';
import 'package:foxfunds/services/settings_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_US');
  
  // Initialize services
  await AutoPayService.instance.initialize();
  await SettingsService.instance.initialize();
  await NotificationService.instance.initialize();
  
  runApp(Phoenix(child: const MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Set up theme change callback
    SettingsService.instance.setThemeChangeCallback(() {
      setState(() {
        // Rebuild the app when theme changes
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = SettingsService.instance.isDarkMode;
    return MaterialApp(
      title: 'FoxF',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const HomeScreen(),
    );
  }
}
