import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pointycastle/export.dart' as pc;

class ImageEncryptor {
  static const _saltLength = 16;
  static const _ivLength = 12;
  static const _iterations = 100000;
  static const _keyLength = 32;
  static const _magicHeader = "SC01";

  Future<String?> encryptImage(
      File imageFile, {
        required String outputPath,
        required String password,
        Function(double)? onProgress,
      }) async {
    try {
      if (!await _hasStoragePermission()) return null;

      final salt = _randomBytes(_saltLength);
      final iv = _randomBytes(_ivLength);
      final imageBytes = await imageFile.readAsBytes();
      final key = await compute(_deriveKeyInIsolate, {'password': password, 'salt': salt});

      onProgress?.call(0.2);

      final encrypted = await compute(_encryptInIsolate, {
        'bytes': imageBytes,
        'key': base64.encode(key),
        'iv': base64.encode(iv),
      });

      onProgress?.call(0.7);

      final output = BytesBuilder()
        ..add(utf8.encode(_magicHeader))
        ..add(salt)
        ..add(iv)
        ..add(encrypted);

      final file = File(outputPath);
      if (!await file.parent.exists()) return null;

      await file.writeAsBytes(output.toBytes());
      onProgress?.call(1.0);
      return outputPath;
    } catch (e, stack) {
      debugPrint("❌ Encryption error: $e\n$stack");
      return null;
    }
  }

  Future<bool> _hasStoragePermission() async {
    if (!Platform.isAndroid) return true;

    final storage = await Permission.storage.request();
    final manage = await Permission.manageExternalStorage.request();
    return storage.isGranted || manage.isGranted;
  }

  Uint8List _randomBytes(int length) {
    final rng = pc.FortunaRandom()
      ..seed(pc.KeyParameter(
        Uint8List.fromList(List.generate(32, (_) => DateTime.now().microsecond % 256)),
      ));
    return rng.nextBytes(length);
  }

  static Future<Uint8List> _deriveKeyInIsolate(Map<String, dynamic> args) async {
    final password = args['password'] as String;
    final salt = args['salt'] as Uint8List;

    final derivator = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64))
      ..init(pc.Pbkdf2Parameters(salt, _iterations, _keyLength));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  static Future<Uint8List> _encryptInIsolate(Map<String, dynamic> args) async {
    final bytes = args['bytes'] as Uint8List;
    final key = encrypt.Key.fromBase64(args['key']);
    final iv = encrypt.IV.fromBase64(args['iv']);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
    return Uint8List.fromList(encrypter.encryptBytes(bytes, iv: iv).bytes);
  }
}