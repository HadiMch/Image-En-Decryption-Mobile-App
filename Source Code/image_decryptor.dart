import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:shared_preferences/shared_preferences.dart';

class ImageDecryptor {
  static const _header = "SC01";
  static const _saltLen = 16, _ivLen = 12, _iterations = 100000, _keyLen = 32;

  static Future<File?> decryptAndReturnImage(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool('isBlocked') ?? false) {
      _showSnack(context, "❌ Access blocked due to multiple failed attempts.");
      return null;
    }

    final result = await FilePicker.platform.pickFiles(dialogTitle: "Pick Encrypted Image");
    final path = result?.files.single.path;
    if (path == null) return null;

    final file = File(path);
    final bytes = await file.readAsBytes();
    if (utf8.decode(bytes.sublist(0, 4)) != _header) {
      _showSnack(context, "❌ Not a valid encrypted file.");
      return null;
    }

    final salt = bytes.sublist(4, 4 + _saltLen);
    final iv = bytes.sublist(4 + _saltLen, 4 + _saltLen + _ivLen);
    final encrypted = bytes.sublist(4 + _saltLen + _ivLen);

    final password = await _promptPassword(context);
    if (password == null) return null;

    _showLoadingDialog(context);

    try {
      final decrypted = await compute(_decryptInIsolate, {
        'password': password,
        'salt': base64.encode(salt),
        'iv': base64.encode(iv),
        'data': base64.encode(encrypted),
      });

      await prefs.setInt('failedAttempts', 0);

      final output = File("${(await getTemporaryDirectory()).path}/decrypted.png");
      await output.writeAsBytes(decrypted);

      Navigator.of(context).pop();
      _showSnack(context, "✅ Decryption successful!");
      return output;
    } catch (_) {
      Navigator.of(context).pop();

      final attempts = (prefs.getInt('failedAttempts') ?? 0) + 1;
      await prefs.setInt('failedAttempts', attempts);
      if (attempts >= 3) await prefs.setBool('isBlocked', true);

      _showSnack(context, "❌ Incorrect password. Attempt $attempts of 3.");
      return null;
    }
  }

  static Future<String?> _promptPassword(BuildContext context) async {
    final passCtrl = TextEditingController(), confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Enter Decryption Password"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password"),
                validator: (val) => (val == null || val.isEmpty) ? "Enter password" : null,
              ),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Confirm Password"),
                validator: (val) =>
                val != passCtrl.text ? "Passwords do not match" : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, passCtrl.text.trim());
              }
            },
            child: const Text("Decrypt"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  static Future<Uint8List> _decryptInIsolate(Map<String, dynamic> args) async {
    final password = args['password'] as String;
    final salt = base64.decode(args['salt']);
    final iv = base64.decode(args['iv']);
    final encryptedData = base64.decode(args['data']);

    final derivator = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64))
      ..init(pc.Pbkdf2Parameters(Uint8List.fromList(salt), _iterations, _keyLen));

    final key = derivator.process(Uint8List.fromList(utf8.encode(password)));

    final encrypter = encrypt.Encrypter(
      encrypt.AES(encrypt.Key(key), mode: encrypt.AESMode.gcm),
    );

    return Uint8List.fromList(encrypter.decryptBytes(
      encrypt.Encrypted(encryptedData),
      iv: encrypt.IV(iv),
    ));
  }

  static void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Decrypting image..."),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}