import 'package:flutter/material.dart';
import 'package:foxfunds/themes/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_US');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoxF',
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
