// Riverpod notifier for the NPC template library (Story 6.2).
// Depends on: Appwrite TablesDB (npc_templates + profiles tables), authProvider.
// Decision: public and "my" templates are fetched and kept as two separate
// lists (instead of one list filtered client-side) so each tab can be
// refreshed independently without refetching the other.
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/npcs/domain/npc_template.dart';
import 'package:ilithid/features/npcs/presentation/providers/npc_templates_state.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';

final npcTemplatesProvider =
    NotifierProvider<NpcTemplatesNotifier, NpcTemplatesState>(
      () => NpcTemplatesNotifier(),
    );

class NpcTemplatesNotifier extends Notifier<NpcTemplatesState> {
  late TablesDB _tablesDb;

  @override
  NpcTemplatesState build() {
    _tablesDb = ref.watch(appwriteTablesDbProvider);

    final authState = ref.watch(authProvider);
    if (authState.status == AuthStatus.authenticated) {
      Future.microtask(() {
        fetchPublicTemplates();
        fetchMyTemplates();
      });
    }

    return NpcTemplatesState.initial();
  }

  Future<void> fetchPublicTemplates() async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) {
      state = NpcTemplatesState.error(
        'User must be logged in to fetch NPC templates.',
      );
      return;
    }

    state = NpcTemplatesState.loading(
      currentPublicTemplates: state.publicTemplates,
      currentMyTemplates: state.myTemplates,
      currentCreatorNames: state.creatorNames,
    );

    try {
      final response = await _tablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteNpcTemplatesTableId,
        queries: [Query.equal('isPublic', true)],
      );

      final templates = response.rows
          .map((row) => NpcTemplate.fromRow(row))
          .toList();
      final resolvedNames = await _resolveCreatorNames(templates);
      if (!ref.mounted) return;

      state = NpcTemplatesState.success(
        publicTemplates: templates,
        myTemplates: state.myTemplates,
        creatorNames: {...state.creatorNames, ...resolvedNames},
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = NpcTemplatesState.error(
        e.toString(),
        currentPublicTemplates: state.publicTemplates,
        currentMyTemplates: state.myTemplates,
        currentCreatorNames: state.creatorNames,
      );
    }
  }

  Future<void> fetchMyTemplates() async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) {
      state = NpcTemplatesState.error(
        'User must be logged in to fetch NPC templates.',
      );
      return;
    }

    state = NpcTemplatesState.loading(
      currentPublicTemplates: state.publicTemplates,
      currentMyTemplates: state.myTemplates,
      currentCreatorNames: state.creatorNames,
    );

    try {
      final response = await _tablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteNpcTemplatesTableId,
        queries: [Query.equal('creatorId', user.$id)],
      );

      final templates = response.rows
          .map((row) => NpcTemplate.fromRow(row))
          .toList();
      if (!ref.mounted) return;

      state = NpcTemplatesState.success(
        publicTemplates: state.publicTemplates,
        myTemplates: templates,
        creatorNames: state.creatorNames,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = NpcTemplatesState.error(
        e.toString(),
        currentPublicTemplates: state.publicTemplates,
        currentMyTemplates: state.myTemplates,
        currentCreatorNames: state.creatorNames,
      );
    }
  }

  // Appwrite has no join support, and profile rows are keyed by userId, so
  // each unknown creator requires its own lookup (skipped on failure, e.g.
  // a deleted account, falling back to showing the raw id).
  Future<Map<String, String>> _resolveCreatorNames(
    List<NpcTemplate> templates,
  ) async {
    final Map<String, String> resolved = {};
    final unresolvedIds = templates
        .map((t) => t.creatorId)
        .toSet()
        .where((id) => !state.creatorNames.containsKey(id));

    for (final creatorId in unresolvedIds) {
      try {
        final profile = await _tablesDb.getRow(
          databaseId: appwriteDatabaseId,
          tableId: appwriteProfilesTableId,
          rowId: creatorId,
        );
        resolved[creatorId] =
            (profile.data['displayName'] as String?) ?? creatorId;
      } catch (_) {
        resolved[creatorId] = creatorId;
      }
    }

    return resolved;
  }

  Future<NpcTemplate?> createNpcTemplate(
    String name,
    int hpMax,
    int ac, {
    String sourceSystem = 'manual',
    bool isPublic = true,
  }) async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) {
      state = NpcTemplatesState.error(
        'User must be logged in to create NPC templates.',
      );
      return null;
    }

    state = NpcTemplatesState.loading(
      currentPublicTemplates: state.publicTemplates,
      currentMyTemplates: state.myTemplates,
      currentCreatorNames: state.creatorNames,
    );

    try {
      final templateId = ID.unique();
      final now = DateTime.now();

      final templateData = {
        'creatorId': user.$id,
        'name': name,
        'hpMax': hpMax,
        'ac': ac,
        'sourceSystem': sourceSystem,
        'isPublic': isPublic,
        'createdAt': now.toIso8601String(),
      };

      final row = await _tablesDb.createRow(
        databaseId: appwriteDatabaseId,
        tableId: appwriteNpcTemplatesTableId,
        rowId: templateId,
        data: templateData,
      );

      final newTemplate = NpcTemplate.fromRow(row);
      if (!ref.mounted) return newTemplate;

      final updatedMine = List<NpcTemplate>.from(state.myTemplates)
        ..add(newTemplate);
      final updatedPublic = isPublic
          ? (List<NpcTemplate>.from(state.publicTemplates)..add(newTemplate))
          : state.publicTemplates;

      state = NpcTemplatesState.success(
        publicTemplates: updatedPublic,
        myTemplates: updatedMine,
        creatorNames: {
          ...state.creatorNames,
          user.$id: authState.displayName ?? user.name,
        },
      );

      return newTemplate;
    } catch (e) {
      if (!ref.mounted) return null;
      state = NpcTemplatesState.error(
        e.toString(),
        currentPublicTemplates: state.publicTemplates,
        currentMyTemplates: state.myTemplates,
        currentCreatorNames: state.creatorNames,
      );
      return null;
    }
  }
}
