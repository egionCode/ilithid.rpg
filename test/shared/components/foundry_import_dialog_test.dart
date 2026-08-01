import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/shared/components/foundry_import_dialog.dart';
import 'package:ilithid/shared/services/foundry_parser.dart';

Uint8List _jsonBytes(Map<String, dynamic> data) {
  return Uint8List.fromList(utf8.encode(jsonEncode(data)));
}

FilePickerResult _resultWithBytes(Uint8List bytes, {String name = 'a.json'}) {
  return FilePickerResult([
    PlatformFile(name: name, size: bytes.length, bytes: bytes),
  ]);
}

void main() {
  Widget buildTestWidget({
    required Future<FilePickerResult?> Function() pickFile,
    required Future<bool> Function(FoundryParseResult parsed, String rawJson)
    onConfirm,
  }) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open_dialog_button'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => FoundryImportDialog(
                    title: 'Importar Ficha do Foundry',
                    pickFile: pickFile,
                    onConfirm: onConfirm,
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          );
        },
      ),
    );
  }

  testWidgets('shows a preview after picking a valid file', (tester) async {
    final bytes = _jsonBytes({
      'name': 'Aragorn',
      'type': 'character',
      'system': {
        'attributes': {
          'hp': {'value': 45, 'max': 50},
          'ac': {'value': 16},
        },
      },
    });

    await tester.pumpWidget(
      buildTestWidget(
        pickFile: () async => _resultWithBytes(bytes),
        onConfirm: (_, _) async => true,
      ),
    );

    await tester.tap(find.byKey(const Key('open_dialog_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('foundry_pick_file_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('foundry_preview')), findsOneWidget);
    expect(find.text('Aragorn'), findsOneWidget);
    expect(find.textContaining('HP: 45/50'), findsOneWidget);
  });

  testWidgets('shows a friendly error for invalid JSON', (tester) async {
    final bytes = Uint8List.fromList(utf8.encode('{not valid json'));

    await tester.pumpWidget(
      buildTestWidget(
        pickFile: () async => _resultWithBytes(bytes),
        onConfirm: (_, _) async => true,
      ),
    );

    await tester.tap(find.byKey(const Key('open_dialog_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('foundry_pick_file_button')));
    await tester.pumpAndSettle();

    expect(find.text('O arquivo não é um JSON válido.'), findsOneWidget);
    expect(find.byKey(const Key('foundry_preview')), findsNothing);
  });

  testWidgets('confirming calls onConfirm with the parsed result', (
    tester,
  ) async {
    final bytes = _jsonBytes({
      'name': 'Orc',
      'type': 'npc',
      'system': {
        'attributes': {
          'hp': {'value': 10, 'max': 15},
          'ac': {'value': 13},
        },
      },
    });

    FoundryParseResult? received;
    await tester.pumpWidget(
      buildTestWidget(
        pickFile: () async => _resultWithBytes(bytes),
        onConfirm: (parsed, rawJson) async {
          received = parsed;
          return true;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('open_dialog_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('foundry_pick_file_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('foundry_confirm_import_button')));
    await tester.pumpAndSettle();

    expect(received, isNotNull);
    expect(received!.name, 'Orc');
    expect(received!.entityType, FoundryEntityType.npc);
    expect(find.text('Orc importado com sucesso!'), findsOneWidget);
  });

  testWidgets('does nothing when the user cancels the file picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestWidget(
        pickFile: () async => null,
        onConfirm: (_, _) async => true,
      ),
    );

    await tester.tap(find.byKey(const Key('open_dialog_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('foundry_pick_file_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('foundry_preview')), findsNothing);
  });
}
