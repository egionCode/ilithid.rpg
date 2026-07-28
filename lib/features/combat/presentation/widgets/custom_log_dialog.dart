import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/combat/presentation/providers/combat_actions_provider.dart';
import 'package:ilithid/shared/components/app_text_field.dart';
import 'package:ilithid/shared/theme/app_colors.dart';

/// Lets the GM add a free-form note to the session log (Story 8.1
/// `custom` type), for narrative events not tied to an HP change.
class CustomLogDialog extends ConsumerStatefulWidget {
  final String sessionId;

  const CustomLogDialog({super.key, required this.sessionId});

  @override
  ConsumerState<CustomLogDialog> createState() => _CustomLogDialogState();
}

class _CustomLogDialogState extends ConsumerState<CustomLogDialog> {
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isSubmitting = true);

    final service = ref.read(combatActionsProvider);
    final actorName = ref.read(authProvider).displayName ?? 'Mestre';
    final success = await service.writeCustomLog(
      sessionId: widget.sessionId,
      actorName: actorName,
      message: message,
    );

    if (!mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Nota adicionada ao log!' : 'Erro ao adicionar nota.',
        ),
        backgroundColor: success ? AppColors.heal : AppColors.damage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Adicionar Nota ao Log',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              key: const Key('custom_log_message_field'),
              controller: _messageController,
              labelText: 'Mensagem',
              hintText: 'Ex: O grupo encontrou uma armadilha.',
            ),
            const SizedBox(height: 20),
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
                    key: const Key('custom_log_submit_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: _submit,
                    child: const Text('Adicionar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
