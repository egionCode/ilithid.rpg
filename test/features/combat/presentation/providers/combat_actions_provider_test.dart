import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/features/combat/domain/combat_target.dart';
import 'package:ilithid/features/combat/presentation/providers/combat_actions_provider.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';
import 'package:mocktail/mocktail.dart';

class MockTablesDB extends Mock implements TablesDB {}

models.Row _buildRow(Map<String, dynamic> data) {
  return models.Row.fromMap({
    r'$id': 'row-id',
    r'$sequence': 1,
    r'$tableId': 'table',
    r'$databaseId': appwriteDatabaseId,
    r'$createdAt': DateTime.now().toIso8601String(),
    r'$updatedAt': DateTime.now().toIso8601String(),
    r'$permissions': <String>[],
    ...data,
  });
}

void main() {
  late MockTablesDB mockTablesDb;
  late CombatActionsService service;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockTablesDb = MockTablesDB();
    service = CombatActionsService(mockTablesDb);

    when(
      () => mockTablesDb.updateRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async => _buildRow({}));

    when(
      () => mockTablesDb.createRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async => _buildRow({}));
  });

  const character = CombatTarget(
    kind: CombatTargetKind.character,
    id: 'char-1',
    name: 'Aria',
    hpCurrent: 20,
    hpMax: 30,
    hpTemp: 0,
  );

  const npc = CombatTarget(
    kind: CombatTargetKind.npcInstance,
    id: 'npc-1',
    name: 'Orc',
    hpCurrent: 10,
    hpMax: 15,
    hpTemp: 0,
  );

  group('applyDamage', () {
    test('updates the characters table with clamped hpCurrent', () async {
      final result = await service.applyDamage(
        target: character,
        sessionId: 'session-1',
        actorName: 'GM',
        amount: 30,
      );

      expect(result, isTrue);
      final captured = verify(
        () => mockTablesDb.updateRow(
          databaseId: appwriteDatabaseId,
          tableId: appwriteCharactersTableId,
          rowId: 'char-1',
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured.single, equals({'hpCurrent': 0, 'hpTemp': 0}));
    });

    test('updates the npc_instances table for an NPC target', () async {
      await service.applyDamage(
        target: npc,
        sessionId: 'session-1',
        actorName: 'GM',
        amount: 4,
      );

      final captured = verify(
        () => mockTablesDb.updateRow(
          databaseId: appwriteDatabaseId,
          tableId: appwriteNpcInstancesTableId,
          rowId: 'npc-1',
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured.single, equals({'hpCurrent': 6, 'hpTemp': 0}));
    });

    test('writes a log entry matching the logs table schema', () async {
      await service.applyDamage(
        target: character,
        sessionId: 'session-1',
        actorName: 'Mestre Victor',
        amount: 5,
      );

      final captured = verify(
        () => mockTablesDb.createRow(
          databaseId: appwriteDatabaseId,
          tableId: appwriteLogsTableId,
          rowId: any(named: 'rowId'),
          data: captureAny(named: 'data'),
        ),
      ).captured;

      final logData = Map<String, dynamic>.from(captured.single as Map);
      expect(logData['sessionId'], 'session-1');
      expect(logData['type'], 'damage');
      expect(logData['actorName'], 'Mestre Victor');
      expect(logData.containsKey('timestamp'), isTrue);
      expect(logData.containsKey('createdAt'), isFalse);
    });
  });

  group('applyHeal', () {
    test('clamps healing at hpMax', () async {
      await service.applyHeal(
        target: character,
        sessionId: 'session-1',
        actorName: 'GM',
        amount: 50,
      );

      final captured = verify(
        () => mockTablesDb.updateRow(
          databaseId: appwriteDatabaseId,
          tableId: appwriteCharactersTableId,
          rowId: 'char-1',
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured.single, equals({'hpCurrent': 30, 'hpTemp': 0}));
    });
  });

  group('applyTempHp', () {
    test('adds temp HP without touching hpCurrent', () async {
      await service.applyTempHp(
        target: npc,
        sessionId: 'session-1',
        actorName: 'GM',
        amount: 5,
      );

      final captured = verify(
        () => mockTablesDb.updateRow(
          databaseId: appwriteDatabaseId,
          tableId: appwriteNpcInstancesTableId,
          rowId: 'npc-1',
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured.single, equals({'hpCurrent': 10, 'hpTemp': 5}));
    });
  });

  test('returns false when the update fails', () async {
    when(
      () => mockTablesDb.updateRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
        data: any(named: 'data'),
      ),
    ).thenThrow(Exception('network error'));

    final result = await service.applyDamage(
      target: character,
      sessionId: 'session-1',
      actorName: 'GM',
      amount: 5,
    );

    expect(result, isFalse);
  });
}
