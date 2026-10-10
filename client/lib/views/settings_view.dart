import 'dart:io';

import 'package:flutter/material.dart';

import '../services/waste_api.dart';
import '../widgets/mode_badge.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.api,
    required this.host,
    required this.token,
    required this.mode,
    required this.onSaveConnection,
    required this.onModeChanged,
    required this.onClearChats,
    required this.onClearNotes,
    required this.onDisconnect,
    required this.onOpenChat,
  });

  final WasteApi api;
  final String host;
  final String? token;
  final String mode;
  final Future<void> Function(String host, String token) onSaveConnection;
  final Future<void> Function(String mode) onModeChanged;
  final Future<void> Function() onClearChats;
  final Future<void> Function() onClearNotes;
  final Future<void> Function() onDisconnect;
  final VoidCallback onOpenChat;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final TextEditingController _host;
  final _token = TextEditingController();
  String? _connectionError;
  String? _connectionMessage;
  String? _actionError;
  bool _saving = false;

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
    setState(() {
      _saving = true;
      _connectionError = null;
      _connectionMessage = null;
    });
    try {
      WasteApi.validateBaseUrl(_host.text);
      await widget.onSaveConnection(_host.text, _token.text.trim().isEmpty ? (widget.token ?? '') : _token.text.trim());
      _token.clear();
      setState(() => _connectionMessage = 'Connection saved. The token remains in secure storage.');
    } on WasteApiException catch (error) {
      setState(() => _connectionError = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _checkConnection() async {
    setState(() { _connectionError = null; _connectionMessage = null; });
    try {
      final health = await widget.api.health(_host.text);
      setState(() => _connectionMessage = '${health['name'] ?? 'Companion'} is reachable (v${health['version'] ?? '?'})');
    } on WasteApiException catch (error) {
      setState(() => _connectionError = error.message);
    }
  }

  Future<bool> _confirm(String title, String body, String action) async => await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text(title), content: Text(body), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: Text(action))])) ?? false;

  Future<void> _clearChats() async {
    if (await _confirm('Clear chat history?', 'Saved conversations will be removed from this device.', 'Clear chats')) await widget.onClearChats();
  }

  Future<void> _clearNotes() async {
    if (await _confirm('Clear notes?', 'Every saved note will be removed from this device.', 'Clear notes')) await widget.onClearNotes();
  }

  Future<void> _disconnect() async {
    if (await _confirm('Disconnect this client?', 'The pairing token will be deleted from secure storage. Local notes and chats stay on this device.', 'Disconnect')) await widget.onDisconnect();
  }

  Future<void> _prepareAction(String action, String label) async {
    if (!Platform.isWindows) return;
    if (widget.token == null || widget.token!.isEmpty) {
      setState(() => _actionError = 'Pair the Windows client before preparing a companion action.');
      return;
    }
    setState(() => _actionError = null);
    try {
      final result = await widget.api.prepareAction(baseUrl: widget.host, token: widget.token!, action: action);
      final confirmationId = result['confirmation_id'] as String?;
      if (confirmationId == null || confirmationId.isEmpty) throw const WasteApiException('The companion did not provide a confirmation.');
      if (!mounted) return;
      final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text('Confirm $label'), content: Text('${result['description'] ?? label}\n\nThis one-use confirmation expires in ${result['expires_in'] ?? 60} seconds.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm action'))])) ?? false;
      if (!confirmed) return;
      await widget.api.confirmAction(baseUrl: widget.host, token: widget.token!, confirmationId: confirmationId);
      if (mounted) setState(() => _actionError = '$label launched on the Windows companion.');
    } on WasteApiException catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(24, 22, 24, 30), children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Controls are explicit and local-first.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white60)),
        const SizedBox(height: 22),
        _section(context, 'Connection', Icons.link, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: _host, decoration: const InputDecoration(labelText: 'Companion origin', hintText: 'http://127.0.0.1:8765')),
          const SizedBox(height: 12),
          TextField(controller: _token, obscureText: true, decoration: InputDecoration(labelText: widget.token == null ? 'Pairing token' : 'Replace pairing token', helperText: 'Stored in secure storage, never in app preferences.')),
          const SizedBox(height: 12),
          Row(children: [FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')), const SizedBox(width: 10), OutlinedButton(onPressed: _checkConnection, child: const Text('Check health')), const Spacer(), if (widget.token != null) const Icon(Icons.lock_outline, size: 16)]),
          if (_connectionError != null) _message(_connectionError!, true),
          if (_connectionMessage != null) _message(_connectionMessage!, false),
        ])),
        const SizedBox(height: 14),
        _section(context, 'Chat mode', Icons.swap_horiz, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Choose each provider path deliberately. Changing this never sends a request.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)), const SizedBox(height: 14), SegmentedButton<String>(segments: const [ButtonSegment(value: 'offline', label: Text('Offline'), icon: Icon(Icons.lan_outlined)), ButtonSegment(value: 'online', label: Text('Online'), icon: Icon(Icons.cloud_outlined))], selected: {widget.mode}, onSelectionChanged: (value) => widget.onModeChanged(value.first)), const SizedBox(height: 10), ModeBadge(mode: widget.mode)])),
        const SizedBox(height: 14),
        _section(context, 'Computer companion actions', Icons.desktop_windows_outlined, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(Platform.isWindows ? 'These are fixed allowlisted operations. Each request is prepared, shown, and confirmed once.' : 'This client is running on a device. Computer companion actions are available only from the Windows client.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [OutlinedButton.icon(onPressed: Platform.isWindows ? () => _prepareAction('open_calculator', 'Open Calculator') : null, icon: const Icon(Icons.calculate_outlined), label: const Text('Open Calculator')), OutlinedButton.icon(onPressed: Platform.isWindows ? () => _prepareAction('open_notepad', 'Open Notepad') : null, icon: const Icon(Icons.note_alt_outlined), label: const Text('Open Notepad'))]),
          if (_actionError != null) _message(_actionError!, _actionError!.contains('error') || _actionError!.contains('Pair')),
        ])),
        const SizedBox(height: 14),
        _section(context, 'Local data', Icons.storage_outlined, Wrap(spacing: 10, runSpacing: 10, children: [OutlinedButton.icon(onPressed: _clearChats, icon: const Icon(Icons.forum_outlined), label: const Text('Clear chats')), OutlinedButton.icon(onPressed: _clearNotes, icon: const Icon(Icons.sticky_note_2_outlined), label: const Text('Clear notes')), OutlinedButton.icon(onPressed: _disconnect, icon: const Icon(Icons.link_off), label: const Text('Disconnect'))])),
        const SizedBox(height: 18),
        Text('Speech controls are planned. WASTE does not show a microphone or text-to-speech control until bounded platform permissions and failure handling are implemented.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54)),
      ]);

  Widget _section(BuildContext context, String title, IconData icon, Widget child) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 9), Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))]), const SizedBox(height: 16), child])));

  Widget _message(String message, bool error) => Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: (error ? Theme.of(context).colorScheme.errorContainer : Theme.of(context).colorScheme.primaryContainer).withOpacity(.65), borderRadius: BorderRadius.circular(10)), child: Text(message));
}
