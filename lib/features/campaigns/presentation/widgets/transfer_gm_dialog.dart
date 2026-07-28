import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/campaigns/presentation/providers/campaigns_provider.dart';
import 'package:ilithid/features/combat/presentation/providers/party_provider.dart';
import 'package:ilithid/features/combat/presentation/providers/party_state.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';
import 'package:ilithid/shared/theme/app_colors.dart';

/// Lets the current GM pick another campaign member to hand the GM role
/// to (Story 9.1). Only lists members whose role is `player`.
class TransferGmDialog extends ConsumerStatefulWidget {
  final String campaignId;
  final String currentUserId;

  const TransferGmDialog({
    super.key,
    required this.campaignId,
    required this.currentUserId,
  });

  @override
  ConsumerState<TransferGmDialog> createState() => _TransferGmDialogState();
}

class _TransferGmDialogState extends ConsumerState<TransferGmDialog> {
  final Map<String, String> _displayNames = {};
  final Set<String> _resolving = {};
  bool _isTransferring = false;

  /// Resolves and caches a userId's displayName from `profiles`, falling
  /// back to the raw id if the lookup fails (e.g. a deleted account).
  Future<void> _resolveName(String userId) async {
    if (_displayNames.containsKey(userId) || _resolving.contains(userId)) {
      return;
    }
    _resolving.add(userId);

    final tablesDb = ref.read(appwriteTablesDbProvider);
    var name = userId;
    try {
      final profile = await tablesDb.getRow(
        databaseId: appwriteDatabaseId,
        tableId: appwriteProfilesTableId,
        rowId: userId,
      );
      name = (profile.data['displayName'] as String?) ?? userId;
    } catch (_) {
      // Keep the raw id as the fallback name.
    }

    if (!mounted) return;
    setState(() {
      _displayNames[userId] = name;
      _resolving.remove(userId);
    });
  }

  void _confirmTransfer(PartyMember target) {
    final name = _displayNames[target.member.userId] ?? target.member.userId;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Transferir Mestre'),
          content: Text(
            'Tem certeza? Você perderá os poderes de Mestre e $name se '
            'tornará o novo Mestre da campanha.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              key: const Key('confirm_transfer_gm_button'),
              onPressed: _isTransferring
                  ? null
                  : () async {
                      Navigator.of(dialogContext).pop();
                      setState(() => _isTransferring = true);

                      final success = await ref
                          .read(campaignsProvider.notifier)
                          .transferGm(
                            campaignId: widget.campaignId,
                            newGmUserId: target.member.userId,
                          );

                      if (!mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Mestre transferido para $name!'
                                : 'Erro ao transferir o papel de Mestre.',
                          ),
                          backgroundColor: success
                              ? AppColors.heal
                              : AppColors.damage,
                        ),
                      );
                    },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final partyState = ref.watch(partyProvider(widget.campaignId));
    final players = partyState.members
        .where(
          (m) =>
              m.member.role == 'player' &&
              m.member.userId != widget.currentUserId,
        )
        .toList();

    for (final player in players) {
      _resolveName(player.member.userId);
    }

    final isLoadingParty =
        partyState.status == PartyStatus.loading && partyState.members.isEmpty;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Transferir Papel de Mestre',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (_isTransferring || isLoadingParty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (players.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Não há outros jogadores nesta campanha.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: players.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final player = players[index];
                    final name =
                        _displayNames[player.member.userId] ??
                        player.member.userId;
                    return ListTile(
                      key: Key('transfer_gm_option_${player.member.userId}'),
                      tileColor: AppColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      onTap: () => _confirmTransfer(player),
                    );
                  },
                ),
              ),
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
        ),
      ),
    );
  }
}
