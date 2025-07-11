import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _all = [], _shown = [];
  String _query = '';
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('encryptionHistory') ?? [];
    _all = raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList().reversed.toList();
    _filter();
  }

  void _filter() {
    final d = _date != null ? DateFormat('yyyy-MM-dd').format(_date!) : null;
    setState(() {
      _shown = _all.where((e) {
        final name = e['name']?.toString().toLowerCase() ?? '';
        final t = e['timestamp'] ?? '';
        return name.contains(_query.toLowerCase()) &&
            (d == null || DateFormat('yyyy-MM-dd').format(DateTime.parse(t)) == d);
      }).toList();
    });
  }

  Future<void> _remove(int i) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('encryptionHistory') ?? [];
    final idx = _all.indexOf(_shown[i]);
    data.removeAt(data.length - 1 - idx);
    await prefs.setStringList('encryptionHistory', data);
    _load();
  }

  Future<void> _clearAll() async {
    if (await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Clear All?"),
        content: const Text("Delete all history records?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Clear All")),
        ],
      ),
    ) ==
        true) {
      await (await SharedPreferences.getInstance()).remove('encryptionHistory');
      _load();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _date = picked;
      _filter();
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Copied to clipboard"), duration: Duration(seconds: 2)));
  }

  Widget _row(IconData icon, String label, String value, {VoidCallback? onLong}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: GestureDetector(
        onLongPress: onLong,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                  children: [
                    TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: value),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Encryption History"),
        actions: _all.isNotEmpty ? [IconButton(icon: const Icon(Icons.delete_forever), onPressed: _clearAll)] : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              TextField(
                decoration: const InputDecoration(
                    labelText: "Search", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                onChanged: (v) {
                  _query = v;
                  _filter();
                },
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_date == null ? "Filter by Date" : DateFormat('yyyy-MM-dd').format(_date!)),
                  ),
                ),
                if (_date != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _date = null;
                      _filter();
                    },
                  )
              ])
            ]),
          ),
          const Divider(),
          Expanded(
            child: _shown.isEmpty
                ? const Center(child: Text("No records found.", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              itemCount: _shown.length,
              itemBuilder: (_, i) {
                final h = _shown[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _row(Icons.image, "Name", h['name']),
                        _row(Icons.lock, "Hash", "${h['hashedPassword'].substring(0, 20)}...",
                            onLong: () => _copy(h['hashedPassword'])),
                        _row(Icons.folder, "Folder",
                            h['path']?.replaceAll(RegExp(r'/[^/]+$'), '') ?? ''),
                        _row(Icons.access_time, "Time", h['timestamp']),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _remove(i),
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text("Remove", style: TextStyle(color: Colors.red)),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
