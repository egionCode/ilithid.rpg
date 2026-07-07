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
      Future.microtask(() => fetchNpcTemplates());
    } else {
      return NpcTemplatesState.initial();
    }

    return NpcTemplatesState.initial();
  }

  Future<void> fetchNpcTemplates() async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) {
      state = NpcTemplatesState.error(
        'User must be logged in to fetch NPC templates.',
      );
      return;
    }

    state = NpcTemplatesState.loading(currentTemplates: state.templates);

    try {
      final response = await _tablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteNpcTemplatesTableId,
        queries: [Query.equal('isPublic', true)],
      );

      final templates = response.rows
          .map((row) => NpcTemplate.fromRow(row))
          .toList();
      state = NpcTemplatesState.success(templates);
    } catch (e) {
      state = NpcTemplatesState.error(
        e.toString(),
        currentTemplates: state.templates,
      );
    }
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

    state = NpcTemplatesState.loading(currentTemplates: state.templates);

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

      final updatedList = List<NpcTemplate>.from(state.templates)
        ..add(newTemplate);
      state = NpcTemplatesState.success(updatedList);

      return newTemplate;
    } catch (e) {
      state = NpcTemplatesState.error(
        e.toString(),
        currentTemplates: state.templates,
      );
      return null;
    }
  }
}
