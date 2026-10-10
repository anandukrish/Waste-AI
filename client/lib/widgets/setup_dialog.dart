import 'package:flutter/material.dart';

import '../services/waste_api.dart';

class SetupDialog extends StatefulWidget {
  const SetupDialog({super.key, required this.host, required this.onSave});

  final String host;
  final Future<void> Function(String host, String token) onSave;

  @override
  State<SetupDialog> createState() => _SetupDialogState();
}

class _SetupDialogState extends State<SetupDialog> {
  late final TextEditingController _host;
  final _token = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _host = TextEditingController(text: widget.host);
  }

  @override
  void dispose() {
    _host.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      WasteApi.validateBaseUrl(_host.text);
      await widget.onSave(_host.text, _token.text);
      if (mounted) Navigator.pop(context, true);
    } on WasteApiException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Row(children: [Icon(Icons.auto_awesome), SizedBox(width: 10), Text('Welcome to WASTE')]),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your notes stay on this device. Chat connects only when you choose a mode and the local companion is available.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 18),
              TextField(controller: _host, decoration: const InputDecoration(labelText: 'Companion origin', hintText: 'http://127.0.0.1:8765')),
              const SizedBox(height: 12),
              TextField(controller: _token, obscureText: true, decoration: const InputDecoration(labelText: 'Pairing token (optional for now)')),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 14),
              Text('Offline mode still uses the companion’s offline provider; it never silently switches to cloud. Non-loopback origins must use HTTPS.', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Explore locally')), FilledButton(onPressed: _save, child: const Text('Save connection'))],
      );
}
