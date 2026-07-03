import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilithid/features/characters/domain/character.dart';
import 'package:ilithid/features/characters/presentation/providers/characters_provider.dart';
import 'package:ilithid/features/characters/presentation/providers/characters_state.dart';
import 'package:ilithid/shared/components/app_button.dart';
import 'package:ilithid/shared/components/app_card.dart';
import 'package:ilithid/shared/components/app_text_field.dart';
import 'package:ilithid/shared/theme/app_colors.dart';

class CharacterFormScreen extends ConsumerStatefulWidget {
  final String? characterId;

  const CharacterFormScreen({super.key, this.characterId});

  @override
  ConsumerState<CharacterFormScreen> createState() =>
      _CharacterFormScreenState();
}

class _CharacterFormScreenState extends ConsumerState<CharacterFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hpController = TextEditingController(text: '10');
  final _acController = TextEditingController(text: '10');
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _hpController.dispose();
    _acController.dispose();
    super.dispose();
  }

  void _initFields(Character character) {
    if (_initialized) return;
    _nameController.text = character.name;
    _hpController.text = character.hpMax.toString();
    _acController.text = character.ac.toString();
    _initialized = true;
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final hpMax = int.parse(_hpController.text.trim());
    final ac = int.parse(_acController.text.trim());

    Character? character;

    if (widget.characterId != null) {
      // Edit mode
      character = await ref
          .read(charactersProvider.notifier)
          .updateCharacter(
            widget.characterId!,
            name: name,
            hpMax: hpMax,
            ac: ac,
          );
    } else {
      // Create mode
      character = await ref
          .read(charactersProvider.notifier)
          .createQuickCharacter(name, hpMax, ac);
    }

    if (character != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.characterId != null
                ? 'Ficha de "${character.name}" atualizada!'
                : 'Ficha de "${character.name}" criada com sucesso!',
          ),
          backgroundColor: AppColors.heal,
        ),
      );
      context.go('/characters');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(charactersProvider);
    final isEditMode = widget.characterId != null;

    final isLoading = state.status == CharactersStatus.loading;

    Character? characterToEdit;
    if (isEditMode) {
      try {
        characterToEdit = state.characters.firstWhere(
          (c) => c.id == widget.characterId,
        );
        _initFields(characterToEdit);
      } catch (_) {
        // Character not found or list still loading
      }
    }

    // Show a loading indicator if list is loading and we don't have the data yet in edit mode
    if (isEditMode && characterToEdit == null && isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Carregando Ficha...')),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    // Show error if we are in edit mode but the character was not found in the list
    if (isEditMode && characterToEdit == null && !isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.damage,
              ),
              const SizedBox(height: 16),
              const Text(
                'Ficha de personagem não encontrada.',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                onPressed: () => context.go('/characters'),
                child: const Text('Voltar para Minhas Fichas'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Editar Ficha' : 'Nova Ficha'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/characters'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isEditMode ? 'Editar Ficha' : 'Criar Ficha',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isEditMode
                        ? 'Atualize os atributos do seu personagem'
                        : 'Preencha os dados do seu novo herói',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          key: const Key('char_name_field'),
                          controller: _nameController,
                          labelText: 'Nome do Personagem',
                          hintText: 'ex: Grog Strongjaw',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'O nome do personagem é obrigatório';
                            }
                            if (value.trim().length < 2) {
                              return 'O nome deve ter pelo menos 2 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          key: const Key('char_hp_field'),
                          controller: _hpController,
                          labelText: 'HP Máximo',
                          hintText: 'ex: 45',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'HP máximo é obrigatório';
                            }
                            final val = int.tryParse(value);
                            if (val == null || val <= 0) {
                              return 'HP deve ser maior que zero';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          key: const Key('char_ac_field'),
                          controller: _acController,
                          labelText: 'Classe de Armadura (CA)',
                          hintText: 'ex: 15',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'CA é obrigatória';
                            }
                            final val = int.tryParse(value);
                            if (val == null || val < 0) {
                              return 'CA deve ser no mínimo zero';
                            }
                            return null;
                          },
                        ),
                        if (state.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            state.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.damage,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        AppButton(
                          key: const Key('char_submit_button'),
                          onPressed: _submit,
                          isLoading: isLoading,
                          child: Text(
                            isEditMode ? 'Salvar Alterações' : 'Criar',
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          onPressed: () => context.go('/characters'),
                          variant: AppButtonVariant.secondary,
                          child: const Text('Cancelar'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
