import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/campaigns/presentation/widgets/transfer_gm_dialog.dart';
import 'package:ilithid/features/sessions/presentation/providers/sessions_provider.dart';
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

models.Row _memberRow({
  required String id,
  required String userId,
  required String role,
}) {
  return models.Row.fromMap({
    r'$id': id,
    r'$tableId': appwriteCampaignMembersTableId,
    r'$databaseId': appwriteDatabaseId,
    r'$createdAt': '',
    r'$updatedAt': '',
    r'$permissions': <String>[],
    r'$sequence': 0,
    'campaignId': 'campaign-1',
    'userId': userId,
    'activeCharacterId': null,
    'role': role,
    'joinedAt': DateTime.now().toIso8601String(),
  });
}

models.Row _profileRow(String userId, String displayName) {
  return models.Row.fromMap({
    r'$id': userId,
    r'$tableId': appwriteProfilesTableId,
    r'$databaseId': appwriteDatabaseId,
    r'$createdAt': '',
    r'$updatedAt': '',
    r'$permissions': <String>[],
    r'$sequence': 0,
    'userId': userId,
    'displayName': displayName,
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

    when(
      () => mockTablesDb.listRows(
        databaseId: any(named: 'databaseId'),
        tableId: appwriteCampaignMembersTableId,
        queries: any(named: 'queries'),
      ),
    ).thenAnswer(
      (_) async => models.RowList(
        total: 2,
        rows: [
          _memberRow(id: 'member-gm', userId: 'gm-id', role: 'gm'),
          _memberRow(id: 'member-player', userId: 'player-id', role: 'player'),
        ],
      ),
    );

    when(
      () => mockTablesDb.listRows(
        databaseId: any(named: 'databaseId'),
        tableId: appwriteCharactersTableId,
        queries: any(named: 'queries'),
      ),
    ).thenAnswer((_) async => models.RowList(total: 0, rows: <models.Row>[]));

    when(
      () => mockTablesDb.getRow(
        databaseId: any(named: 'databaseId'),
        tableId: appwriteProfilesTableId,
        rowId: 'player-id',
      ),
    ).thenAnswer((_) async => _profileRow('player-id', 'Vex Vaneth'));

    when(
      () => mockTablesDb.updateRow(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        rowId: any(named: 'rowId'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async => _memberRow(id: 'x', userId: 'x', role: 'gm'));
  });

  Widget buildTestWidget() {
    final gmUser = models.User.fromMap({
      r'$id': 'gm-id',
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

    return ProviderScope(
      overrides: [
        appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
        realtimeClientProvider.overrideWithValue(mockRealtime),
        appwriteRealtimeProvider.overrideWithValue(mockRealtime),
        authProvider.overrideWith(
          () => FakeAuthNotifier(AuthState.authenticated(gmUser, 'GM')),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: TransferGmDialog(
            campaignId: 'campaign-1',
            currentUserId: 'gm-id',
          ),
        ),
      ),
    );
  }

  testWidgets('lists players (excluding self and the current GM)', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Vex Vaneth'), findsOneWidget);
    expect(
      find.byKey(const Key('transfer_gm_option_player-id')),
      findsOneWidget,
    );
  });

  testWidgets('confirming the transfer calls transferGm with the target id', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('transfer_gm_option_player-id')));
    await tester.pumpAndSettle();

    expect(find.text('Confirmar'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm_transfer_gm_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    verify(
      () => mockTablesDb.updateRow(
        databaseId: appwriteDatabaseId,
        tableId: appwriteCampaignsTableId,
        rowId: 'campaign-1',
        data: {'gmUserId': 'player-id'},
      ),
    ).called(1);
  });
}
