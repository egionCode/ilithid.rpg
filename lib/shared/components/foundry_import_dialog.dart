import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:ilithid/shared/components/app_button.dart';
import 'package:ilithid/shared/services/foundry_parser.dart';
import 'package:ilithid/shared/theme/app_colors.dart';

/// Shared file-picker → parse → preview → confirm flow for importing a
/// Foundry VTT actor export, reused by character import (Story 10.2) and
/// NPC template import (Story 10.3) - the only difference between the two
/// is what [onConfirm] does with the parsed result.
class FoundryImportDialog extends StatefulWidget {
  final String title;
  final Future<bool> Function(FoundryParseResult parsed, String rawJson)
  onConfirm;

  /// Overrides the real file picker in tests, since file_selector's
  /// `openFile` talks to a platform channel that isn't available under
  /// `flutter_test`. Returns the picked file's raw bytes, or null if the
  /// user cancelled.
  final Future<Uint8List?> Function()? pickFile;

  const FoundryImportDialog({
    super.key,
    required this.title,
    required this.onConfirm,
    this.pickFile,
  });

  @override
  State<FoundryImportDialog> createState() => _FoundryImportDialogState();
}

class _FoundryImportDialogState extends State<FoundryImportDialog> {
  String? _error;
  FoundryParseResult? _parsed;
  String? _rawJson;
  bool _isSubmitting = false;

  Future<Uint8List?> _defaultPickFile() async {
    const jsonType = XTypeGroup(label: 'json', extensions: ['json']);
    final file = await openFile(acceptedTypeGroups: const [jsonType]);
    if (file == null) return null;
    return file.readAsBytes();
  }

  Future<void> _pickFile() async {
    setState(() => _error = null);

    try {
      final bytes = await (widget.pickFile ?? _defaultPickFile)();
      if (bytes == null) return;

      final rawJson = utf8.decode(bytes);
      final parsed = FoundryParser.parse(rawJson);

      if (!mounted) return;
      setState(() {
        _parsed = parsed;
        _rawJson = rawJson;
      });
    } on FoundryParseException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Erro ao ler o arquivo selecionado.');
    }
  }

  Future<void> _confirm() async {
    final parsed = _parsed;
    final rawJson = _rawJson;
    if (parsed == null || rawJson == null) return;

    setState(() => _isSubmitting = true);
    final success = await widget.onConfirm(parsed, rawJson);
    if (!mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${parsed.name} importado com sucesso!'
              : 'Erro ao importar.',
        ),
        backgroundColor: success ? AppColors.heal : AppColors.damage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.damage.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.damage.withAlpha(77)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.damage),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (parsed == null)
              AppButton(
                key: const Key('foundry_pick_file_button'),
                onPressed: _pickFile,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_file, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Selecionar arquivo .json',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  key: const Key('foundry_preview'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parsed.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'HP: ${parsed.hpCurrent}/${parsed.hpMax} | CA: ${parsed.ac} | '
                      '${parsed.entityType == FoundryEntityType.npc ? 'NPC' : 'Personagem'}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    if (parsed.unrecognizedFields.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Campos ainda não suportados: '
                        '${parsed.unrecognizedFields.join(', ')}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isSubmitting)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    ElevatedButton(
                      key: const Key('foundry_confirm_import_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: _confirm,
                      child: const Text('Confirmar'),
                    ),
                ],
              ),
            ],
            if (parsed == null) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
