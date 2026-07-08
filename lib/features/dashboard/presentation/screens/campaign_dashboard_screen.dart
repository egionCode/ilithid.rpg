import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilithid/features/campaigns/domain/campaign.dart';
import 'package:ilithid/features/campaigns/domain/campaign_member.dart';
import 'package:ilithid/features/campaigns/domain/user_campaign.dart';
import 'package:ilithid/features/campaigns/presentation/providers/campaigns_provider.dart';
import 'package:ilithid/features/characters/domain/character.dart';
import 'package:ilithid/features/characters/presentation/providers/characters_provider.dart';
import 'package:ilithid/features/sessions/presentation/providers/sessions_provider.dart';
import 'package:ilithid/features/sessions/presentation/providers/sessions_state.dart';
import 'package:ilithid/shared/components/app_button.dart';
import 'package:ilithid/shared/components/app_card.dart';
import 'package:ilithid/shared/theme/app_colors.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class CampaignDashboardScreen extends ConsumerStatefulWidget {
  final String hexId;

  const CampaignDashboardScreen({super.key, required this.hexId});

  @override
  ConsumerState<CampaignDashboardScreen> createState() =>
      _CampaignDashboardScreenState();
}

class _CampaignDashboardScreenState
    extends ConsumerState<CampaignDashboardScreen> {
  Future<CampaignMember?>? _membershipFuture;
  Campaign? _campaign;
  int _currentTab = 0; // 0 = Geral, 1 = Sessões

  @override
  void initState() {
    super.initState();
    _loadMembership();
  }

  void _loadMembership() {
    // Find campaign from cache first
    final campaignsState = ref.read(campaignsProvider);
    UserCampaign? userCamp;
    for (final uc in campaignsState.campaigns) {
      if (uc.campaign.hexId.toLowerCase() == widget.hexId.toLowerCase()) {
        userCamp = uc;
        break;
      }
    }

    if (userCamp != null) {
      _campaign = userCamp.campaign;
      _membershipFuture = ref
          .read(campaignsProvider.notifier)
          .checkMembership(userCamp.campaign.id);
    } else {
      // Fallback: search by hexId
      ref
          .read(campaignsProvider.notifier)
          .findCampaignByHexId(widget.hexId)
          .then((camp) {
            if (camp != null && mounted) {
              setState(() {
                _campaign = camp;
                _membershipFuture = ref
                    .read(campaignsProvider.notifier)
                    .checkMembership(camp.id);
              });
            }
          });
    }
  }

  void _showShareBottomSheet(BuildContext context) {
    const domain = String.fromEnvironment(
      'APP_DOMAIN',
      defaultValue: 'ilithid.tuxedorat.com',
    );
    final shareLink = 'https://$domain/join/${widget.hexId}';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Compartilhar Campanha',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Convide jogadores compartilhando o código, o link ou o QR Code abaixo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: shareLink,
                        version: QrVersions.auto,
                        size: 160.0,
                        gapless: false,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ShareActionButton(
                        key: const Key('copy_code_button'),
                        icon: Icons.code,
                        label: 'Copiar Código',
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: widget.hexId.toUpperCase()),
                          ).then((_) {
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Código copiado para a área de transferência!',
                                  ),
                                  backgroundColor: AppColors.heal,
                                ),
                              );
                            }
                          });
                        },
                      ),
                      _ShareActionButton(
                        key: const Key('copy_link_button'),
                        icon: Icons.link,
                        label: 'Copiar Link',
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: shareLink),
                          ).then((_) {
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Link copiado para a área de transferência!',
                                  ),
                                  backgroundColor: AppColors.heal,
                                ),
                              );
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    key: const Key('native_share_button'),
                    onPressed: () {
                      Navigator.pop(context);
                      SharePlus.instance.share(
                        ShareParams(
                          text:
                              'Junte-se à minha campanha no ilithid!\nLink: $shareLink\nCódigo: ${widget.hexId.toUpperCase()}',
                          subject: 'Código de Campanha ilithid',
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.share, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Compartilhar Link'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCharacterSwapSheet(
    BuildContext context,
    String campaignId,
    String? currentActiveId,
  ) {
    final charactersState = ref.read(charactersProvider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Trocar Ficha Ativa',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Selecione uma de suas fichas para jogar nesta campanha.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                if (charactersState.characters.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Text(
                      'Você não possui outras fichas criadas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ] else ...[
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: charactersState.characters.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final char = charactersState.characters[index];
                        final isCurrent = char.id == currentActiveId;

                        return InkWell(
                          onTap: isCurrent
                              ? null
                              : () async {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  Navigator.pop(context);
                                  final success = await ref
                                      .read(campaignsProvider.notifier)
                                      .updateActiveCharacter(
                                        campaignId: campaignId,
                                        activeCharacterId: char.id,
                                      );
                                  if (success && mounted) {
                                    setState(() {
                                      _loadMembership();
                                    });
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Ficha ativa alterada para "${char.name}"!',
                                        ),
                                        backgroundColor: AppColors.heal,
                                      ),
                                    );
                                  }
                                },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? AppColors.primary.withAlpha(26)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCurrent
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isCurrent
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: isCurrent
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        char.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isCurrent
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'HP: ${char.hpMax} | CA: ${char.ac}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
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
                  ),
                ],
                const SizedBox(height: 8),
                AppButton(
                  onPressed: () => Navigator.pop(context),
                  variant: AppButtonVariant.secondary,
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} às ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final campaignsState = ref.watch(campaignsProvider);
    if (_campaign != null) {
      for (final uc in campaignsState.campaigns) {
        if (uc.campaign.id == _campaign!.id) {
          _campaign = uc.campaign;
          break;
        }
      }
    }

    if (_campaign != null && _campaign!.status == 'finished') {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final router = GoRouter.of(context);
      Future.microtask(() {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Esta campanha foi finalizada pelo Mestre.'),
            backgroundColor: AppColors.primary,
          ),
        );
        router.go('/');
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_campaign == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final charactersState = ref.watch(charactersProvider);
    final sessionsState = ref.watch(sessionsProvider(_campaign!.id));
    final activeSession = sessionsState.activeSession;
    final isLoadingSession = sessionsState.status == SessionsStatus.loading;

    return Scaffold(
      appBar: AppBar(
        title: Text(_campaign!.name),
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
            child: FutureBuilder<CampaignMember?>(
              future: _membershipFuture,
              builder: (context, snapshot) {
                final isLoadingMember =
                    snapshot.connectionState == ConnectionState.waiting;
                final member = snapshot.data;
                final isGm = member?.role == 'gm';

                Character? activeChar;
                if (member?.activeCharacterId != null) {
                  try {
                    activeChar = charactersState.characters.firstWhere(
                      (c) => c.id == member!.activeCharacterId,
                    );
                  } catch (_) {}
                }

                return AppCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.dashboard_outlined,
                        size: 64,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _campaign!.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Role Badge
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isGm
                                ? AppColors.masterMagic.withAlpha(38)
                                : AppColors.primary.withAlpha(38),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isGm
                                  ? AppColors.masterMagic.withAlpha(77)
                                  : AppColors.primary.withAlpha(77),
                            ),
                          ),
                          child: Text(
                            isGm ? 'MESTRE' : 'JOGADOR',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isGm
                                  ? AppColors.masterMagic
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              key: const Key('tab_general'),
                              onTap: () => setState(() => _currentTab = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _currentTab == 0
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Geral',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: _currentTab == 0
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: _currentTab == 0
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              key: const Key('tab_sessions'),
                              onTap: () => setState(() => _currentTab = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _currentTab == 1
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Sessões',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: _currentTab == 1
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: _currentTab == 1
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      if (_currentTab == 0) ...[
                        // Code hex card
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'CÓDIGO DA CAMPANHA (HEX ID)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.hexId.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Player active character section
                        if (isLoadingMember) ...[
                          const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        ] else if (member != null && !isGm) ...[
                          const Divider(height: 32, color: AppColors.border),
                          const Text(
                            'SUA FICHA ATIVA',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (activeChar != null) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.shield_outlined,
                                    color: AppColors.primary,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          activeChar.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'HP Máx: ${activeChar.hpMax} | CA: ${activeChar.ac}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.damage.withAlpha(26),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.damage.withAlpha(77),
                                ),
                              ),
                              child: const Text(
                                'Nenhum personagem ativo selecionado.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.damage,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          AppButton(
                            key: const Key('change_active_char_button'),
                            onPressed: () => _showCharacterSwapSheet(
                              context,
                              _campaign!.id,
                              member.activeCharacterId,
                            ),
                            variant: AppButtonVariant.secondary,
                            child: Text(
                              activeChar != null
                                  ? 'Trocar Ficha Ativa'
                                  : 'Selecionar Ficha Ativa',
                            ),
                          ),
                        ],

                        // Active Session Section
                        const Divider(height: 32, color: AppColors.border),
                        if (isLoadingSession) ...[
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ] else ...[
                          if (activeSession != null) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.heal.withAlpha(26),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.heal.withAlpha(77),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.play_circle_fill_outlined,
                                        color: AppColors.heal,
                                        size: 28,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Sessão em Andamento!',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Iniciada em: ${_formatDate(activeSession.startedAt)}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  AppButton(
                                    key: const Key('enter_session_button'),
                                    onPressed: () {
                                      context.go(
                                        '/campaigns/${widget.hexId}/session/${activeSession.id}',
                                      );
                                    },
                                    child: const Text('Entrar na Sessão'),
                                  ),
                                  if (isGm) ...[
                                    const SizedBox(height: 12),
                                    AppButton(
                                      key: const Key('end_session_button'),
                                      variant: AppButtonVariant.danger,
                                      onPressed: () =>
                                          _showEndSessionConfirmation(
                                            context,
                                            activeSession.id,
                                          ),
                                      child: const Text('Encerrar Sessão'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ] else ...[
                            if (isGm) ...[
                              AppButton(
                                key: const Key('start_session_button'),
                                onPressed: () async {
                                  final notifier = ref.read(
                                    sessionsProvider(_campaign!.id).notifier,
                                  );
                                  final session = await notifier
                                      .createSession();
                                  if (session != null && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Sessão iniciada com sucesso!',
                                        ),
                                        backgroundColor: AppColors.heal,
                                      ),
                                    );
                                  }
                                },
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.play_arrow, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('Iniciar Sessão'),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: AppColors.textSecondary,
                                      size: 24,
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        'Nenhuma sessão ativa no momento. Aguarde o Mestre iniciar.',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ] else ...[
                        _buildSessionsTab(sessionsState, isGm),
                      ],
                      const Divider(height: 32, color: AppColors.border),
                      AppButton(
                        key: const Key('dashboard_share_button'),
                        onPressed: () => _showShareBottomSheet(context),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.share, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Compartilhar Campanha'),
                          ],
                        ),
                      ),
                      if (isGm) ...[
                        const SizedBox(height: 12),
                        AppButton(
                          key: const Key('end_campaign_button'),
                          variant: AppButtonVariant.danger,
                          onPressed: () =>
                              _showEndCampaignConfirmation(context),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.gavel, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Finalizar Campanha'),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      AppButton(
                        onPressed: () => context.go('/'),
                        variant: AppButtonVariant.secondary,
                        child: const Text('Voltar para Home'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionsTab(SessionsState sessionsState, bool isGm) {
    if (sessionsState.status == SessionsStatus.loading &&
        sessionsState.sessions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final sessions = sessionsState.sessions;
    if (sessions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          children: [
            Icon(Icons.history, color: AppColors.textMuted, size: 48),
            SizedBox(height: 12),
            Text(
              'Nenhuma sessão registrada nesta campanha.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'HISTÓRICO DE SESSÕES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        ...sessions.map((session) {
          final isActive = session.status == 'active';
          return Container(
            key: Key('session_card_${session.id}'),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.heal.withAlpha(26)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? AppColors.heal.withAlpha(128)
                    : AppColors.border,
                width: isActive ? 2 : 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.heal.withAlpha(38),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  isActive
                      ? Icons.play_circle_fill_outlined
                      : Icons.check_circle_outline,
                  color: isActive ? AppColors.heal : AppColors.textMuted,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isActive ? 'Sessão Ativa' : 'Sessão Finalizada',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isActive
                                  ? AppColors.heal
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.heal.withAlpha(38)
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isActive ? 'ATIVA' : 'CONCLUÍDA',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? AppColors.heal
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Início: ${_formatDate(session.startedAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (session.endedAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Fim: ${_formatDate(session.endedAt!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showEndSessionConfirmation(BuildContext context, String sessionId) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Encerrar Sessão'),
          content: const Text(
            'Tem certeza que deseja encerrar a sessão ativa? Esta ação é irreversível.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            AppButton(
              key: const Key('confirm_end_session_button'),
              onPressed: () async {
                Navigator.pop(dialogContext);
                final notifier = ref.read(
                  sessionsProvider(_campaign!.id).notifier,
                );
                final success = await notifier.endSession(sessionId);
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sessão encerrada com sucesso!'),
                      backgroundColor: AppColors.heal,
                    ),
                  );
                }
              },
              variant: AppButtonVariant.danger,
              child: const Text('Encerrar'),
            ),
          ],
        );
      },
    );
  }

  void _showEndCampaignConfirmation(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Finalizar Campanha'),
          content: const Text(
            'Tem certeza que deseja finalizar esta campanha? Isso impedirá novos logins e sessões.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            AppButton(
              key: const Key('confirm_end_campaign_first_button'),
              onPressed: () {
                Navigator.pop(dialogContext);
                _showEndCampaignSecondConfirmation(context);
              },
              variant: AppButtonVariant.danger,
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  void _showEndCampaignSecondConfirmation(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('AVISO: Ação Irreversível'),
          content: const Text(
            'Esta ação é permanente e não poderá ser desfeita. Deseja mesmo finalizar a campanha?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            AppButton(
              key: const Key('confirm_end_campaign_second_button'),
              onPressed: () async {
                Navigator.pop(dialogContext);
                final notifier = ref.read(campaignsProvider.notifier);
                final success = await notifier.endCampaign(_campaign!.id);
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Campanha finalizada com sucesso!'),
                      backgroundColor: AppColors.heal,
                    ),
                  );
                  context.go('/');
                }
              },
              variant: AppButtonVariant.danger,
              child: const Text('Finalizar Permanentemente'),
            ),
          ],
        );
      },
    );
  }
}

class _ShareActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShareActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
