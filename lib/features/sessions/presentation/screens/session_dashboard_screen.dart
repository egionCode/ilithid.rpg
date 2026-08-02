import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilithid/features/campaigns/domain/campaign.dart';
import 'package:ilithid/features/campaigns/domain/campaign_member.dart';
import 'package:ilithid/features/campaigns/domain/user_campaign.dart';
import 'package:ilithid/features/campaigns/presentation/providers/campaigns_provider.dart';
import 'package:ilithid/features/characters/domain/character.dart';
import 'package:ilithid/features/characters/presentation/providers/characters_provider.dart';
import 'package:ilithid/features/combat/domain/combat_target.dart';
import 'package:ilithid/features/combat/presentation/providers/logs_provider.dart';
import 'package:ilithid/features/combat/presentation/providers/party_provider.dart';
import 'package:ilithid/features/combat/presentation/providers/party_state.dart';
import 'package:ilithid/features/combat/presentation/widgets/combat_action_dialog.dart';
import 'package:ilithid/features/combat/presentation/widgets/custom_log_dialog.dart';
import 'package:ilithid/features/combat/presentation/widgets/log_feed.dart';
import 'package:ilithid/features/npcs/domain/npc_instance.dart';
import 'package:ilithid/features/npcs/domain/npc_template.dart';
import 'package:ilithid/features/npcs/domain/npc_visual_state.dart';
import 'package:ilithid/features/npcs/presentation/providers/npc_instances_provider.dart';
import 'package:ilithid/features/npcs/presentation/providers/npc_instances_state.dart';
import 'package:ilithid/features/npcs/presentation/providers/npc_templates_provider.dart';
import 'package:ilithid/features/npcs/presentation/providers/npc_templates_state.dart';
import 'package:ilithid/features/sessions/domain/session.dart';
import 'package:ilithid/features/sessions/presentation/providers/sessions_provider.dart';
import 'package:ilithid/features/sessions/presentation/providers/sessions_state.dart';
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
    final partyState = ref.watch(partyProvider(_campaign!.id));
    final sessionsState = ref.watch(sessionsProvider(_campaign!.id));

    final currentSession = sessionsState.sessions.cast<Session?>().firstWhere(
      (s) => s?.id == widget.sessionId,
      orElse: () => sessionsState.activeSession,
    );
    final showNpcHp = currentSession?.showNpcHp ?? false;

    final charactersState = ref.watch(charactersProvider);
    final activeCharacterId = _member?.activeCharacterId;
    final myCharacter = activeCharacterId == null
        ? null
        : charactersState.characters.cast<Character?>().firstWhere(
            (c) => c?.id == activeCharacterId,
            orElse: () => null,
          );

    final companions = partyState.members
        .where((m) => m.character != null && m.character!.id != myCharacter?.id)
        .toList();

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
      floatingActionButton: ResponsiveBuilder(
        builder: (context, deviceType) {
          if (!isGm || deviceType != DeviceType.mobile) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton(
            key: const Key('session_add_npc_fab'),
            backgroundColor: AppColors.primary,
            tooltip: 'Adicionar NPC',
            onPressed: () => _showAddNpcDialog(context),
            child: const Icon(Icons.add, color: Colors.white),
          );
        },
      ),
      body: ResponsiveBuilder(
        builder: (context, deviceType) {
          if (deviceType == DeviceType.mobile) {
            return _buildMobileBody(
              isGm: isGm,
              showNpcHp: showNpcHp,
              myCharacter: myCharacter,
              companions: companions,
              partyState: partyState,
              npcInstancesState: npcInstancesState,
            );
          }
          return _buildDesktopBody(
            isGm: isGm,
            showNpcHp: showNpcHp,
            myCharacter: myCharacter,
            companions: companions,
            partyState: partyState,
            npcInstancesState: npcInstancesState,
            sessionsState: sessionsState,
          );
        },
      ),
    );
  }

  /// Pull-to-refresh fallback (Story 11.1) - re-fetches every provider this
  /// screen shows, since Realtime already keeps them live but a manual
  /// refresh is a reasonable "did I miss something" escape hatch.
  Future<void> _refreshAll() async {
    await Future.wait([
      ref
          .read(npcInstancesProvider(widget.sessionId).notifier)
          .fetchNpcInstances(),
      ref.read(partyProvider(_campaign!.id).notifier).fetchParty(),
      ref.read(sessionsProvider(_campaign!.id).notifier).checkActiveSession(),
      ref.read(logsProvider(widget.sessionId).notifier).fetchLogs(),
      ref.read(charactersProvider.notifier).fetchCharacters(),
    ]);
  }

  Widget _sessionInfoCard() {
    return AppCard(
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
    );
  }

  Widget _sectionHeading(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _myCharacterBody(Character character) {
    return _MyCharacterCard(character: character, sessionId: widget.sessionId);
  }

  Widget _groupBody(List<PartyMember> companions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: companions
          .map(
            (partyMember) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CompanionCard(character: partyMember.character!),
            ),
          )
          .toList(),
    );
  }

  Widget _playersBody(PartyState partyState) {
    final withCharacter = partyState.members
        .where((m) => m.character != null)
        .toList();

    if (partyState.status == PartyStatus.loading &&
        partyState.members.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (withCharacter.isEmpty) {
      return const AppCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Nenhum jogador com ficha ativa nesta campanha.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: withCharacter
          .map(
            (partyMember) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PartyMemberCard(
                partyMember: partyMember,
                sessionId: widget.sessionId,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _npcsBody(
    NpcInstancesState npcInstancesState,
    bool isGm,
    bool showNpcHp, {
    int crossAxisCount = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isGm) ...[
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              onPressed: () => _showAddNpcDialog(context),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Adicionar NPC',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SwitchListTile(
            key: const Key('toggle_show_npc_hp'),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Mostrar HP exato dos NPCs para os jogadores',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            value: showNpcHp,
            activeThumbColor: AppColors.primary,
            onChanged: (value) => ref
                .read(sessionsProvider(_campaign!.id).notifier)
                .setShowNpcHp(widget.sessionId, value),
          ),
          const SizedBox(height: 8),
        ],
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
          )
        else if (npcInstancesState.npcInstances.isEmpty)
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
          GridView.builder(
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
                showNpcHp: showNpcHp,
                sessionId: widget.sessionId,
              );
            },
          ),
      ],
    );
  }

  Widget _logBody(bool isGm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isGm)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('add_custom_log_button'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) =>
                    CustomLogDialog(sessionId: widget.sessionId),
              ),
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('Adicionar Nota'),
            ),
          ),
        SizedBox(height: 320, child: LogFeed(sessionId: widget.sessionId)),
      ],
    );
  }

  /// Mobile GM/Player dashboard (Stories 11.1/11.3): a linear column of
  /// collapsible sections, pull-to-refresh as a fallback to Realtime, and
  /// a FAB (declared in [build]) for the GM to add an NPC.
  Widget _buildMobileBody({
    required bool isGm,
    required bool showNpcHp,
    required Character? myCharacter,
    required List<PartyMember> companions,
    required PartyState partyState,
    required NpcInstancesState npcInstancesState,
  }) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _refreshAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sessionInfoCard(),
            const SizedBox(height: 24),
            if (myCharacter != null) ...[
              _sectionHeading('Minha Ficha'),
              const SizedBox(height: 16),
              _myCharacterBody(myCharacter),
              const SizedBox(height: 24),
            ],
            if (!isGm && companions.isNotEmpty)
              _CollapsibleSection(
                title: 'Grupo',
                child: _groupBody(companions),
              ),
            if (isGm)
              _CollapsibleSection(
                title: 'Jogadores',
                child: _playersBody(partyState),
              ),
            _CollapsibleSection(
              title: 'NPCs em Combate',
              child: _npcsBody(npcInstancesState, isGm, showNpcHp),
            ),
            _CollapsibleSection(
              title: 'Log de Combate',
              initiallyExpanded: false,
              child: _logBody(isGm),
            ),
          ],
        ),
      ),
    );
  }

  /// Desktop GM/Player dashboard (Stories 11.2/11.4): a sessions sidebar
  /// plus a 3-column layout (Jogadores/Minha Ficha+Grupo | NPCs | Log),
  /// each column independently scrollable.
  Widget _buildDesktopBody({
    required bool isGm,
    required bool showNpcHp,
    required Character? myCharacter,
    required List<PartyMember> companions,
    required PartyState partyState,
    required NpcInstancesState npcInstancesState,
    required SessionsState sessionsState,
  }) {
    // Note: these columns intentionally do NOT get their own
    // SingleChildScrollView - the whole page already scrolls via the
    // SingleChildScrollView below, and nesting an unbounded-height
    // scrollable inside another (previously also wrapped in
    // IntrinsicHeight) collapsed every column to zero height on web.
    Widget column(String title, Widget body, {Widget? headingTrailing}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (headingTrailing == null)
                _sectionHeading(title)
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [_sectionHeading(title), headingTrailing],
                ),
              const SizedBox(height: 16),
              body,
            ],
          ),
        ),
      );
    }

    final leftColumn = isGm
        ? column('Jogadores', _playersBody(partyState))
        : column(
            'Minha Ficha',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (myCharacter != null) _myCharacterBody(myCharacter),
                if (companions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _sectionHeading('Grupo'),
                  const SizedBox(height: 16),
                  _groupBody(companions),
                ],
              ],
            ),
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SessionsSidebar(
          sessions: sessionsState.sessions,
          currentSessionId: widget.sessionId,
          hexId: widget.hexId,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sessionInfoCard(),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leftColumn,
                    column(
                      'NPCs em Combate',
                      _npcsBody(
                        npcInstancesState,
                        isGm,
                        showNpcHp,
                        crossAxisCount: 2,
                      ),
                    ),
                    column('Log de Combate', _logBody(isGm)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Sessions sidebar for the desktop layout (Story 11.2): lists the
/// campaign's sessions so the GM can jump between them without going back
/// to the campaign dashboard.
class _SessionsSidebar extends StatelessWidget {
  final List<Session> sessions;
  final String currentSessionId;
  final String hexId;

  const _SessionsSidebar({
    required this.sessions,
    required this.currentSessionId,
    required this.hexId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'SESSÕES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                final isCurrent = session.id == currentSessionId;
                return Tooltip(
                  message: session.status == 'active'
                      ? 'Sessão ativa'
                      : 'Sessão encerrada',
                  child: ListTile(
                    dense: true,
                    selected: isCurrent,
                    selectedTileColor: AppColors.primary.withAlpha(26),
                    leading: Icon(
                      session.status == 'active'
                          ? Icons.play_circle_fill_outlined
                          : Icons.check_circle_outline,
                      size: 18,
                      color: session.status == 'active'
                          ? AppColors.heal
                          : AppColors.textMuted,
                    ),
                    title: Text(
                      session.startedAt.toLocal().toString().split('.').first,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: session.status == 'active' && !isCurrent
                        ? () => context.go(
                            '/campaigns/$hexId/session/${session.id}',
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
          const Divider(color: AppColors.border),
          ListTile(
            dense: true,
            leading: const Icon(
              Icons.arrow_back,
              size: 18,
              color: AppColors.textSecondary,
            ),
            title: const Text(
              'Voltar à campanha',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            onTap: () => context.go('/campaigns/$hexId'),
          ),
        ],
      ),
    );
  }
}

/// Collapsible section wrapper for the mobile layout (Story 11.1).
class _CollapsibleSection extends StatelessWidget {
  final String title;
  final Widget child;
  final bool initiallyExpanded;

  const _CollapsibleSection({
    required this.title,
    required this.child,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          // ExpansionTile's ListTile paints ink/background on the nearest
          // Material ancestor; without this, they'd render invisibly
          // behind the surrounding decorated Container's own background.
          color: Colors.transparent,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey<String>(title),
              initiallyExpanded: initiallyExpanded,
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [child],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanionCard extends StatelessWidget {
  final Character character;

  const _CompanionCard({required this.character});

  @override
  Widget build(BuildContext context) {
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
              color: AppColors.heal.withAlpha(26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person, color: AppColors.heal, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
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
                const SizedBox(height: 8),
                HpBar(
                  currentHp: character.hpCurrent,
                  maxHp: character.hpMax,
                  tempHp: character.hpTemp,
                  height: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NpcVisualStateBadge extends StatelessWidget {
  final NpcVisualState state;

  const _NpcVisualStateBadge({required this.state});

  Color get _color {
    switch (state) {
      case NpcVisualState.healthy:
        return AppColors.heal;
      case NpcVisualState.wounded:
        return AppColors.tempHp;
      case NpcVisualState.nearDeath:
        return AppColors.damage;
      case NpcVisualState.dead:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withAlpha(38),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withAlpha(102)),
      ),
      child: Text(
        state.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: _color,
        ),
      ),
    );
  }
}

class _MyCharacterCard extends StatelessWidget {
  final Character character;
  final String sessionId;

  const _MyCharacterCard({required this.character, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(76)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  character.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'CA ${character.ac}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          HpBar(
            currentHp: character.hpCurrent,
            maxHp: character.hpMax,
            tempHp: character.hpTemp,
            height: 20,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              key: Key('my_character_combat_action_${character.id}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () => showCombatAction(
                context,
                sessionId: sessionId,
                target: CombatTarget(
                  kind: CombatTargetKind.character,
                  id: character.id,
                  name: character.name,
                  hpCurrent: character.hpCurrent,
                  hpMax: character.hpMax,
                  hpTemp: character.hpTemp,
                ),
              ),
              icon: const Icon(Icons.flash_on, size: 18),
              label: const Text('Aplicar Dano/Cura'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartyMemberCard extends StatelessWidget {
  final PartyMember partyMember;
  final String sessionId;

  const _PartyMemberCard({required this.partyMember, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final character = partyMember.character!;
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
              color: AppColors.heal.withAlpha(26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person, color: AppColors.heal, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
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
                const SizedBox(height: 8),
                HpBar(
                  currentHp: character.hpCurrent,
                  maxHp: character.hpMax,
                  tempHp: character.hpTemp,
                  height: 16,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            key: Key('party_combat_action_${character.id}'),
            icon: const Icon(
              Icons.flash_on,
              color: AppColors.primary,
              size: 22,
            ),
            tooltip: 'Ações de combate',
            onPressed: () => showCombatAction(
              context,
              sessionId: sessionId,
              target: CombatTarget(
                kind: CombatTargetKind.character,
                id: character.id,
                name: character.name,
                hpCurrent: character.hpCurrent,
                hpMax: character.hpMax,
                hpTemp: character.hpTemp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NpcInstanceCard extends ConsumerWidget {
  final NpcInstance instance;
  final bool isGm;
  final bool showNpcHp;
  final String sessionId;

  const _NpcInstanceCard({
    required this.instance,
    required this.isGm,
    required this.showNpcHp,
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
                if (isGm || showNpcHp)
                  HpBar(
                    currentHp: instance.hpCurrent,
                    maxHp: instance.hpMax,
                    tempHp: instance.hpTemp,
                    height: 16,
                  )
                else
                  _NpcVisualStateBadge(
                    state: NpcVisualState.fromHp(
                      instance.hpCurrent,
                      instance.hpMax,
                    ),
                  ),
              ],
            ),
          ),
          if (isGm) ...[
            const SizedBox(width: 12),
            IconButton(
              key: Key('npc_combat_action_${instance.id}'),
              icon: const Icon(
                Icons.flash_on,
                color: AppColors.primary,
                size: 22,
              ),
              tooltip: 'Ações de combate',
              onPressed: () => showCombatAction(
                context,
                sessionId: sessionId,
                target: CombatTarget(
                  kind: CombatTargetKind.npcInstance,
                  id: instance.id,
                  name: instance.name,
                  hpCurrent: instance.hpCurrent,
                  hpMax: instance.hpMax,
                  hpTemp: instance.hpTemp,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.favorite_outline,
                color: AppColors.heal,
                size: 22,
              ),
              onPressed: () => _showAdjustHpDialog(context, ref),
              tooltip: 'Ajustar HP (valor absoluto)',
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
