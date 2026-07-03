import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilithid/features/campaigns/domain/campaign.dart';
import 'package:ilithid/features/campaigns/presentation/providers/campaigns_provider.dart';
import 'package:ilithid/features/characters/domain/character.dart';
import 'package:ilithid/features/characters/presentation/providers/characters_provider.dart';
import 'package:ilithid/features/characters/presentation/providers/characters_state.dart';
import 'package:ilithid/shared/components/app_button.dart';
import 'package:ilithid/shared/components/app_card.dart';
import 'package:ilithid/shared/theme/app_colors.dart';

class JoinCampaignScreen extends ConsumerStatefulWidget {
  final String? initialHexId;

  const JoinCampaignScreen({super.key, this.initialHexId});

  @override
  ConsumerState<JoinCampaignScreen> createState() => _JoinCampaignScreenState();
}

class _JoinCampaignScreenState extends ConsumerState<JoinCampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _isSearching = false;
  bool _searchPerformed = false;
  Campaign? _foundCampaign;
  bool _isAlreadyMember = false;
  Character? _selectedCharacter;

  @override
  void initState() {
    super.initState();
    if (widget.initialHexId != null && widget.initialHexId!.isNotEmpty) {
      _codeController.text = widget.initialHexId!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchCampaign();
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _searchCampaign() async {
    final hexId = _codeController.text.trim();
    if (hexId.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchPerformed = false;
      _foundCampaign = null;
      _isAlreadyMember = false;
      _selectedCharacter = null;
    });

    final campaign = await ref
        .read(campaignsProvider.notifier)
        .findCampaignByHexId(hexId);

    if (campaign == null) {
      setState(() {
        _isSearching = false;
        _searchPerformed = true;
      });
      return;
    }

    final membership = await ref
        .read(campaignsProvider.notifier)
        .checkMembership(campaign.id);

    setState(() {
      _foundCampaign = campaign;
      _isAlreadyMember = membership != null;
      _isSearching = false;
      _searchPerformed = true;
    });
  }

  void _showQuickCharacterDialog() {
    final dialogFormKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final hpController = TextEditingController(text: '10');
    final acController = TextEditingController(text: '10');

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Criar Ficha Rápida',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Form(
            key: dialogFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const Key('quick_char_name_field'),
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do Personagem',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Nome é obrigatório'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('quick_char_hp_field'),
                    controller: hpController,
                    decoration: const InputDecoration(
                      labelText: 'HP Máximo',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'HP Máximo é obrigatório';
                      }
                      final numVal = int.tryParse(val);
                      if (numVal == null || numVal <= 0) {
                        return 'HP deve ser maior que 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('quick_char_ac_field'),
                    controller: acController,
                    decoration: const InputDecoration(
                      labelText: 'Classe de Armadura (CA)',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'CA é obrigatória';
                      }
                      final numVal = int.tryParse(val);
                      if (numVal == null || numVal < 0) {
                        return 'CA deve ser no mínimo 0';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
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
              key: const Key('quick_char_submit_button'),
              onPressed: () async {
                if (dialogFormKey.currentState?.validate() ?? false) {
                  final name = nameController.text.trim();
                  final hp = int.parse(hpController.text.trim());
                  final ac = int.parse(acController.text.trim());

                  Navigator.pop(dialogContext);

                  // Create character in DB
                  final character = await ref
                      .read(charactersProvider.notifier)
                      .createQuickCharacter(name, hp, ac);

                  if (character != null) {
                    if (!mounted) return;
                    setState(() {
                      _selectedCharacter = character;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Ficha de "${character.name}" criada!'),
                        backgroundColor: AppColors.heal,
                      ),
                    );
                  }
                }
              },
              child: const Text('Criar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _joinCampaign() async {
    if (_foundCampaign == null || _selectedCharacter == null) return;

    final member = await ref
        .read(campaignsProvider.notifier)
        .joinCampaign(
          campaignId: _foundCampaign!.id,
          activeCharacterId: _selectedCharacter!.id,
        );

    if (member != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Você entrou na campanha "${_foundCampaign!.name}"!'),
          backgroundColor: AppColors.heal,
        ),
      );
      context.go('/campaigns/${_foundCampaign!.hexId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final charactersState = ref.watch(charactersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrar em Campanha'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.group_add_outlined,
                          size: 64,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Insira o código da campanha',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Digite o código hexadecimal da campanha enviado pelo Mestre.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          key: const Key('hex_id_field'),
                          controller: _codeController,
                          decoration: InputDecoration(
                            labelText: 'Código da Campanha (Hex ID)',
                            hintText: 'ex: abc12345',
                            labelStyle: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                            hintStyle: const TextStyle(
                              color: AppColors.textMuted,
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: AppColors.primary),
                            ),
                            suffixIcon: _codeController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () {
                                      _codeController.clear();
                                      setState(() {
                                        _searchPerformed = false;
                                        _foundCampaign = null;
                                        _isAlreadyMember = false;
                                        _selectedCharacter = null;
                                      });
                                    },
                                  )
                                : null,
                          ),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontFamily: 'monospace',
                            fontSize: 16,
                            letterSpacing: 1.5,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'O código da campanha é obrigatório';
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 20),
                        AppButton(
                          key: const Key('search_campaign_button'),
                          onPressed: _isSearching
                              ? null
                              : () {
                                  if (_formKey.currentState?.validate() ??
                                      false) {
                                    _searchCampaign();
                                  }
                                },
                          child: _isSearching
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Buscar Campanha'),
                        ),
                      ],
                    ),
                  ),

                  // If search was performed and no campaign was found
                  if (_searchPerformed && _foundCampaign == null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.damage.withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.damage.withAlpha(77),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.damage,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Nenhuma campanha encontrada para o código "${_codeController.text}".',
                              style: const TextStyle(
                                color: AppColors.damage,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // If campaign was found
                  if (_foundCampaign != null) ...[
                    const SizedBox(height: 24),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Campanha Encontrada',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _foundCampaign!.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: AppColors.heal,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Status: Ativa',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32, color: AppColors.border),

                          // If already a member
                          if (_isAlreadyMember) ...[
                            const Icon(
                              Icons.check_circle_outline,
                              size: 48,
                              color: AppColors.heal,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Você já participa desta campanha!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            AppButton(
                              onPressed: () => context.go(
                                '/campaigns/${_foundCampaign!.hexId}',
                              ),
                              child: const Text('Ir para o Dashboard'),
                            ),
                          ]
                          // Select Character to join
                          else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Selecione sua Ficha Ativa',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  key: const Key('quick_char_dialog_button'),
                                  onPressed: _showQuickCharacterDialog,
                                  icon: const Icon(
                                    Icons.add,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  label: const Text(
                                    'Nova Ficha',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (charactersState.status ==
                                    CharactersStatus.loading &&
                                charactersState.characters.isEmpty) ...[
                              const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              ),
                            ] else if (charactersState.characters.isEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.folder_open_outlined,
                                      color: AppColors.textMuted,
                                      size: 40,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Você não possui fichas de personagem',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Crie uma Ficha Rápida para poder entrar na campanha.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    AppButton(
                                      key: const Key(
                                        'quick_char_dialog_empty_button',
                                      ),
                                      onPressed: _showQuickCharacterDialog,
                                      variant: AppButtonVariant.secondary,
                                      child: const Text('Criar Ficha Rápida'),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              // Character list selection
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: charactersState.characters.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final char =
                                      charactersState.characters[index];
                                  final isSelected =
                                      _selectedCharacter?.id == char.id;

                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedCharacter = char;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary.withAlpha(26)
                                            : AppColors.background,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.border,
                                          width: isSelected ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isSelected
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_off,
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.textMuted,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  char.name,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: isSelected
                                                        ? AppColors.primary
                                                        : AppColors.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'HP Máx: ${char.hpMax} | CA: ${char.ac}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: 32),
                            AppButton(
                              key: const Key('join_campaign_submit_button'),
                              onPressed: _selectedCharacter == null
                                  ? null
                                  : _joinCampaign,
                              child: const Text('Entrar na Campanha'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
