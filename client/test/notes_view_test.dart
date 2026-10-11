import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waste/models/app_models.dart';
import 'package:waste/views/notes_view.dart';

void main() {
  Note note(String text) => Note(
        id: 'note-1',
        text: text,
        createdAt: DateTime(2026, 10, 11),
      );

  Widget host({
    required List<Note> notes,
    required Future<void> Function(String) onAdd,
    required Future<void> Function(Note) onDelete,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: NotesView(
          notes: notes,
          onAdd: onAdd,
          onDelete: onDelete,
          onClear: () async {},
        ),
      ),
    );
  }

  testWidgets('adding a note submits the entered text', (tester) async {
    String? addedText;

    await tester.pumpWidget(
      host(
        notes: const [],
        onAdd: (text) async => addedText = text,
        onDelete: (_) async {},
      ),
    );

    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Keep this locally');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(addedText, 'Keep this locally');
  });

  testWidgets('deleting a note submits the confirmed note', (tester) async {
    final existingNote = note('Remove this note');
    Note? deletedNote;

    await tester.pumpWidget(
      host(
        notes: [existingNote],
        onAdd: (_) async {},
        onDelete: (value) async => deletedNote = value,
      ),
    );

    await tester.tap(find.byTooltip('Delete note'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(deletedNote, same(existingNote));
  });
}
