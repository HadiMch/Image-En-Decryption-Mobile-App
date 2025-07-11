import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'password_setup_screen.dart';
import 'my_home_page.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _storage = const FlutterSecureStorage();
  final _passwordCtrl = TextEditingController();
  final _auth = LocalAuthentication();

  String? _savedHashedPassword;
  bool _isLoading = true, _canUseBiometrics = false, _isLockedOut = false;
  int _failedAttempts = 0, _lockoutTime = 0;
  bool _selfDestructWarned = false;

  @override
  void initState() {
    super.initState();
    _loadAndCheck();
  }

  Future<void> _loadAndCheck() async {
    final storedPassword = await _storage.read(key: 'appPassword');
    final isAvailable = await _isBiometricAvailable();
    final failedAttempts = await _storage.read(key: 'failedAttempts') ?? '0';

    setState(() {
      _failedAttempts = int.parse(failedAttempts);
      _savedHashedPassword = storedPassword;
      _canUseBiometrics = isAvailable;
      _isLoading = false;
    });

    final lockoutTime = await _storage.read(key: 'lockoutTime');
    if (lockoutTime != null && int.parse(lockoutTime) > 0) {
      _lockoutTime = int.parse(lockoutTime);
      _isLockedOut = true;
      _startLockoutTimer();
    }
  }

  Future<bool> _isBiometricAvailable() async {
    try {
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isLockedOut) return;

    final didAuth = await _auth.authenticate(
      localizedReason: 'Scan your fingerprint to unlock',
      options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
    );

    didAuth ? _navigateToHome() : _showMessage('❌ Biometric authentication failed');
  }

  String _hashPassword(String input) => sha256.convert(utf8.encode(input)).toString();

  void _checkPassword() async {
    if (_isLockedOut) return;

    if (_hashPassword(_passwordCtrl.text.trim()) == _savedHashedPassword) {
      _resetFailedAttempts();
      _navigateToHome();
    } else {
      _failedAttempts++;
      await _storage.write(key: 'failedAttempts', value: _failedAttempts.toString());
      _failedAttempts >= 3 ? _startLockout() : _showMessage('❌ Incorrect password');
    }
  }

  Future<void> _startLockout() async {
    final lockoutDuration = _failedAttempts == 3 ? 1 : (_failedAttempts == 6 ? 5 : 0);
    if (lockoutDuration > 0) {
      _lockoutTime = lockoutDuration * 60;
      _isLockedOut = true;
      await _storage.write(key: 'lockoutTime', value: _lockoutTime.toString());
      _showMessage('❌ Too many failed attempts. Locking out for $_lockoutTime seconds.');
      setState(() {});
      _startLockoutTimer();
    }
  }

  void _startLockoutTimer() async {
    while (_lockoutTime > 0) {
      await Future.delayed(Duration(seconds: 1));
      setState(() => _lockoutTime--);
    }
    if (_lockoutTime == 0) {
      _isLockedOut = false;
      await _storage.write(key: 'lockoutTime', value: '0');
      _showMessage('You can try again now.');
    }
  }

  void _resetFailedAttempts() async {
    _failedAttempts = 0;
    await _storage.write(key: 'failedAttempts', value: '0');
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MyHomePage(title: 'Secure Your Memories'),
      ),
    );
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _selfDestruct() async {
    await _storage.deleteAll();
    _showMessage('App self-destructed. All data has been erased.');
    exit(0);  // Close the app
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF3B82F6);
    const grey = Color(0xFF334155);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFE3E8F0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE3E8F0), Color(0xFFD2D8E0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 60),
              child: Column(
                children: [
                  const Icon(Icons.security, size: 72, color: blue),
                  const SizedBox(height: 12),
                  Text(
                    _savedHashedPassword == null ? 'Create Password to Start' : 'Enter Password to Login',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: grey),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))],
                    ),
                    child: Column(
                      children: [
                        if (_savedHashedPassword == null) _buildCreatePasswordButton(),
                        ..._savedHashedPassword != null ? _buildPasswordForm(blue) : [],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatePasswordButton() => ElevatedButton.icon(
    icon: const Icon(Icons.lock),
    label: const Text('Create Password'),
    onPressed: () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PasswordSetupScreen(onSetupComplete: widget.onUnlocked),
        ),
      );
    },
    style: _elevatedButtonStyle(),
  );

  List<Widget> _buildPasswordForm(Color blue) => [
    TextField(
      controller: _passwordCtrl,
      obscureText: true,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _checkPassword(),
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.blueGrey),
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    ),
    const SizedBox(height: 20),
    ElevatedButton.icon(
      onPressed: _isLockedOut ? null : _checkPassword,
      icon: const Icon(Icons.lock_open),
      label: const Text('Unlock'),
      style: _elevatedButtonStyle(),
    ),
    const SizedBox(height: 12),
    if (_canUseBiometrics && !_isLockedOut)
      OutlinedButton.icon(
        onPressed: _authenticateWithBiometrics,
        icon: const Icon(Icons.fingerprint),
        label: const Text('Use Fingerprint'),
        style: OutlinedButton.styleFrom(
          foregroundColor: blue,
          side: BorderSide(color: blue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size.fromHeight(50),
        ),
      ),
    const SizedBox(height: 16),
    if (_isLockedOut)
      Column(
        children: [
          Text(
            'try again after: $_lockoutTime sec',
            style: const TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (_failedAttempts >= 9 && !_selfDestructWarned)
            GestureDetector(
              onTap: () async {
                _selfDestructWarned = true;
                await _selfDestruct();
              },
              child: Text(
                'WARNING: One more wrong attempt will destroy all your data!',
                style: TextStyle(fontSize: 21, color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    TextButton(
      onPressed: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PasswordSetupScreen()),
        );
      },
      child: Text(
        'Forgot or Change Password',
        style: TextStyle(color: blue, fontWeight: FontWeight.w600),
      ),
    ),
  ];

  ButtonStyle _elevatedButtonStyle() => ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF3B82F6),
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}
