import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilithid/features/characters/domain/character.dart';
import 'package:ilithid/features/characters/presentation/providers/characters_provider.dart';
import 'package:ilithid/features/characters/presentation/providers/characters_state.dart';
import 'package:ilithid/shared/components/app_button.dart';
import 'package:ilithid/shared/components/app_card.dart';
import 'package:ilithid/shared/components/foundry_import_dialog.dart';
import 'package:ilithid/shared/theme/app_colors.dart';

class CharactersListScreen extends ConsumerWidget {
  const CharactersListScreen({super.key});

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return FoundryImportDialog(
          title: 'Importar Ficha do Foundry',
          onConfirm: (parsed, rawJson) async {
            final character = await ref
                .read(charactersProvider.notifier)
                .createFromFoundry(parsed: parsed, rawJson: rawJson);
            return character != null;
          },
        );
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Character character,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Excluir Ficha',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            'Tem certeza que deseja excluir a ficha de "${character.name}"? Esta ação não pode ser desfeita.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            AppButton(
              key: const Key('confirm_delete_button'),
              onPressed: () async {
                Navigator.pop(dialogContext);
                final success = await ref
                    .read(charactersProvider.notifier)
                    .deleteCharacter(character.id);

                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ficha de "${character.name}" excluída!'),
                      backgroundColor: AppColors.heal,
                    ),
                  );
                }
              },
              variant: AppButtonVariant.danger,
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(charactersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Fichas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            key: const Key('import_foundry_character_button'),
            icon: const Icon(Icons.upload_file),
            tooltip: 'Importar do Foundry',
            onPressed: () => _showImportDialog(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_character_fab'),
        backgroundColor: AppColors.primary,
        onPressed: () => context.go('/characters/new'),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nova Ficha', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          await ref.read(charactersProvider.notifier).fetchCharacters();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Suas Fichas de Personagem',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Gerencie suas fichas e use-as para entrar em campanhas.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (state.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.damage.withAlpha(26),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.damage.withAlpha(77),
                        ),
                      ),
                      child: Text(
                        state.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.damage),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (state.status == CharactersStatus.loading &&
                      state.characters.isEmpty) ...[
                    const SizedBox(height: 80),
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ] else if (state.characters.isEmpty) ...[
                    const SizedBox(height: 40),
                    AppCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.folder_open_outlined,
                              size: 64,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Nenhuma ficha encontrada',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Crie sua primeira ficha de personagem manual para começar a jogar.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            AppButton(
                              key: const Key('empty_state_add_char_button'),
                              onPressed: () => context.go('/characters/new'),
                              child: const Text('Criar Ficha Manual'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.characters.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final character = state.characters[index];

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(26),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.shield_outlined,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      character.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'HP: ${character.hpCurrent}/${character.hpMax} | CA: ${character.ac}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                key: Key('edit_char_${character.id}'),
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () => context.go(
                                  '/characters/${character.id}/edit',
                                ),
                              ),
                              IconButton(
                                key: Key('delete_char_${character.id}'),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.damage,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _confirmDelete(context, ref, character),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
