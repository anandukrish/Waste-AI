import 'package:flutter/material.dart';

import '../models/app_models.dart';

class NotesView extends StatelessWidget {
  const NotesView({
    super.key,
    required this.notes,
    required this.onAdd,
    required this.onDelete,
    required this.onClear,
  });

  final List<Note> notes;
  final Future<void> Function(String) onAdd;
  final Future<void> Function(Note) onDelete;
  final Future<void> Function() onClear;

  Future<void> _add(BuildContext context) async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => const _NoteEditorDialog(),
    );
    if (text != null && text.trim().isNotEmpty) await onAdd(text);
  }

  Future<void> _delete(BuildContext context, Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text(
          'This local note will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onDelete(note);
  }

  Future<void> _clear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all notes?'),
        content: const Text(
          'Every saved note on this device will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear notes'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onClear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notes',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Saved only on this device.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white60),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Clear notes',
                onPressed: notes.isEmpty ? null : () => _clear(context),
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: () => _add(context),
                icon: const Icon(Icons.add),
                label: const Text('New note'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: notes.isEmpty
                ? Center(
                    child: Text(
                      'No notes yet. Add one while offline.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: Colors.white60),
                    ),
                  )
                : ListView.separated(
                    itemCount: notes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return Card(
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.fromLTRB(18, 8, 8, 8),
                          title: Text(note.text),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_date(note.createdAt)),
                          ),
                          trailing: IconButton(
                            tooltip: 'Delete note',
                            onPressed: () => _delete(context, note),
                            icon: const Icon(Icons.delete_outline),
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

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class _NoteEditorDialog extends StatefulWidget {
  const _NoteEditorDialog();

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New note'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 6,
        decoration: const InputDecoration(
          hintText: 'Write something worth keeping…',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
