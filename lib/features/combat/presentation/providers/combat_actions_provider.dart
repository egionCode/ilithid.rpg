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
    required String actorName,
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
      actorName: actorName,
    );
  }

  Future<bool> applyHeal({
    required CombatTarget target,
    required String sessionId,
    required String actorName,
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
      actorName: actorName,
    );
  }

  Future<bool> applyTempHp({
    required CombatTarget target,
    required String sessionId,
    required String actorName,
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
      actorName: actorName,
    );
  }

  /// Writes a free-form log entry for the GM (Story 8.1 `custom` type),
  /// e.g. narrative notes not tied to a specific HP change.
  ///
  /// Unlike [_writeLog] (used as a side effect of HP updates, where a
  /// logging failure shouldn't block the HP change), this IS the action,
  /// so failures are reported back instead of swallowed.
  Future<bool> writeCustomLog({
    required String sessionId,
    required String actorName,
    required String message,
  }) async {
    try {
      final entry = LogEntry(
        id: '',
        sessionId: sessionId,
        type: LogEntryType.custom,
        message: message,
        actorName: actorName,
        timestamp: DateTime.now(),
      );

      await _tablesDb.createRow(
        databaseId: appwriteDatabaseId,
        tableId: appwriteLogsTableId,
        rowId: ID.unique(),
        data: entry.toMap(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _updateHp({
    required CombatTarget target,
    required String sessionId,
    required int hpCurrent,
    required int hpTemp,
    required LogEntryType logType,
    required String logMessage,
    required String actorName,
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

      await _writeLog(
        sessionId: sessionId,
        type: logType,
        message: logMessage,
        actorName: actorName,
      );

      // A hit that brings hpCurrent from alive to zero gets its own death
      // log entry, on top of the damage entry (Story 8.1).
      if (target.hpCurrent > 0 && hpCurrent == 0) {
        await _writeLog(
          sessionId: sessionId,
          type: LogEntryType.death,
          message: '${target.name} foi derrotado(a).',
          actorName: actorName,
        );
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _writeLog({
    required String sessionId,
    required LogEntryType type,
    required String message,
    required String actorName,
  }) async {
    try {
      final entry = LogEntry(
        id: '',
        sessionId: sessionId,
        type: type,
        message: message,
        actorName: actorName,
        timestamp: DateTime.now(),
      );

      await _tablesDb.createRow(
        databaseId: appwriteDatabaseId,
        tableId: appwriteLogsTableId,
        rowId: ID.unique(),
        data: entry.toMap(),
      );
    } catch (_) {
      // Logging failures shouldn't block the HP update itself.
    }
  }
}
