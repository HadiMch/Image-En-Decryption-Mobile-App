import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'image_encryptor.dart';
import 'password_input_page.dart';

class ImageController {
  static final ImagePicker _picker = ImagePicker();

  static Future<File?> pickFromGallery() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    return picked != null ? File(picked.path) : null;
  }

  static Future<File?> captureFromCamera() async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    return picked != null ? File(picked.path) : null;
  }

  static Future<void> encryptAndSave(BuildContext context, File? imageFile) async {
    if (imageFile == null) return;

    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (context) => const PasswordInputPage()),
    );

    if (result == null || result['name']?.trim().isEmpty != false || result['password']?.trim().isEmpty != false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Name or password not provided. Cancelled.")),
      );
      return;
    }

    final imageName = result['name']!.trim();
    final password = result['password']!.trim();

    // Get folder path using FilePicker
    final folderPath = await FilePicker.platform.getDirectoryPath();
    if (folderPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ No folder selected. Cancelled.")),
      );
      return;
    }

    // Sanitize folder path
    String sanitizedFolderPath = folderPath.endsWith('/')
        ? folderPath.substring(0, folderPath.length - 1)
        : folderPath;
    sanitizedFolderPath = sanitizedFolderPath.replaceAll(
      RegExp(r'/Encrypted Images/Encrypted Images'),
      '/Encrypted Images',
    );

    final directory = Directory(sanitizedFolderPath);
    if (!await directory.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Selected folder does not exist.")),
      );
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ValueNotifier<double> progress = ValueNotifier(0.0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (_, value, __) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Encrypting image..."),
              const SizedBox(height: 20),
              LinearProgressIndicator(value: value),
            ],
          ),
        ),
      ),
    );

    try {
      final encryptor = ImageEncryptor();
      final imageFileName = "$imageName.enc";
      final fullOutputPath = '$sanitizedFolderPath/$imageFileName';

      final savedPath = await encryptor.encryptImage(
        imageFile,
        outputPath: fullOutputPath,
        password: password,
        onProgress: (val) => progress.value = val,
      );

      navigator.pop();

      if (savedPath != null) {
        // ✅ Store history
        final hashedPassword = sha256.convert(utf8.encode(password)).toString();
        final prefs = await SharedPreferences.getInstance();
        final history = prefs.getStringList('encryptionHistory') ?? [];

        final newEntry = jsonEncode({
          'name': imageName,
          'hashedPassword': hashedPassword,
          'timestamp': DateTime.now().toIso8601String(),
          'path': savedPath,
        });

        history.add(newEntry);
        await prefs.setStringList('encryptionHistory', history);

        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text("✅ Encrypted & saved to: $savedPath")),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text("❌ Failed to save encrypted image.")),
        );
      }
    } catch (e) {
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    }
  }
}
