import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/sessions/presentation/providers/sessions_provider.dart';
import 'package:ilithid/features/sessions/presentation/providers/sessions_state.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';
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
  ProviderContainer? container;
  const String campaignId = 'test-campaign-id';

  models.Row buildSessionRow({
    required String id,
    required String campaignId,
    required String status,
    bool showNpcHp = false,
  }) {
    return models.Row.fromMap({
      '\$id': id,
      '\$tableId': 'sessions',
      '\$databaseId': 'main',
      '\$createdAt': '',
      '\$updatedAt': '',
      '\$permissions': <String>[],
      '\$sequence': 0,
      'campaignId': campaignId,
      'status': status,
      'startedAt': DateTime.now().toIso8601String(),
      'endedAt': null,
      'showNpcHp': showNpcHp,
    });
  }

  models.User buildMockUser({
    required String id,
    required String name,
    required String email,
  }) {
    return models.User.fromMap({
      '\$id': id,
      '\$createdAt': '',
      '\$updatedAt': '',
      'name': name,
      'email': email,
      'phone': '',
      'emailVerification': false,
      'phoneVerification': false,
      'status': true,
      'labels': <String>[],
      'passwordUpdate': '',
      'registration': '',
      'accessedAt': '',
      'prefs': <String, dynamic>{},
      'mfa': false,
      'targets': <Map<String, dynamic>>[],
    });
  }

  setUp(() {
    mockTablesDb = MockTablesDB();
    mockRealtime = MockRealtime();
    mockRealtimeSubscription = MockRealtimeSubscription();
    container = null;

    when(
      () => mockRealtime.subscribe(any()),
    ).thenReturn(mockRealtimeSubscription);
    when(
      () => mockRealtimeSubscription.stream,
    ).thenAnswer((_) => const Stream.empty());
  });

  tearDown(() {
    container?.dispose();
  });

  group('SessionsNotifier Tests', () {
    test(
      'checkActiveSession sets activeSession to null if no session is active',
      () async {
        // Stub listRows to return empty list
        when(
          () => mockTablesDb.listRows(
            databaseId: appwriteDatabaseId,
            tableId: appwriteSessionsTableId,
            queries: any(named: 'queries'),
          ),
        ).thenAnswer(
          (_) async => models.RowList.fromMap({
            'total': 0,
            'rows': <Map<String, dynamic>>[],
          }),
        );

        final authState = AuthState.authenticated(
          buildMockUser(
            id: 'user-id',
            name: 'User Name',
            email: 'email@example.com',
          ),
          'User Name',
        );

        container = ProviderContainer(
          overrides: [
            appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
            appwriteRealtimeProvider.overrideWithValue(mockRealtime),
            authProvider.overrideWith(() => FakeAuthNotifier(authState)),
          ],
        );

        // Trigger build / initialization
        final stateBefore = container!.read(sessionsProvider(campaignId));
        expect(stateBefore.status, SessionsStatus.initial);

        // Wait for async checkActiveSession to complete
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final stateAfter = container!.read(sessionsProvider(campaignId));
        expect(stateAfter.status, SessionsStatus.success);
        expect(stateAfter.activeSession, isNull);
        expect(stateAfter.sessions, isEmpty);
      },
    );

    test(
      'checkActiveSession sets activeSession if an active session is found',
      () async {
        final sessionRow = buildSessionRow(
          id: 'session-id',
          campaignId: campaignId,
          status: 'active',
        );

        when(
          () => mockTablesDb.listRows(
            databaseId: appwriteDatabaseId,
            tableId: appwriteSessionsTableId,
            queries: any(named: 'queries'),
          ),
        ).thenAnswer(
          (_) async => models.RowList.fromMap({
            'total': 1,
            'rows': [sessionRow.toMap()],
          }),
        );

        final authState = AuthState.authenticated(
          buildMockUser(
            id: 'user-id',
            name: 'User Name',
            email: 'email@example.com',
          ),
          'User Name',
        );

        container = ProviderContainer(
          overrides: [
            appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
            appwriteRealtimeProvider.overrideWithValue(mockRealtime),
            authProvider.overrideWith(() => FakeAuthNotifier(authState)),
          ],
        );

        container!.read(sessionsProvider(campaignId));
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final state = container!.read(sessionsProvider(campaignId));
        expect(state.status, SessionsStatus.success);
        expect(state.activeSession, isNotNull);
        expect(state.activeSession!.id, 'session-id');
        expect(state.activeSession!.status, 'active');
        expect(state.sessions, hasLength(1));
        expect(state.sessions.first.id, 'session-id');
      },
    );

    test(
      'checkActiveSession populates all sessions and extracts activeSession correctly',
      () async {
        final activeSessionRow = buildSessionRow(
          id: 'session-active',
          campaignId: campaignId,
          status: 'active',
        );
        final inactiveSessionRow = buildSessionRow(
          id: 'session-inactive',
          campaignId: campaignId,
          status: 'finished',
        );

        when(
          () => mockTablesDb.listRows(
            databaseId: appwriteDatabaseId,
            tableId: appwriteSessionsTableId,
            queries: any(named: 'queries'),
          ),
        ).thenAnswer(
          (_) async => models.RowList.fromMap({
            'total': 2,
            'rows': [activeSessionRow.toMap(), inactiveSessionRow.toMap()],
          }),
        );

        final authState = AuthState.authenticated(
          buildMockUser(
            id: 'user-id',
            name: 'User Name',
            email: 'email@example.com',
          ),
          'User Name',
        );

        container = ProviderContainer(
          overrides: [
            appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
            appwriteRealtimeProvider.overrideWithValue(mockRealtime),
            authProvider.overrideWith(() => FakeAuthNotifier(authState)),
          ],
        );

        container!.read(sessionsProvider(campaignId));
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final state = container!.read(sessionsProvider(campaignId));
        expect(state.status, SessionsStatus.success);
        expect(state.sessions, hasLength(2));
        expect(state.activeSession, isNotNull);
        expect(state.activeSession!.id, 'session-active');
        expect(state.sessions[0].id, 'session-active');
        expect(state.sessions[1].id, 'session-inactive');
      },
    );

    test('createSession fails if there is already an active session', () async {
      final sessionRow = buildSessionRow(
        id: 'session-id',
        campaignId: campaignId,
        status: 'active',
      );

      // Mock listRows to say there is an active session
      when(
        () => mockTablesDb.listRows(
          databaseId: appwriteDatabaseId,
          tableId: appwriteSessionsTableId,
          queries: any(named: 'queries'),
        ),
      ).thenAnswer(
        (_) async => models.RowList.fromMap({
          'total': 1,
          'rows': [sessionRow.toMap()],
        }),
      );

      final authState = AuthState.authenticated(
        buildMockUser(
          id: 'user-id',
          name: 'User Name',
          email: 'email@example.com',
        ),
        'User Name',
      );

      container = ProviderContainer(
        overrides: [
          appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
          appwriteRealtimeProvider.overrideWithValue(mockRealtime),
          authProvider.overrideWith(() => FakeAuthNotifier(authState)),
        ],
      );

      container!.read(sessionsProvider(campaignId));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final result = await container!
          .read(sessionsProvider(campaignId).notifier)
          .createSession();
      expect(result, isNull);

      final state = container!.read(sessionsProvider(campaignId));
      expect(state.status, SessionsStatus.error);
      expect(
        state.errorMessage,
        'A session is already active for this campaign.',
      );
    });

    test('createSession succeeds if there is no active session', () async {
      // 1. Mock listRows to return empty (no active session)
      when(
        () => mockTablesDb.listRows(
          databaseId: appwriteDatabaseId,
          tableId: appwriteSessionsTableId,
          queries: any(named: 'queries'),
        ),
      ).thenAnswer(
        (_) async => models.RowList.fromMap({
          'total': 0,
          'rows': <Map<String, dynamic>>[],
        }),
      );

      // 2. Mock createRow to return the newly created session row
      final newSessionRow = buildSessionRow(
        id: 'new-session-id',
        campaignId: campaignId,
        status: 'active',
      );

      when(
        () => mockTablesDb.createRow(
          databaseId: appwriteDatabaseId,
          tableId: appwriteSessionsTableId,
          rowId: any(named: 'rowId'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => newSessionRow);

      final authState = AuthState.authenticated(
        buildMockUser(
          id: 'user-id',
          name: 'User Name',
          email: 'email@example.com',
        ),
        'User Name',
      );

      container = ProviderContainer(
        overrides: [
          appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
          appwriteRealtimeProvider.overrideWithValue(mockRealtime),
          authProvider.overrideWith(() => FakeAuthNotifier(authState)),
        ],
      );

      container!.read(sessionsProvider(campaignId));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final result = await container!
          .read(sessionsProvider(campaignId).notifier)
          .createSession();
      expect(result, isNotNull);
      expect(result!.id, 'new-session-id');
      expect(result.status, 'active');

      final state = container!.read(sessionsProvider(campaignId));
      expect(state.status, SessionsStatus.success);
      expect(state.activeSession, isNotNull);
      expect(state.activeSession!.id, 'new-session-id');
      expect(state.sessions, hasLength(1));
      expect(state.sessions.first.id, 'new-session-id');
    });

    test('endSession succeeds and updates activeSession and list', () async {
      final finishedSessionRow = buildSessionRow(
        id: 'session-id',
        campaignId: campaignId,
        status: 'finished',
      );

      when(
        () => mockTablesDb.updateRow(
          databaseId: appwriteDatabaseId,
          tableId: appwriteSessionsTableId,
          rowId: 'session-id',
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => finishedSessionRow);

      when(
        () => mockTablesDb.listRows(
          databaseId: appwriteDatabaseId,
          tableId: appwriteSessionsTableId,
          queries: any(named: 'queries'),
        ),
      ).thenAnswer(
        (_) async => models.RowList.fromMap({
          'total': 1,
          'rows': [finishedSessionRow.toMap()],
        }),
      );

      final authState = AuthState.authenticated(
        buildMockUser(
          id: 'user-id',
          name: 'User Name',
          email: 'email@example.com',
        ),
        'User Name',
      );

      container = ProviderContainer(
        overrides: [
          appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
          appwriteRealtimeProvider.overrideWithValue(mockRealtime),
          authProvider.overrideWith(() => FakeAuthNotifier(authState)),
        ],
      );

      container!.read(sessionsProvider(campaignId));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final result = await container!
          .read(sessionsProvider(campaignId).notifier)
          .endSession('session-id');
      expect(result, isTrue);

      final state = container!.read(sessionsProvider(campaignId));
      expect(state.status, SessionsStatus.success);
      expect(state.activeSession, isNull);
      expect(state.sessions, hasLength(1));
      expect(state.sessions.first.status, 'finished');
    });

    test('setShowNpcHp updates the session and refetches', () async {
      final updatedSessionRow = buildSessionRow(
        id: 'session-id',
        campaignId: campaignId,
        status: 'active',
        showNpcHp: true,
      );

      when(
        () => mockTablesDb.updateRow(
          databaseId: appwriteDatabaseId,
          tableId: appwriteSessionsTableId,
          rowId: 'session-id',
          data: {'showNpcHp': true},
        ),
      ).thenAnswer((_) async => updatedSessionRow);

      when(
        () => mockTablesDb.listRows(
          databaseId: appwriteDatabaseId,
          tableId: appwriteSessionsTableId,
          queries: any(named: 'queries'),
        ),
      ).thenAnswer(
        (_) async => models.RowList.fromMap({
          'total': 1,
          'rows': [updatedSessionRow.toMap()],
        }),
      );

      final authState = AuthState.authenticated(
        buildMockUser(
          id: 'user-id',
          name: 'User Name',
          email: 'email@example.com',
        ),
        'User Name',
      );

      container = ProviderContainer(
        overrides: [
          appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
          appwriteRealtimeProvider.overrideWithValue(mockRealtime),
          authProvider.overrideWith(() => FakeAuthNotifier(authState)),
        ],
      );

      container!.read(sessionsProvider(campaignId));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final result = await container!
          .read(sessionsProvider(campaignId).notifier)
          .setShowNpcHp('session-id', true);
      expect(result, isTrue);

      final state = container!.read(sessionsProvider(campaignId));
      expect(state.sessions.first.showNpcHp, isTrue);
    });

    group('realtime subscription tests', () {
      // Note: Appwrite Realtime object subscription is tested implicitly or mocked.
      // The implementation fails silently if Realtime setup fails, which is safe.
    });
  });
}
