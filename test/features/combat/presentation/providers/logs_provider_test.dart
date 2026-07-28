import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/combat/presentation/providers/logs_provider.dart';
import 'package:ilithid/features/combat/presentation/providers/logs_state.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';
import 'package:ilithid/shared/services/realtime_service.dart';
import 'package:mocktail/mocktail.dart';

class MockTablesDB extends Mock implements TablesDB {}

class MockRealtime extends Mock implements Realtime {}

class MockRealtimeSubscription extends Mock implements RealtimeSubscription {}

class FakeAuthNotifier extends AuthNotifier {
  final AuthState _initialState;
  FakeAuthNotifier(this._initialState);
  @override
  AuthState build() => _initialState;
}

models.Row _logRow({
  required String id,
  required String sessionId,
  required String type,
  String message = 'msg',
  String actorName = 'GM',
  DateTime? timestamp,
}) {
  return models.Row.fromMap({
    r'$id': id,
    r'$tableId': appwriteLogsTableId,
    r'$databaseId': appwriteDatabaseId,
    r'$createdAt': '',
    r'$updatedAt': '',
    r'$permissions': <String>[],
    r'$sequence': 0,
    'sessionId': sessionId,
    'type': type,
    'message': message,
    'actorName': actorName,
    'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
  });
}

models.User _buildMockUser() {
  return models.User.fromMap({
    r'$id': 'user-id',
    r'$createdAt': '',
    r'$updatedAt': '',
    'name': 'GM',
    'email': 'gm@example.com',
    'phone': '',
    'status': true,
    'labels': <String>[],
    'passwordUpdate': '',
    'emailVerification': true,
    'phoneVerification': false,
    'mfa': false,
    'prefs': <String, dynamic>{},
    'accessedAt': '',
    'registration': '',
    'targets': <Map<String, dynamic>>[],
  });
}

void main() {
  late MockTablesDB mockTablesDb;
  late MockRealtime mockRealtime;
  late MockRealtimeSubscription mockRealtimeSubscription;
  ProviderContainer? container;
  const sessionId = 'session-1';

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
    when(() => mockRealtimeSubscription.close).thenReturn(() async {});
  });

  tearDown(() => container?.dispose());

  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [
        appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
        realtimeClientProvider.overrideWithValue(mockRealtime),
        authProvider.overrideWith(
          () =>
              FakeAuthNotifier(AuthState.authenticated(_buildMockUser(), 'GM')),
        ),
      ],
    );
  }

  test('fetchLogs loads the most recent page ordered by the query', () async {
    when(
      () => mockTablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteLogsTableId,
        queries: any(named: 'queries'),
      ),
    ).thenAnswer(
      (_) async => models.RowList(
        total: 2,
        rows: [
          _logRow(id: 'log-2', sessionId: sessionId, type: 'heal'),
          _logRow(id: 'log-1', sessionId: sessionId, type: 'damage'),
        ],
      ),
    );

    container = buildContainer();
    container!.read(logsProvider(sessionId));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = container!.read(logsProvider(sessionId));
    expect(state.status, LogsStatus.success);
    expect(state.logs, hasLength(2));
    expect(state.hasMore, isFalse);
  });

  test('hasMore is true when total exceeds the fetched page', () async {
    when(
      () => mockTablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteLogsTableId,
        queries: any(named: 'queries'),
      ),
    ).thenAnswer(
      (_) async => models.RowList(
        total: 100,
        rows: [_logRow(id: 'log-1', sessionId: sessionId, type: 'damage')],
      ),
    );

    container = buildContainer();
    container!.read(logsProvider(sessionId));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = container!.read(logsProvider(sessionId));
    expect(state.hasMore, isTrue);
  });

  test('loadMore appends older entries to the end of the list', () async {
    when(
      () => mockTablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteLogsTableId,
        queries: any(named: 'queries'),
      ),
    ).thenAnswer(
      (_) async => models.RowList(
        total: 2,
        rows: [_logRow(id: 'log-1', sessionId: sessionId, type: 'damage')],
      ),
    );

    container = buildContainer();
    container!.read(logsProvider(sessionId));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    when(
      () => mockTablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteLogsTableId,
        queries: any(named: 'queries'),
      ),
    ).thenAnswer(
      (_) async => models.RowList(
        total: 2,
        rows: [_logRow(id: 'log-2', sessionId: sessionId, type: 'heal')],
      ),
    );

    await container!.read(logsProvider(sessionId).notifier).loadMore();

    final state = container!.read(logsProvider(sessionId));
    expect(state.logs, hasLength(2));
    expect(state.logs.map((l) => l.id), ['log-1', 'log-2']);
    expect(state.hasMore, isFalse);
  });

  test('reports an error when fetchLogs fails', () async {
    when(
      () => mockTablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteLogsTableId,
        queries: any(named: 'queries'),
      ),
    ).thenThrow(Exception('network error'));

    container = buildContainer();
    container!.read(logsProvider(sessionId));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = container!.read(logsProvider(sessionId));
    expect(state.status, LogsStatus.error);
  });
}
