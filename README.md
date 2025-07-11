# 🔐 PixelLock – Image Encryption & Decryption App

**PixelLock** is a highly secure, cross-platform mobile application built with **Flutter**, designed for advanced image encryption and decryption. The app combines modern cryptographic standards with strong access controls to ensure user privacy and data confidentiality.

PixelLock employs **AES-based encryption** with **auto-generated secure keys**, combined with **user-defined passwords** for multi-factor protection. Encrypted files are stored securely using **flutter_secure_storage** and **platform-level encryption APIs**, while sensitive credentials never leave the device. It also supports **optional biometric authentication** (fingerprint/face unlock) for seamless, secure access. The application architecture adheres to **best practices in secure coding**, data isolation, and encrypted storage—making it suitable for both personal and sensitive use cases.

---


## 📱 Features

- 🔒 Encrypt images with a user-defined password
- 🔓 Decrypt and view previously encrypted images
- 🧠 Local password management with secure storage
- 🧾 History of encrypted/decrypted files
- 🧩 Modular encryption and decryption engine
- 🔐 Optional biometric unlock (if supported)
- 📁 Save and manage encrypted files securely


---

## 🚀 Tech Stack

- **Flutter** – Cross-platform development
- **Dart** – Core application logic
- **flutter_secure_storage** – Secure data storage
- **image_picker** – Select images from gallery or camera
- **path_provider** – File system access
- **shared_preferences** – Lightweight user config storage
- **local_auth** – Biometric authentication (optional)
- **Custom encryption logic** – in `image_encryptor.dart` / `image_decryptor.dart`

---


## 📁 Key Project Structure

lib/
├── main.dart # App entry point
├── my_home_page.dart # Main UI screen
├── lock_screen.dart # App locking mechanism
├── image_encryptor.dart # Image encryption logic
├── image_decryptor.dart # Image decryption logic
├── password_input_page.dart # Password entry screen
├── password_setup_screen.dart # Setup password screen
├── image_controller.dart # Image state controller
├── history_page.dart # View encryption/decryption history

Other folders:
- `android/`, `ios/`, `linux/`, `web/`, `windows/` – Platform-specific files
- `pubspec.yaml` – App dependencies
- `assets/`, `native_assets/` – Static files and external packages

---


## 🛠️ Getting Started


### Prerequisites
- Flutter SDK installed
- Android Studio or VS Code
- Emulator/device for testing


### Run the App
```bash
flutter pub get
flutter run
📄 Report & Presentation
📘 Full project report: Hadi Mcheimech-42130168- CSCI490-REPORT.docx


🖥️ Project presentation: Pixel-Lock- Presentation.pptx


📄 License
This project is licensed as proprietary.
All rights reserved. You may not use, copy, modify, or distribute any part of this code without express permission from the author.


👨‍💻 Author
Hadi Mcheimech
Developed as part of the CSCI490 Graduation Project – 2025
---
