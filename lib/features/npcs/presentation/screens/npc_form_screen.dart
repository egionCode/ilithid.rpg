import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilithid/features/npcs/presentation/providers/npc_templates_provider.dart';
import 'package:ilithid/features/npcs/presentation/providers/npc_templates_state.dart';
import 'package:ilithid/shared/components/app_button.dart';
import 'package:ilithid/shared/components/app_card.dart';
import 'package:ilithid/shared/components/app_text_field.dart';
import 'package:ilithid/shared/theme/app_colors.dart';

class NpcFormScreen extends ConsumerStatefulWidget {
  const NpcFormScreen({super.key});

  @override
  ConsumerState<NpcFormScreen> createState() => _NpcFormScreenState();
}

class _NpcFormScreenState extends ConsumerState<NpcFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hpController = TextEditingController(text: '10');
  final _acController = TextEditingController(text: '10');
  String _sourceSystem = 'manual';

  @override
  void dispose() {
    _nameController.dispose();
    _hpController.dispose();
    _acController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final hpMax = int.parse(_hpController.text.trim());
    final ac = int.parse(_acController.text.trim());

    final template = await ref
        .read(npcTemplatesProvider.notifier)
        .createNpcTemplate(name, hpMax, ac, sourceSystem: _sourceSystem);

    if (template != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Template de NPC "${template.name}" criado com sucesso!',
          ),
          backgroundColor: AppColors.heal,
        ),
      );
      context.go('/npcs');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(npcTemplatesProvider);
    final isLoading = state.status == NpcTemplatesStatus.loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo NPC'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/npcs'),
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
                  const Text(
                    'Criar NPC',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cadastre um novo template de monstro ou NPC',
                    textAlign: TextAlign.center,
                    style: TextStyle(
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
                          key: const Key('npc_name_field'),
                          controller: _nameController,
                          labelText: 'Nome do NPC',
                          hintText: 'ex: Goblin Ranger',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'O nome do NPC é obrigatório';
                            }
                            if (value.trim().length < 2) {
                              return 'O nome deve ter pelo menos 2 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          key: const Key('npc_hp_field'),
                          controller: _hpController,
                          labelText: 'HP Máximo',
                          hintText: 'ex: 12',
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
                          key: const Key('npc_ac_field'),
                          controller: _acController,
                          labelText: 'Classe de Armadura (CA)',
                          hintText: 'ex: 13',
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
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          key: const Key('npc_system_field'),
                          initialValue: _sourceSystem,
                          decoration: const InputDecoration(
                            labelText: 'Sistema de RPG',
                            border: OutlineInputBorder(),
                          ),
                          dropdownColor: AppColors.surface,
                          items: const [
                            DropdownMenuItem(
                              value: 'manual',
                              child: Text(
                                'Manual / Outros',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'dnd5e',
                              child: Text(
                                'D&D 5e',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'pathfinder',
                              child: Text(
                                'Pathfinder 2e',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _sourceSystem = val;
                              });
                            }
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
                          key: const Key('npc_submit_button'),
                          onPressed: _submit,
                          isLoading: isLoading,
                          child: const Text('Criar NPC'),
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          onPressed: () => context.go('/npcs'),
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
