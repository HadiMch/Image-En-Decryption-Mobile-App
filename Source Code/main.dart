import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'lock_screen.dart';
import 'password_setup_screen.dart';
import 'my_home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isUnlocked = false;

  void _showHomeScreen() {
    setState(() => _isUnlocked = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Stega Cryption',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: _isUnlocked
          ? MyHomePage(
        title: 'Stega_Cryption',
      )
          : LockScreen(onUnlocked: _showHomeScreen),
    );
  }
}
