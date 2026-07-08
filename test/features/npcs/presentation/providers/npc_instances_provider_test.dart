import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/npcs/presentation/providers/npc_instances_provider.dart';
import 'package:ilithid/features/npcs/presentation/providers/npc_instances_state.dart';
import 'package:ilithid/features/sessions/presentation/providers/sessions_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockTablesDB extends Mock implements TablesDB {}

class MockRealtime extends Mock implements Realtime {}

class MockRealtimeSubscription extends Mock implements RealtimeSubscription {}

class FakeAuthNotifier extends AuthNotifier {
  final AuthState _initialState;

  FakeAuthNotifier(this._initialState);

  @override
  AuthState build() {
    return _initialState;
  }
}

void main() {
  late MockTablesDB mockTablesDb;
  late MockRealtime mockRealtime;
  late MockRealtimeSubscription mockRealtimeSubscription;
  late ProviderContainer container;
  const sessionId = 'test-session-id';

  /// Helper to mock an NPC Instance Row.
  models.Row buildNpcInstanceRow({
    required String id,
    required String sessionId,
    String? templateId,
    required String name,
    required int hpCurrent,
    required int hpMax,
    int hpTemp = 0,
    required int ac,
  }) {
    return models.Row.fromMap({
      '\$id': id,
      '\$tableId': 'npc_instances',
      '\$databaseId': 'main',
      '\$createdAt': '',
      '\$updatedAt': '',
      '\$permissions': <String>[],
      '\$sequence': 0,
      'sessionId': sessionId,
      'templateId': templateId,
      'name': name,
      'hpCurrent': hpCurrent,
      'hpMax': hpMax,
      'hpTemp': hpTemp,
      'ac': ac,
    });
  }

  setUp(() {
    mockTablesDb = MockTablesDB();
    mockRealtime = MockRealtime();
    mockRealtimeSubscription = MockRealtimeSubscription();

    when(
      () => mockRealtime.subscribe(any()),
    ).thenReturn(mockRealtimeSubscription);
    when(
      () => mockRealtimeSubscription.stream,
    ).thenAnswer((_) => const Stream.empty());

    when(
      () => mockTablesDb.listRows(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        queries: any(named: 'queries'),
      ),
    ).thenAnswer(
      (_) async => models.RowList.fromMap({
        'total': 0,
        'rows': <Map<String, dynamic>>[],
      }),
    );
  });

  tearDown(() {
    container.dispose();
  });

  ProviderContainer createContainer(AuthState authState) {
    container = ProviderContainer(
      overrides: [
        appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
        appwriteRealtimeProvider.overrideWithValue(mockRealtime),
        authProvider.overrideWith(() => FakeAuthNotifier(authState)),
      ],
    );
    return container;
  }

  group('NpcInstancesNotifier Tests', () {
    test('initial state is initial status with empty list', () {
      final authState = AuthState.initial();
      final container = createContainer(authState);

      final state = container.read(npcInstancesProvider(sessionId));

      expect(state.status, NpcInstancesStatus.initial);
      expect(state.npcInstances, isEmpty);
      expect(state.errorMessage, null);
    });

    test('fetchNpcInstances success state', () async {
      final mockUser = models.User.fromMap({
        '\$id': 'user-123',
        '\$createdAt': '',
        '\$updatedAt': '',
        'name': 'Victor',
        'email': 'victor@mail.com',
        'phone': '',
        'emailVerification': true,
        'phoneVerification': false,
        'status': true,
        'mfa': false,
        'passwordUpdate': '',
        'accessedAt': '',
        'registration': '',
        'labels': <String>[],
        'prefs': <String, dynamic>{},
        'targets': <Map<String, dynamic>>[],
      });
      final authState = AuthState(
        status: AuthStatus.authenticated,
        user: mockUser,
        displayName: 'Victor',
      );

      final row1 = buildNpcInstanceRow(
        id: 'inst-1',
        sessionId: sessionId,
        name: 'Goblin 1',
        hpCurrent: 7,
        hpMax: 7,
        ac: 15,
      );
      final row2 = buildNpcInstanceRow(
        id: 'inst-2',
        sessionId: sessionId,
        name: 'Goblin 2',
        hpCurrent: 7,
        hpMax: 7,
        ac: 15,
      );

      when(
        () => mockTablesDb.listRows(
          databaseId: any(named: 'databaseId'),
          tableId: 'npc_instances',
          queries: any(named: 'queries'),
        ),
      ).thenAnswer(
        (_) async => models.RowList.fromMap({
          'total': 2,
          'rows': [row1.toMap(), row2.toMap()],
        }),
      );

      final container = createContainer(authState);

      await container
          .read(npcInstancesProvider(sessionId).notifier)
          .fetchNpcInstances();

      final state = container.read(npcInstancesProvider(sessionId));

      expect(state.status, NpcInstancesStatus.success);
      expect(state.npcInstances.length, 2);
      expect(state.npcInstances[0].id, 'inst-1');
      expect(state.npcInstances[0].name, 'Goblin 1');
      expect(state.npcInstances[1].id, 'inst-2');
    });

    test('fetchNpcInstances failure state', () async {
      final mockUser = models.User.fromMap({
        '\$id': 'user-123',
        '\$createdAt': '',
        '\$updatedAt': '',
        'name': 'Victor',
        'email': 'victor@mail.com',
        'phone': '',
        'emailVerification': true,
        'phoneVerification': false,
        'status': true,
        'mfa': false,
        'passwordUpdate': '',
        'accessedAt': '',
        'registration': '',
        'labels': <String>[],
        'prefs': <String, dynamic>{},
        'targets': <Map<String, dynamic>>[],
      });
      final authState = AuthState(
        status: AuthStatus.authenticated,
        user: mockUser,
        displayName: 'Victor',
      );

      when(
        () => mockTablesDb.listRows(
          databaseId: any(named: 'databaseId'),
          tableId: 'npc_instances',
          queries: any(named: 'queries'),
        ),
      ).thenThrow(AppwriteException('Database error', 500, ''));

      final container = createContainer(authState);

      await container
          .read(npcInstancesProvider(sessionId).notifier)
          .fetchNpcInstances();

      final state = container.read(npcInstancesProvider(sessionId));

      expect(state.status, NpcInstancesStatus.error);
      expect(state.errorMessage, 'Database error');
    });

    test('instantiateNpc success flow', () async {
      final mockUser = models.User.fromMap({
        '\$id': 'user-123',
        '\$createdAt': '',
        '\$updatedAt': '',
        'name': 'Victor',
        'email': 'victor@mail.com',
        'phone': '',
        'emailVerification': true,
        'phoneVerification': false,
        'status': true,
        'mfa': false,
        'passwordUpdate': '',
        'accessedAt': '',
        'registration': '',
        'labels': <String>[],
        'prefs': <String, dynamic>{},
        'targets': <Map<String, dynamic>>[],
      });
      final authState = AuthState(
        status: AuthStatus.authenticated,
        user: mockUser,
        displayName: 'Victor',
      );

      final newRow = buildNpcInstanceRow(
        id: 'new-inst',
        sessionId: sessionId,
        name: 'Orc Warchief',
        hpCurrent: 45,
        hpMax: 45,
        ac: 16,
        templateId: 'tpl-1',
      );

      when(
        () => mockTablesDb.createRow(
          databaseId: any(named: 'databaseId'),
          tableId: 'npc_instances',
          rowId: any(named: 'rowId'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => newRow);

      final container = createContainer(authState);
      final notifier = container.read(npcInstancesProvider(sessionId).notifier);

      final result = await notifier.instantiateNpc(
        name: 'Orc Warchief',
        hpMax: 45,
        ac: 16,
        templateId: 'tpl-1',
      );

      expect(result, isNotNull);
      expect(result!.id, 'new-inst');
      expect(result.name, 'Orc Warchief');
      expect(result.hpCurrent, 45);

      final state = container.read(npcInstancesProvider(sessionId));
      expect(state.npcInstances, contains(result));
    });

    test('updateNpcHp success flow', () async {
      final mockUser = models.User.fromMap({
        '\$id': 'user-123',
        '\$createdAt': '',
        '\$updatedAt': '',
        'name': 'Victor',
        'email': 'victor@mail.com',
        'phone': '',
        'emailVerification': true,
        'phoneVerification': false,
        'status': true,
        'mfa': false,
        'passwordUpdate': '',
        'accessedAt': '',
        'registration': '',
        'labels': <String>[],
        'prefs': <String, dynamic>{},
        'targets': <Map<String, dynamic>>[],
      });
      final authState = AuthState(
        status: AuthStatus.authenticated,
        user: mockUser,
        displayName: 'Victor',
      );

      final initialRow = buildNpcInstanceRow(
        id: 'inst-1',
        sessionId: sessionId,
        name: 'Goblin 1',
        hpCurrent: 7,
        hpMax: 7,
        ac: 15,
      );

      final updatedRow = buildNpcInstanceRow(
        id: 'inst-1',
        sessionId: sessionId,
        name: 'Goblin 1',
        hpCurrent: 4,
        hpMax: 7,
        ac: 15,
        hpTemp: 2,
      );

      when(
        () => mockTablesDb.listRows(
          databaseId: any(named: 'databaseId'),
          tableId: 'npc_instances',
          queries: any(named: 'queries'),
        ),
      ).thenAnswer(
        (_) async => models.RowList.fromMap({
          'total': 1,
          'rows': [initialRow.toMap()],
        }),
      );

      when(
        () => mockTablesDb.updateRow(
          databaseId: any(named: 'databaseId'),
          tableId: 'npc_instances',
          rowId: 'inst-1',
          data: {
            'sessionId': sessionId,
            'name': 'Goblin 1',
            'hpCurrent': 4,
            'hpMax': 7,
            'hpTemp': 2,
            'ac': 15,
          },
        ),
      ).thenAnswer((_) async => updatedRow);

      final container = createContainer(authState);
      final notifier = container.read(npcInstancesProvider(sessionId).notifier);

      // Load initial instances
      await notifier.fetchNpcInstances();

      final success = await notifier.updateNpcHp(
        'inst-1',
        hpCurrent: 4,
        hpTemp: 2,
      );
      expect(success, isTrue);

      final state = container.read(npcInstancesProvider(sessionId));
      expect(state.npcInstances.length, 1);
      expect(state.npcInstances[0].hpCurrent, 4);
      expect(state.npcInstances[0].hpTemp, 2);
    });

    test('deleteNpcInstance success flow', () async {
      final mockUser = models.User.fromMap({
        '\$id': 'user-123',
        '\$createdAt': '',
        '\$updatedAt': '',
        'name': 'Victor',
        'email': 'victor@mail.com',
        'phone': '',
        'emailVerification': true,
        'phoneVerification': false,
        'status': true,
        'mfa': false,
        'passwordUpdate': '',
        'accessedAt': '',
        'registration': '',
        'labels': <String>[],
        'prefs': <String, dynamic>{},
        'targets': <Map<String, dynamic>>[],
      });
      final authState = AuthState(
        status: AuthStatus.authenticated,
        user: mockUser,
        displayName: 'Victor',
      );

      final initialRow = buildNpcInstanceRow(
        id: 'inst-1',
        sessionId: sessionId,
        name: 'Goblin 1',
        hpCurrent: 7,
        hpMax: 7,
        ac: 15,
      );

      when(
        () => mockTablesDb.listRows(
          databaseId: any(named: 'databaseId'),
          tableId: 'npc_instances',
          queries: any(named: 'queries'),
        ),
      ).thenAnswer(
        (_) async => models.RowList.fromMap({
          'total': 1,
          'rows': [initialRow.toMap()],
        }),
      );

      when(
        () => mockTablesDb.deleteRow(
          databaseId: any(named: 'databaseId'),
          tableId: 'npc_instances',
          rowId: 'inst-1',
        ),
      ).thenAnswer((_) async => {});

      final container = createContainer(authState);
      final notifier = container.read(npcInstancesProvider(sessionId).notifier);

      // Load initial instances
      await notifier.fetchNpcInstances();

      final success = await notifier.deleteNpcInstance('inst-1');
      expect(success, isTrue);

      final state = container.read(npcInstancesProvider(sessionId));
      expect(state.npcInstances, isEmpty);
    });
  });
}
