import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _usedNamesKey = 'used_names';
const String _usedPasswordsKey = 'used_passwords';

class PasswordInputPage extends StatefulWidget {
  const PasswordInputPage({super.key});

  @override
  State<PasswordInputPage> createState() => _PasswordInputPageState();
}

class _PasswordInputPageState extends State<PasswordInputPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscure = true;
  List<String> _usedNames = [];
  List<String> _usedPasswords = [];
  double _passwordStrength = 0;

  @override
  void initState() {
    super.initState();
    _loadUsedData();
    _passwordController.addListener(_updatePasswordStrength);
  }

  Future<void> _loadUsedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _usedNames = prefs.getStringList(_usedNamesKey) ?? [];
      _usedPasswords = prefs.getStringList(_usedPasswordsKey) ?? [];
    });
  }

  Future<void> _saveUsedData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_usedNamesKey, _usedNames);
    await prefs.setStringList(_usedPasswordsKey, _usedPasswords);
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _usedNames.add(_nameController.text.trim());
      _usedPasswords.add(_passwordController.text.trim());
      _saveUsedData();
      Navigator.pop(context, {
        "name": _nameController.text.trim(),
        "password": _passwordController.text.trim(),
      });
    }
  }

  void _updatePasswordStrength() {
    final password = _passwordController.text;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasNumber = RegExp(r'\d').hasMatch(password);
    final hasSpecialChar = RegExp(r'[!@#\$&*~_\-]').hasMatch(password);

    setState(() {
      _passwordStrength = (password.length >= 6 ? 0.25 : 0) +
          (hasUpper ? 0.25 : 0) +
          (hasNumber ? 0.25 : 0) +
          (hasSpecialChar ? 0.25 : 0);
    });
  }

  bool get _canSubmit {
    return _nameController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmController.text == _passwordController.text &&
        _passwordStrength >= 0.75 &&
        !_usedNames.contains(_nameController.text.trim()) &&
        !_usedPasswords.contains(_passwordController.text.trim());
  }

  Color _getStrengthColor(double strength) {
    if (strength <= 0.25) return Colors.red;
    if (strength <= 0.5) return Colors.orange;
    if (strength <= 0.75) return Colors.lightGreen;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text("Encrypt Image")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: [
              Icon(Icons.lock, size: 90, color: isDark ? Colors.blue[200] : Colors.blue),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Image Name",
                  hintText: "Enter a name for your image",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.label_important),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Please enter a valid name";
                  if (_usedNames.contains(val.trim())) return "This image name is already used";
                  return null;
                },
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: "Password",
                  hintText: "Min 6 chars, 1 capital, 1 number, 1 special (@, -, etc)",
                  prefixIcon: const Icon(Icons.vpn_key),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return "Please enter a password";
                  if (val.length < 6) return "Password must be at least 6 characters long";
                  if (!RegExp(r'[A-Z]').hasMatch(val)) return "Must contain at least one uppercase letter";
                  if (!RegExp(r'\d').hasMatch(val)) return "Must contain at least one number";
                  if (!RegExp(r'[!@#\$&*~_\-]').hasMatch(val)) return "Must contain at least one special character";
                  if (_usedPasswords.contains(val.trim())) return "This password is already used";
                  return null;
                },
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _passwordStrength,
                color: _getStrengthColor(_passwordStrength),
                backgroundColor: Colors.grey.shade300,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "Strength: ${_passwordStrength <= 0.25 ? 'Weak' : _passwordStrength <= 0.5 ? 'Fair' : _passwordStrength <= 0.75 ? 'Good' : 'Strong'}",
                    style: TextStyle(color: _getStrengthColor(_passwordStrength)),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: "Confirm Password",
                  prefixIcon: const Icon(Icons.check_circle),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val != _passwordController.text) return "Passwords do not match";
                  return null;
                },
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Checkbox(
                    value: !_obscure,
                    onChanged: (val) => setState(() => _obscure = !(val ?? false)),
                  ),
                  const Text("Show password"),
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.lock),
                  label: const Text("Encrypt"),
                  onPressed: _canSubmit ? _submit : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
