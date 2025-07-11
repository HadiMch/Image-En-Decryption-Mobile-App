import 'dart:io';
import 'package:flutter/material.dart';
import 'image_controller.dart';
import 'image_decryptor.dart';
import 'history_page.dart';
import 'lock_screen.dart';

class MyHomePage extends StatefulWidget {
  final String title;

  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _image;
  bool _loading = false;

  void _setImage(File? image) => setState(() => _image = image);

  Future<void> _handleImage(Future<File?> Function() getImage) async {
    final image = await getImage();
    if (image != null) _setImage(image);
  }

  Future<void> _encryptImage() async {
    if (_image == null) {
      _showSnackBar("⚠️ Please select an image first!");
      return;
    }

    setState(() => _loading = true);
    await ImageController.encryptAndSave(context, _image);
    setState(() {
      _image = null;
      _loading = false;
    });
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _viewFullscreen() {
    if (_image == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(child: InteractiveViewer(child: Image.file(_image!))),
        ),
      ),
    );
  }

  void _showBottomSheet(List<BottomSheetOption> options) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((option) => _styledOption(option)).toList(),
          ),
        );
      },
    );
  }

  Widget _styledOption(BottomSheetOption option) {
    return InkWell(
      onTap: option.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.blueGrey[50],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(option.icon, size: 28, color: Colors.blueGrey[600]),
            const SizedBox(width: 20),
            Expanded(child: Text(option.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.settings, size: 30), tooltip: "Settings", onPressed: _showSettings),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (_image != null)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(_image!, width: double.infinity, height: MediaQuery.of(context).size.height * 0.35, fit: BoxFit.cover),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children: [
                            _miniButton(Icons.zoom_out_map, "View Fullscreen", _viewFullscreen),
                            _miniButton(Icons.clear, "Clear Image", () => _setImage(null)),
                          ],
                        ),
                      ],
                    )
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.image, size: 250, color: Colors.grey),
                        SizedBox(height: 40),
                      ],
                    ),
                  const SizedBox(height: 30),
                  if (_image == null)
                    _mainButton(Icons.image, "Select an Image", _showImageSelectionOptions),
                  _mainButton(Icons.lock, "Encrypt and Save", _encryptImage),
                  _mainButton(Icons.vpn_key, "Choose and Decrypt", () async {
                    final image = await ImageDecryptor.decryptAndReturnImage(context);
                    if (image != null) _setImage(image);
                  }),
                ],
              ),
            ),
            if (_loading) Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  Widget _mainButton(IconData icon, String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            backgroundColor: Colors.blueGrey[700],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.15),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: Colors.white),
              const SizedBox(width: 16),
              Text(label, style: const TextStyle(fontSize: 18, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniButton(IconData icon, String label, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueGrey[600],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
      ),
    );
  }

  void _showSettings() {
    _showBottomSheet([
      BottomSheetOption(
        icon: Icons.history,
        label: "History Page",
        onTap: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage()));
        },
      ),
      BottomSheetOption(
        icon: Icons.logout,
        label: "Logout",
        onTap: () {
          Navigator.pop(context);
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LockScreen(onUnlocked: () {})));
        },
      ),
    ]);
  }

  void _showImageSelectionOptions() {
    _showBottomSheet([
      BottomSheetOption(
        icon: Icons.photo_library,
        label: "Choose from Gallery",
        onTap: () {
          Navigator.pop(context);
          _handleImage(ImageController.pickFromGallery);
        },
      ),
      BottomSheetOption(
        icon: Icons.camera_alt_rounded,
        label: "Take a Photo",
        onTap: () {
          Navigator.pop(context);
          _handleImage(ImageController.captureFromCamera);
        },
      ),
    ]);
  }
}

class BottomSheetOption {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  BottomSheetOption({required this.icon, required this.label, required this.onTap});
}
