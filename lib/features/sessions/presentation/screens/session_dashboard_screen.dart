import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilithid/features/campaigns/domain/campaign.dart';
import 'package:ilithid/features/campaigns/domain/campaign_member.dart';
import 'package:ilithid/features/campaigns/domain/user_campaign.dart';
import 'package:ilithid/features/campaigns/presentation/providers/campaigns_provider.dart';
import 'package:ilithid/features/npcs/domain/npc_instance.dart';
import 'package:ilithid/features/npcs/domain/npc_template.dart';
import 'package:ilithid/features/npcs/presentation/providers/npc_instances_provider.dart';
import 'package:ilithid/features/npcs/presentation/providers/npc_instances_state.dart';
import 'package:ilithid/features/npcs/presentation/providers/npc_templates_provider.dart';
import 'package:ilithid/features/npcs/presentation/providers/npc_templates_state.dart';
import 'package:ilithid/shared/components/app_button.dart';
import 'package:ilithid/shared/components/app_card.dart';
import 'package:ilithid/shared/components/app_text_field.dart';
import 'package:ilithid/shared/components/hp_bar.dart';
import 'package:ilithid/shared/components/responsive_builder.dart';
import 'package:ilithid/shared/theme/app_colors.dart';

class SessionDashboardScreen extends ConsumerStatefulWidget {
  final String hexId;
  final String sessionId;

  const SessionDashboardScreen({
    super.key,
    required this.hexId,
    required this.sessionId,
  });

  @override
  ConsumerState<SessionDashboardScreen> createState() =>
      _SessionDashboardScreenState();
}

class _SessionDashboardScreenState
    extends ConsumerState<SessionDashboardScreen> {
  Campaign? _campaign;
  CampaignMember? _member;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCampaignAndMember();
  }

  Future<void> _loadCampaignAndMember() async {
    final notifier = ref.read(campaignsProvider.notifier);
    final campaignsState = ref.read(campaignsProvider);

    Campaign? campaign;
    final userCamp = campaignsState.campaigns.cast<UserCampaign?>().firstWhere(
      (uc) => uc?.campaign.hexId.toLowerCase() == widget.hexId.toLowerCase(),
      orElse: () => null,
    );

    if (userCamp != null) {
      campaign = userCamp.campaign;
    } else {
      campaign = await notifier.findCampaignByHexId(widget.hexId);
    }

    if (campaign == null) {
      if (mounted) {
        setState(() {
          _error = 'Campanha não encontrada.';
          _isLoading = false;
        });
      }
      return;
    }

    final member = await notifier.checkMembership(campaign.id);

    if (mounted) {
      setState(() {
        _campaign = campaign;
        _member = member;
        _isLoading = false;
      });
    }
  }

  void _showAddNpcDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _AddNpcDialog(sessionId: widget.sessionId);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_error != null || _campaign == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: Center(
          child: Text(
            _error ?? 'Erro desconhecido',
            style: const TextStyle(color: AppColors.damage),
          ),
        ),
      );
    }

    final isGm = _member?.role == 'gm';
    final npcInstancesState = ref.watch(npcInstancesProvider(widget.sessionId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          key: const Key('session_back_button'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/campaigns/${widget.hexId}'),
        ),
        title: Text(
          'Sessão — ${_campaign!.name}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Session info card
              AppCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.play_circle_fill_outlined,
                      color: AppColors.heal,
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SESSÃO ATIVA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.heal,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _campaign!.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'NPCs em Combate',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (isGm)
                    AppButton(
                      onPressed: () => _showAddNpcDialog(context),
                      child: const Row(
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text('Adicionar NPC'),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              if (npcInstancesState.status == NpcInstancesStatus.loading &&
                  npcInstancesState.npcInstances.isEmpty)
                const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              else if (npcInstancesState.status == NpcInstancesStatus.error)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.damage.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.damage.withAlpha(76)),
                  ),
                  child: Text(
                    npcInstancesState.errorMessage!,
                    style: const TextStyle(color: AppColors.damage),
                  ),
                ),
              const SizedBox(height: 16),

              if (npcInstancesState.npcInstances.isEmpty &&
                  npcInstancesState.status != NpcInstancesStatus.loading)
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.face_retouching_natural_outlined,
                          size: 64,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Nenhum NPC em combate',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isGm
                              ? 'Toque em "Adicionar NPC" para trazer monstros ou aliados para o combate.'
                              : 'Aguarde o Mestre instanciar NPCs nesta sessão.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ResponsiveBuilder(
                  builder: (context, deviceType) {
                    final isMobile = deviceType == DeviceType.mobile;
                    final crossAxisCount = isMobile ? 1 : 2;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 96,
                      ),
                      itemCount: npcInstancesState.npcInstances.length,
                      itemBuilder: (context, index) {
                        final instance = npcInstancesState.npcInstances[index];
                        return _NpcInstanceCard(
                          instance: instance,
                          isGm: isGm,
                          sessionId: widget.sessionId,
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NpcInstanceCard extends ConsumerWidget {
  final NpcInstance instance;
  final bool isGm;
  final String sessionId;

  const _NpcInstanceCard({
    required this.instance,
    required this.isGm,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            child: const Icon(Icons.gavel, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        instance.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'CA ${instance.ac}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                HpBar(
                  currentHp: instance.hpCurrent,
                  maxHp: instance.hpMax,
                  tempHp: instance.hpTemp,
                  height: 16,
                ),
              ],
            ),
          ),
          if (isGm) ...[
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(
                Icons.favorite_outline,
                color: AppColors.heal,
                size: 22,
              ),
              onPressed: () => _showAdjustHpDialog(context, ref),
              tooltip: 'Ajustar HP',
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.damage,
                size: 22,
              ),
              onPressed: () => _confirmDelete(context, ref),
              tooltip: 'Remover NPC',
            ),
          ],
        ],
      ),
    );
  }

  void _showAdjustHpDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _AdjustHpDialog(instance: instance, sessionId: sessionId);
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'Remover ${instance.name}',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: const Text(
            'Deseja realmente remover este NPC do combate?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.damage,
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final success = await ref
                    .read(npcInstancesProvider(sessionId).notifier)
                    .deleteNpcInstance(instance.id);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'NPC removido com sucesso!'
                            : 'Erro ao remover NPC.',
                      ),
                      backgroundColor: success
                          ? AppColors.heal
                          : AppColors.damage,
                    ),
                  );
                }
              },
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );
  }
}

class _AddNpcDialog extends ConsumerStatefulWidget {
  final String sessionId;

  const _AddNpcDialog({required this.sessionId});

  @override
  ConsumerState<_AddNpcDialog> createState() => _AddNpcDialogState();
}

class _AddNpcDialogState extends ConsumerState<_AddNpcDialog> {
  final TextEditingController _searchController = TextEditingController();
  NpcTemplate? _selectedTemplate;
  String _searchQuery = '';

  final _nameController = TextEditingController();
  final _hpController = TextEditingController();
  final _acController = TextEditingController();
  bool _isInstantiating = false;

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _hpController.dispose();
    _acController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templatesState = ref.watch(npcTemplatesProvider);
    final allTemplates = <NpcTemplate>[
      ...templatesState.myTemplates,
      ...templatesState.publicTemplates,
    ];

    // Unique by ID
    final uniqueTemplatesMap = {for (var t in allTemplates) t.id: t};
    final uniqueTemplates = uniqueTemplatesMap.values.toList();

    final filteredTemplates = uniqueTemplates.where((t) {
      if (_searchQuery.isEmpty) return true;
      return t.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: _selectedTemplate == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Selecionar Template de NPC',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    key: const Key('dialog_search_field'),
                    controller: _searchController,
                    labelText: 'Buscar por nome',
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: () {
                      if (templatesState.status == NpcTemplatesStatus.loading ||
                          templatesState.status == NpcTemplatesStatus.initial) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Carregando fichas de NPCs...',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      if (templatesState.status == NpcTemplatesStatus.error) {
                        return Center(
                          child: Text(
                            templatesState.errorMessage ??
                                'Erro ao carregar templates.',
                            style: const TextStyle(color: AppColors.damage),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      if (filteredTemplates.isEmpty) {
                        return const Center(
                          child: Text(
                            'Nenhum template encontrado.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: filteredTemplates.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final template = filteredTemplates[index];
                          return ListTile(
                            key: Key('template_option_${template.id}'),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            title: Text(
                              template.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              'HP Máx: ${template.hpMax} | CA: ${template.ac}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            tileColor: AppColors.background,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            onTap: () {
                              setState(() {
                                _selectedTemplate = template;
                                _nameController.text = template.name;
                                _hpController.text = template.hpMax.toString();
                                _acController.text = template.ac.toString();
                              });
                            },
                          );
                        },
                      );
                    }(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Instanciar: ${_selectedTemplate!.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    key: const Key('instantiate_name_field'),
                    controller: _nameController,
                    labelText: 'Nome Customizado',
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    key: const Key('instantiate_hp_field'),
                    controller: _hpController,
                    labelText: 'HP Máximo',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    key: const Key('instantiate_ac_field'),
                    controller: _acController,
                    labelText: 'Classe de Armadura (CA)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedTemplate = null;
                          });
                        },
                        child: const Text(
                          'Voltar',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_isInstantiating)
                        const CircularProgressIndicator(
                          color: AppColors.primary,
                        )
                      else
                        AppButton(
                          key: const Key('confirm_instantiate_button'),
                          onPressed: () async {
                            final name = _nameController.text.trim();
                            final hp =
                                int.tryParse(_hpController.text) ??
                                _selectedTemplate!.hpMax;
                            final ac =
                                int.tryParse(_acController.text) ??
                                _selectedTemplate!.ac;

                            if (name.isEmpty) return;

                            setState(() {
                              _isInstantiating = true;
                            });

                            final result = await ref
                                .read(
                                  npcInstancesProvider(
                                    widget.sessionId,
                                  ).notifier,
                                )
                                .instantiateNpc(
                                  name: name,
                                  hpMax: hp,
                                  ac: ac,
                                  templateId: _selectedTemplate!.id,
                                );

                            if (context.mounted) {
                              if (result != null) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'NPC "$name" instanciado com sucesso!',
                                    ),
                                    backgroundColor: AppColors.heal,
                                  ),
                                );
                              } else {
                                if (mounted) {
                                  setState(() {
                                    _isInstantiating = false;
                                  });
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Erro ao instanciar NPC.'),
                                    backgroundColor: AppColors.damage,
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Instanciar'),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _AdjustHpDialog extends ConsumerStatefulWidget {
  final NpcInstance instance;
  final String sessionId;

  const _AdjustHpDialog({required this.instance, required this.sessionId});

  @override
  ConsumerState<_AdjustHpDialog> createState() => _AdjustHpDialogState();
}

class _AdjustHpDialogState extends ConsumerState<_AdjustHpDialog> {
  late final TextEditingController _hpController;
  late final TextEditingController _tempHpController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _hpController = TextEditingController(
      text: widget.instance.hpCurrent.toString(),
    );
    _tempHpController = TextEditingController(
      text: widget.instance.hpTemp.toString(),
    );
  }

  @override
  void dispose() {
    _hpController.dispose();
    _tempHpController.dispose();
    super.dispose();
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
              'Ajustar HP: ${widget.instance.name}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'HP Máximo do Template: ${widget.instance.hpMax}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            AppTextField(
              key: const Key('adjust_hp_current_field'),
              controller: _hpController,
              labelText: 'HP Atual',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            AppTextField(
              key: const Key('adjust_hp_temp_field'),
              controller: _tempHpController,
              labelText: 'HP Temporário',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Salvar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final hp = int.tryParse(_hpController.text);
    final tempHp = int.tryParse(_tempHpController.text);

    if (hp == null || hp < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, insira um valor válido de HP.'),
          backgroundColor: AppColors.damage,
        ),
      );
      return;
    }

    if (tempHp == null || tempHp < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, insira um valor válido de HP Temporário.'),
          backgroundColor: AppColors.damage,
        ),
      );
      return;
    }

    if (hp > widget.instance.hpMax) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'O HP Atual não pode exceder o HP Máximo (${widget.instance.hpMax}). '
            'Caso queira adicionar pontos adicionais, utilize o HP Temporário.',
          ),
          backgroundColor: AppColors.damage,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final success = await ref
        .read(npcInstancesProvider(widget.sessionId).notifier)
        .updateNpcHp(widget.instance.id, hpCurrent: hp, hpTemp: tempHp);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'HP ajustado com sucesso!' : 'Erro ao ajustar HP.',
          ),
          backgroundColor: success ? AppColors.heal : AppColors.damage,
        ),
      );
    }
  }
}
