import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/combat/presentation/widgets/log_feed.dart';
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
  required String type,
  required String message,
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
    'sessionId': 'session-1',
    'type': type,
    'message': message,
    'actorName': 'GM',
    'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
  });
}

void main() {
  late MockTablesDB mockTablesDb;
  late MockRealtime mockRealtime;
  late MockRealtimeSubscription mockRealtimeSubscription;

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

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
        realtimeClientProvider.overrideWithValue(mockRealtime),
        authProvider.overrideWith(
          () => FakeAuthNotifier(
            const AuthState(
              status: AuthStatus.authenticated,
              displayName: 'GM',
            ),
          ),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SizedBox(height: 400, child: LogFeed(sessionId: 'session-1')),
        ),
      ),
    );
  }

  testWidgets('shows an empty state when there are no logs', (tester) async {
    when(
      () => mockTablesDb.listRows(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        queries: any(named: 'queries'),
      ),
    ).thenAnswer((_) async => models.RowList(total: 0, rows: <models.Row>[]));

    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Nenhum evento registrado ainda.'), findsOneWidget);
  });

  testWidgets('renders log entries with message and actor/time line', (
    tester,
  ) async {
    when(
      () => mockTablesDb.listRows(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        queries: any(named: 'queries'),
      ),
    ).thenAnswer(
      (_) async => models.RowList(
        total: 1,
        rows: [
          _logRow(
            id: 'log-1',
            type: 'damage',
            message: 'Orc sofreu 5 de dano.',
            timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
          ),
        ],
      ),
    );

    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Orc sofreu 5 de dano.'), findsOneWidget);
    expect(find.textContaining('há 2 min'), findsOneWidget);
  });
}
