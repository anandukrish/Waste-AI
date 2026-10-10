import 'package:flutter/material.dart';

import 'models/app_models.dart';
import 'services/local_store.dart';
import 'services/waste_api.dart';
import 'views/chat_view.dart';
import 'views/notes_view.dart';
import 'views/settings_view.dart';
import 'widgets/setup_dialog.dart';

enum WasteSection { chat, notes, settings }

class WasteShell extends StatefulWidget {
  const WasteShell({super.key, required this.store});

  final LocalStore store;

  @override
  State<WasteShell> createState() => _WasteShellState();
}

class _WasteShellState extends State<WasteShell> {
  late AppSettings _settings;
  late List<Note> _notes;
  late List<ChatMessage> _history;
  final WasteApi _api = WasteApi();
  WasteSection _section = WasteSection.chat;
  String? _token;
  bool _loading = true;
  bool _chatBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _settings = widget.store.settings;
    _notes = widget.store.notes;
    _history = widget.store.history;
    _token = await widget.store.readToken();
    if (!mounted) return;
    setState(() => _loading = false);
    if (_settings.showSetup) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSetup());
    }
  }

  Future<void> _showSetup() async {
    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SetupDialog(
        host: _settings.host,
        onSave: (host, token) async {
          await _saveConnection(host, token);
        },
      ),
    );
    if (completed == true && mounted) {
      setState(() => _settings = _settings.copyWith(showSetup: false));
      await widget.store.saveSettings(_settings);
    }
  }

  Future<void> _saveConnection(String host, String token) async {
    final validated = WasteApi.validateBaseUrl(host);
    _settings = _settings.copyWith(host: validated.toString());
    await widget.store.saveSettings(_settings);
    if (token.trim().isEmpty) {
      await widget.store.clearToken();
      _token = null;
    } else {
      await widget.store.saveToken(token.trim());
      _token = token.trim();
    }
    if (mounted) setState(() {});
  }

  Future<void> _setMode(String mode) async {
    _settings = _settings.copyWith(mode: mode);
    await widget.store.saveSettings(_settings);
    if (mounted) setState(() {});
  }

  Future<void> _addNote(String text) async {
    final note = Note(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text.trim(),
      createdAt: DateTime.now(),
    );
    _notes = [note, ..._notes];
    await widget.store.saveNotes(_notes);
    if (mounted) setState(() {});
  }

  Future<void> _deleteNote(Note note) async {
    _notes = _notes.where((item) => item.id != note.id).toList();
    await widget.store.saveNotes(_notes);
    if (mounted) setState(() {});
  }

  Future<void> _clearNotes() async {
    _notes = [];
    await widget.store.clearNotes();
    if (mounted) setState(() {});
  }

  Future<void> _clearHistory() async {
    _history = [];
    await widget.store.clearHistory();
    if (mounted) setState(() {});
  }

  Future<void> _disconnect() async {
    await widget.store.clearToken();
    _token = null;
    if (mounted) setState(() {});
  }

  Future<void> _appendHistory(ChatMessage user, ChatMessage assistant) async {
    _history = [..._history, user, assistant];
    if (_history.length > 40) _history = _history.sublist(_history.length - 40);
    await widget.store.saveHistory(_history);
    if (mounted) setState(() {});
  }

  void _setChatBusy(bool busy) {
    if (mounted) setState(() => _chatBusy = busy);
  }

  void _navigate(WasteSection section) {
    if (_chatBusy && section != WasteSection.chat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wait for the pending chat request to finish.')),
      );
      return;
    }
    setState(() => _section = section);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final content = switch (_section) {
      WasteSection.chat => ChatView(
          api: _api,
          host: _settings.host,
          token: _token,
          mode: _settings.mode,
          history: _history,
          onModeChanged: _setMode,
          onMessages: _appendHistory,
          onOpenSettings: () => _navigate(WasteSection.settings),
          onBusyChanged: _setChatBusy,
        ),
      WasteSection.notes => NotesView(
          notes: _notes,
          onAdd: _addNote,
          onDelete: _deleteNote,
          onClear: _clearNotes,
        ),
      WasteSection.settings => SettingsView(
          api: _api,
          host: _settings.host,
          token: _token,
          mode: _settings.mode,
          onSaveConnection: _saveConnection,
          onModeChanged: _setMode,
          onClearChats: _clearHistory,
          onClearNotes: _clearNotes,
          onDisconnect: _disconnect,
          onOpenChat: () => _navigate(WasteSection.chat),
        ),
    };
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide) _rail(),
            Expanded(child: content),
          ],
        ),
      ),
      bottomNavigationBar: wide ? null : NavigationBar(
          selectedIndex: _section.index,
          onDestinationSelected: (index) => _navigate(WasteSection.values[index]),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chat'),
            NavigationDestination(icon: Icon(Icons.sticky_note_2_outlined), selectedIcon: Icon(Icons.sticky_note_2), label: 'Notes'),
            NavigationDestination(icon: Icon(Icons.tune), selectedIcon: Icon(Icons.tune), label: 'Settings'),
          ],
        ),
    );
  }

  Widget _rail() => NavigationRail(
        selectedIndex: _section.index,
        onDestinationSelected: (index) => _navigate(WasteSection.values[index]),
        labelType: NavigationRailLabelType.all,
        leading: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary, size: 30),
              const SizedBox(height: 8),
              Text('WASTE', style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
        destinations: const [
          NavigationRailDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: Text('Chat')),
          NavigationRailDestination(icon: Icon(Icons.sticky_note_2_outlined), selectedIcon: Icon(Icons.sticky_note_2), label: Text('Notes')),
          NavigationRailDestination(icon: Icon(Icons.tune), selectedIcon: Icon(Icons.tune), label: Text('Settings')),
        ],
      );
}
