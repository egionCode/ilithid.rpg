import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/combat/domain/combat_target.dart';
import 'package:ilithid/features/combat/presentation/providers/combat_actions_provider.dart';
import 'package:ilithid/shared/components/app_text_field.dart';
import 'package:ilithid/shared/theme/app_colors.dart';

enum _CombatAction { damage, heal, tempHp }

/// Quick-action dialog to apply damage, heal or temporary HP to a
/// [CombatTarget] (Story 7.2 GM panel, Story 7.3 player self-actions).
class CombatActionDialog extends ConsumerStatefulWidget {
  final CombatTarget target;
  final String sessionId;

  const CombatActionDialog({
    super.key,
    required this.target,
    required this.sessionId,
  });

  @override
  ConsumerState<CombatActionDialog> createState() => _CombatActionDialogState();
}

class _CombatActionDialogState extends ConsumerState<CombatActionDialog> {
  final _amountController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _apply(_CombatAction action) async {
    final amount = int.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um valor numérico maior que zero.'),
          backgroundColor: AppColors.damage,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final service = ref.read(combatActionsProvider);
    final actorName = ref.read(authProvider).displayName ?? 'Sistema';
    final success = switch (action) {
      _CombatAction.damage => await service.applyDamage(
        target: widget.target,
        sessionId: widget.sessionId,
        actorName: actorName,
        amount: amount,
      ),
      _CombatAction.heal => await service.applyHeal(
        target: widget.target,
        sessionId: widget.sessionId,
        actorName: actorName,
        amount: amount,
      ),
      _CombatAction.tempHp => await service.applyTempHp(
        target: widget.target,
        sessionId: widget.sessionId,
        actorName: actorName,
        amount: amount,
      ),
    };

    if (!mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Ação aplicada com sucesso!' : 'Erro ao aplicar ação.',
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
            Text(
              widget.target.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              key: const Key('combat_action_amount_field'),
              controller: _amountController,
              labelText: 'Valor',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            if (_isSubmitting)
              const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    key: const Key('combat_action_damage_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.damage,
                    ),
                    onPressed: () => _apply(_CombatAction.damage),
                    icon: const Icon(Icons.local_fire_department, size: 18),
                    label: const Text('Dano'),
                  ),
                  ElevatedButton.icon(
                    key: const Key('combat_action_heal_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.heal,
                    ),
                    onPressed: () => _apply(_CombatAction.heal),
                    icon: const Icon(Icons.favorite, size: 18),
                    label: const Text('Cura'),
                  ),
                  ElevatedButton.icon(
                    key: const Key('combat_action_temp_hp_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tempHp,
                    ),
                    onPressed: () => _apply(_CombatAction.tempHp),
                    icon: const Icon(Icons.shield, size: 18),
                    label: const Text('HP Temp'),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
