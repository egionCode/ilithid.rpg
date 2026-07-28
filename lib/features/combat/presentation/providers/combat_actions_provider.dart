import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/combat/domain/combat_math.dart';
import 'package:ilithid/features/combat/domain/combat_target.dart';
import 'package:ilithid/features/combat/domain/log_entry.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';

final combatActionsProvider = Provider<CombatActionsService>((ref) {
  return CombatActionsService(ref.watch(appwriteTablesDbProvider));
});

/// Applies damage/heal/temporary-HP actions to a [CombatTarget] (a player's
/// character or an NPC instance) and records a log entry for each action.
///
/// Row updates propagate to other clients via the Realtime subscriptions
/// already set up in [RealtimeService] (Story 7.1), so no local state is
/// held here.
class CombatActionsService {
  CombatActionsService(this._tablesDb);

  final TablesDB _tablesDb;

  Future<bool> applyDamage({
    required CombatTarget target,
    required String sessionId,
    required int amount,
  }) {
    final hpCurrent = CombatMath.applyDamage(target.hpCurrent, amount);
    return _updateHp(
      target: target,
      sessionId: sessionId,
      hpCurrent: hpCurrent,
      hpTemp: target.hpTemp,
      logType: LogEntryType.damage,
      logMessage: '${target.name} sofreu $amount de dano.',
    );
  }

  Future<bool> applyHeal({
    required CombatTarget target,
    required String sessionId,
    required int amount,
  }) {
    final hpCurrent = CombatMath.applyHeal(
      target.hpCurrent,
      target.hpMax,
      amount,
    );
    return _updateHp(
      target: target,
      sessionId: sessionId,
      hpCurrent: hpCurrent,
      hpTemp: target.hpTemp,
      logType: LogEntryType.heal,
      logMessage: '${target.name} recuperou $amount de HP.',
    );
  }

  Future<bool> applyTempHp({
    required CombatTarget target,
    required String sessionId,
    required int amount,
  }) {
    final hpTemp = CombatMath.applyTempHp(target.hpTemp, amount);
    return _updateHp(
      target: target,
      sessionId: sessionId,
      hpCurrent: target.hpCurrent,
      hpTemp: hpTemp,
      logType: LogEntryType.tempHp,
      logMessage: '${target.name} recebeu $amount de HP temporário.',
    );
  }

  Future<bool> _updateHp({
    required CombatTarget target,
    required String sessionId,
    required int hpCurrent,
    required int hpTemp,
    required LogEntryType logType,
    required String logMessage,
  }) async {
    try {
      final tableId = target.kind == CombatTargetKind.character
          ? appwriteCharactersTableId
          : appwriteNpcInstancesTableId;

      await _tablesDb.updateRow(
        databaseId: appwriteDatabaseId,
        tableId: tableId,
        rowId: target.id,
        data: {'hpCurrent': hpCurrent, 'hpTemp': hpTemp},
      );

      await _writeLog(sessionId: sessionId, type: logType, message: logMessage);

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _writeLog({
    required String sessionId,
    required LogEntryType type,
    required String message,
  }) async {
    try {
      await _tablesDb.createRow(
        databaseId: appwriteDatabaseId,
        tableId: appwriteLogsTableId,
        rowId: ID.unique(),
        data: {
          'sessionId': sessionId,
          'type': type.name,
          'message': message,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {
      // Logging failures shouldn't block the HP update itself.
    }
  }
}
