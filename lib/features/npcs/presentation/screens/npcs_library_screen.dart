// NPC library screen (Story 6.2): "Comunidade" (public templates) and "Meus
// NPCs" (own templates) tabs, with client-side name search.
// Depends on: npcTemplatesProvider.
// Decision: search filters the already-fetched lists in memory instead of
// re-querying Appwrite per keystroke, since Query.search requires a fulltext
// index not currently set up for the npc_templates collection.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilithid/features/npcs/domain/npc_template.dart';
import 'package:ilithid/features/npcs/presentation/providers/npc_templates_provider.dart';
import 'package:ilithid/features/npcs/presentation/providers/npc_templates_state.dart';
import 'package:ilithid/shared/components/app_card.dart';
import 'package:ilithid/shared/components/app_text_field.dart';
import 'package:ilithid/shared/components/foundry_import_dialog.dart';
import 'package:ilithid/shared/theme/app_colors.dart';

class NpcsLibraryScreen extends ConsumerStatefulWidget {
  const NpcsLibraryScreen({super.key});

  @override
  ConsumerState<NpcsLibraryScreen> createState() => _NpcsLibraryScreenState();
}

class _NpcsLibraryScreenState extends ConsumerState<NpcsLibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showImportDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return FoundryImportDialog(
          title: 'Importar NPC do Foundry',
          onConfirm: (parsed, rawJson) async {
            final template = await ref
                .read(npcTemplatesProvider.notifier)
                .createNpcTemplate(
                  parsed.name,
                  parsed.hpMax,
                  parsed.ac,
                  sourceSystem: 'dnd5e',
                  isPublic: true,
                );
            return template != null;
          },
        );
      },
    );
  }

  List<NpcTemplate> _filterByName(List<NpcTemplate> templates) {
    if (_searchQuery.isEmpty) return templates;
    final query = _searchQuery.toLowerCase();
    return templates
        .where((template) => template.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(npcTemplatesProvider);
    final notifier = ref.read(npcTemplatesProvider.notifier);

    final filteredPublic = _filterByName(state.publicTemplates);
    final filteredMine = _filterByName(state.myTemplates);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca de NPCs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            key: const Key('import_foundry_npc_button'),
            icon: const Icon(Icons.upload_file),
            tooltip: 'Importar do Foundry',
            onPressed: () => _showImportDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(key: Key('npcs_tab_community'), text: 'Comunidade'),
            Tab(key: Key('npcs_tab_mine'), text: 'Meus NPCs'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_npc_template_fab'),
        backgroundColor: AppColors.primary,
        onPressed: () => context.go('/npcs/new'),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Novo NPC', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: AppTextField(
              key: const Key('npc_search_field'),
              controller: _searchController,
              labelText: 'Buscar por nome',
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.damage.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.damage.withAlpha(77)),
                ),
                child: Text(
                  state.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.damage),
                ),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _NpcTemplatesList(
                  key: const Key('npcs_community_list'),
                  templates: filteredPublic,
                  isLoading:
                      state.status == NpcTemplatesStatus.loading &&
                      state.publicTemplates.isEmpty,
                  creatorNames: state.creatorNames,
                  onRefresh: notifier.fetchPublicTemplates,
                  emptyMessage:
                      'Crie templates de NPCs para utilizá-los rapidamente em combate.',
                ),
                _NpcTemplatesList(
                  key: const Key('npcs_mine_list'),
                  templates: filteredMine,
                  isLoading:
                      state.status == NpcTemplatesStatus.loading &&
                      state.myTemplates.isEmpty,
                  creatorNames: state.creatorNames,
                  onRefresh: notifier.fetchMyTemplates,
                  emptyMessage: 'Você ainda não criou nenhum NPC.',
                  showCreator: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NpcTemplatesList extends StatelessWidget {
  const _NpcTemplatesList({
    super.key,
    required this.templates,
    required this.isLoading,
    required this.creatorNames,
    required this.onRefresh,
    required this.emptyMessage,
    this.showCreator = true,
  });

  final List<NpcTemplate> templates;
  final bool isLoading;
  final Map<String, String> creatorNames;
  final Future<void> Function() onRefresh;
  final String emptyMessage;
  final bool showCreator;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: onRefresh,
      child: templates.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              children: [
                const SizedBox(height: 60),
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
                          'Nenhum NPC encontrado',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          emptyMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              itemCount: templates.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final template = templates[index];
                final creatorName =
                    creatorNames[template.creatorId] ?? template.creatorId;

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
                          Icons.gavel,
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
                              template.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'HP Máx: ${template.hpMax} | CA: ${template.ac}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (showCreator) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Criado por: $creatorName',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          template.sourceSystem.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
