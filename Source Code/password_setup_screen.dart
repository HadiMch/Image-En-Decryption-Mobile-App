import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'lock_screen.dart';

class PasswordSetupScreen extends StatefulWidget {
  final VoidCallback? onSetupComplete;
  const PasswordSetupScreen({super.key, this.onSetupComplete});

  @override
  State<PasswordSetupScreen> createState() => _PasswordSetupScreenState();
}

class _PasswordSetupScreenState extends State<PasswordSetupScreen> {
  final _storage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isSaving = false, _bioEnabled = false, _passSet = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final pass = await _storage.read(key: 'appPassword');
    setState(() async {
      _passSet = pass != null;
      _bioEnabled = (await _storage.read(key: 'biometricEnabled')) == 'true';
    });
  }

  String _hash(String text) => sha256.convert(utf8.encode(text)).toString();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passSet && !(await _verifyIdentity())) {
      _msg('Verification failed. Password not changed.');
      return;
    }

    setState(() => _isSaving = true);

    await _storage.write(key: 'appPassword', value: _hash(_passCtrl.text));
    await _storage.write(key: 'biometricEnabled', value: _bioEnabled.toString());
    _gotoLock();
  }

  Future<bool> _verifyIdentity() async {
    if (_bioEnabled) {
      if (await _auth.authenticate(localizedReason: 'Verify biometric to change password', options: const AuthenticationOptions(biometricOnly: true))) return true;
    }
    return await _verifyDialog();
  }

  void _gotoLock() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LockScreen(onUnlocked: widget.onSetupComplete ?? () {})),
    );
  }

  Future<void> _setupBiometric() async {
    if (!(await _auth.canCheckBiometrics) || (await _auth.getAvailableBiometrics()).isEmpty) return _msg('Biometric not available.');

    if (!(await _auth.authenticate(localizedReason: 'Enable biometric authentication', options: const AuthenticationOptions(biometricOnly: true))) ||
        !(await _auth.authenticate(localizedReason: 'Confirm biometric', options: const AuthenticationOptions(biometricOnly: true)))) {
      return _msg('Biometric confirmation failed.');
    }

    await _storage.write(key: 'biometricEnabled', value: 'true');
    setState(() => _bioEnabled = true);
    if (!_passSet) _gotoLock();
  }

  Future<void> _reset() async {
    if (!_passSet) return _clearData('Authentication reset.');
    if (!(await _verifyIdentity())) return _msg('Reset cancelled.');
    await _clearData('Authentication reset.');
  }

  Future<void> _clearData(String message) async {
    await _storage.deleteAll();
    setState(() {
      _bioEnabled = false;
      _passSet = false;
      _passCtrl.clear();
      _confirmCtrl.clear();
    });
    _msg(message);
  }

  Future<bool> _verifyDialog() async {
    final ctrl = TextEditingController();
    return (await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Verify Password'),
        content: TextField(controller: ctrl, obscureText: true, decoration: const InputDecoration(labelText: 'Enter current password')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final stored = await _storage.read(key: 'appPassword');
              Navigator.pop(context, _hash(ctrl.text) == stored);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    )) ?? false;
  }

  void _msg(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Widget _field(String label, TextEditingController ctrl, {bool isConfirm = false}) {
    return TextFormField(
      controller: ctrl,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (val) => !isConfirm ? (val != null && val.length >= 4 ? null : 'Min 4 characters') : (val == _passCtrl.text ? null : 'Passwords don’t match'),
    );
  }

  @override
  Widget build(BuildContext context) {
    const baseColor = Color(0xFF1C1C2D);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: baseColor,
        centerTitle: true,
        title: null,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: _gotoLock),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 24),
              _field('New Password', _passCtrl),
              const SizedBox(height: 16),
              _field('Confirm Password', _confirmCtrl, isConfirm: true),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Password'),
                onPressed: _isSaving ? null : _save,
                style: _buttonStyle(baseColor),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(_bioEnabled ? Icons.refresh : Icons.fingerprint),
                label: Text(_bioEnabled ? 'Reset Authentication' : 'Set Biometric Authentication'),
                onPressed: _bioEnabled ? _reset : _setupBiometric,
                style: _buttonStyle(_bioEnabled ? Colors.red[700]! : Colors.green[700]!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle _buttonStyle(Color bg) => ElevatedButton.styleFrom(
    backgroundColor: bg,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}
