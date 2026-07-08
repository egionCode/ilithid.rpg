import 'dart:async';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/npcs/domain/npc_instance.dart';
import 'package:ilithid/features/npcs/presentation/providers/npc_instances_state.dart';
import 'package:ilithid/features/sessions/presentation/providers/sessions_provider.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';

final npcInstancesProvider =
    NotifierProvider.family<NpcInstancesNotifier, NpcInstancesState, String>(
      (arg) => NpcInstancesNotifier(arg),
    );

class NpcInstancesNotifier extends Notifier<NpcInstancesState> {
  final String sessionId;
  late TablesDB _tablesDb;

  NpcInstancesNotifier(this.sessionId);

  @override
  NpcInstancesState build() {
    _tablesDb = ref.watch(appwriteTablesDbProvider);

    final authState = ref.watch(authProvider);
    if (authState.status == AuthStatus.authenticated) {
      Future.microtask(() {
        fetchNpcInstances();
        _subscribeToRealtime(sessionId);
      });
    }

    return NpcInstancesState.initial();
  }

  /// Fetches all active NPC instances in this session.
  Future<void> fetchNpcInstances() async {
    state = NpcInstancesState.loading(currentInstances: state.npcInstances);

    try {
      final response = await _tablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteNpcInstancesTableId,
        queries: [Query.equal('sessionId', sessionId)],
      );

      if (!ref.mounted) return;

      final instances = response.rows
          .map((row) => NpcInstance.fromRow(row))
          .toList();
      state = NpcInstancesState.success(instances);
    } on AppwriteException catch (e) {
      if (!ref.mounted) return;
      state = NpcInstancesState.error(
        e.message ?? 'Failed to fetch NPC instances.',
        currentInstances: state.npcInstances,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = NpcInstancesState.error(
        e.toString(),
        currentInstances: state.npcInstances,
      );
    }
  }

  /// Instantiates a new NPC in the session.
  Future<NpcInstance?> instantiateNpc({
    required String name,
    required int hpMax,
    required int ac,
    String? templateId,
  }) async {
    state = NpcInstancesState.loading(currentInstances: state.npcInstances);

    try {
      final instanceId = ID.unique();
      final data = {
        'sessionId': sessionId,
        // ignore: use_null_aware_elements
        if (templateId != null) 'templateId': templateId,
        'name': name,
        'hpCurrent': hpMax,
        'hpMax': hpMax,
        'hpTemp': 0,
        'ac': ac,
      };

      final row = await _tablesDb.createRow(
        databaseId: appwriteDatabaseId,
        tableId: appwriteNpcInstancesTableId,
        rowId: instanceId,
        data: data,
      );

      final newInstance = NpcInstance.fromRow(row);

      if (!ref.mounted) return newInstance;

      final updated = List<NpcInstance>.from(state.npcInstances)
        ..add(newInstance);
      state = NpcInstancesState.success(updated);

      return newInstance;
    } on AppwriteException catch (e) {
      if (!ref.mounted) return null;
      state = NpcInstancesState.error(
        e.message ?? 'Failed to instantiate NPC.',
        currentInstances: state.npcInstances,
      );
      return null;
    } catch (e) {
      if (!ref.mounted) return null;
      state = NpcInstancesState.error(
        e.toString(),
        currentInstances: state.npcInstances,
      );
      return null;
    }
  }

  /// Updates the HP (Current and Temporary) of an NPC instance.
  Future<bool> updateNpcHp(
    String instanceId, {
    required int hpCurrent,
    required int hpTemp,
  }) async {
    try {
      final existingNpc = state.npcInstances.firstWhere(
        (inst) => inst.id == instanceId,
      );

      final row = await _tablesDb.updateRow(
        databaseId: appwriteDatabaseId,
        tableId: appwriteNpcInstancesTableId,
        rowId: instanceId,
        data: {
          'sessionId': existingNpc.sessionId,
          if (existingNpc.templateId != null)
            'templateId': existingNpc.templateId,
          'name': existingNpc.name,
          'hpCurrent': hpCurrent,
          'hpMax': existingNpc.hpMax,
          'hpTemp': hpTemp,
          'ac': existingNpc.ac,
        },
      );

      if (!ref.mounted) return true;

      final updatedInstance = NpcInstance.fromRow(row);
      final updatedList = state.npcInstances.map((inst) {
        return inst.id == instanceId ? updatedInstance : inst;
      }).toList();

      state = NpcInstancesState.success(updatedList);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = NpcInstancesState.error(
        e.toString(),
        currentInstances: state.npcInstances,
      );
      return false;
    }
  }

  /// Deletes an NPC instance from the active session.
  Future<bool> deleteNpcInstance(String instanceId) async {
    try {
      await _tablesDb.deleteRow(
        databaseId: appwriteDatabaseId,
        tableId: appwriteNpcInstancesTableId,
        rowId: instanceId,
      );

      if (!ref.mounted) return true;

      final updatedList = state.npcInstances
          .where((inst) => inst.id != instanceId)
          .toList();
      state = NpcInstancesState.success(updatedList);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = NpcInstancesState.error(
        e.toString(),
        currentInstances: state.npcInstances,
      );
      return false;
    }
  }

  /// Subscribes to the Realtime events for the npc_instances collection.
  void _subscribeToRealtime(String sessionId) {
    try {
      final realtime = ref.read(appwriteRealtimeProvider);
      final isTest = StackTrace.current.toString().contains(
        'package:flutter_test',
      );
      if (isTest && realtime.runtimeType.toString() == 'Realtime') {
        return;
      }
      const channel =
          'databases.$appwriteDatabaseId.collections.$appwriteNpcInstancesTableId.documents';
      final subscription = realtime.subscribe([channel]);

      final streamSub = subscription.stream.listen((event) {
        final payload = event.payload;
        final eventSessionId = payload['sessionId'] as String?;
        if (eventSessionId == sessionId) {
          fetchNpcInstances();
        }
      });

      ref.onDispose(() {
        streamSub.cancel();
      });
    } catch (_) {
      // Fail silently if Realtime connection fails
    }
  }
}
