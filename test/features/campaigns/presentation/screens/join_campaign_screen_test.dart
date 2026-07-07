import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/campaigns/presentation/screens/join_campaign_screen.dart';
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

  /// Helper to mock a Campaign Row.
  models.Row buildCampaignRow({
    required String id,
    required String name,
    required String hexId,
  }) {
    return models.Row.fromMap({
      '\$id': id,
      '\$tableId': 'campaigns',
      '\$databaseId': 'main',
      '\$createdAt': '',
      '\$updatedAt': '',
      '\$permissions': <String>[],
      '\$sequence': 0,
      'hexId': hexId,
      'name': name,
      'gmUserId': 'gm_123',
      'status': 'active',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Helper to mock a Character Row.
  models.Row buildCharacterRow({required String id, required String name}) {
    return models.Row.fromMap({
      '\$id': id,
      '\$tableId': 'characters',
      '\$databaseId': 'main',
      '\$createdAt': '',
      '\$updatedAt': '',
      '\$permissions': <String>[],
      '\$sequence': 0,
      'userId': 'user_123',
      'name': name,
      'hpCurrent': 120,
      'hpMax': 120,
      'ac': 17,
      'createdAt': DateTime.now().toIso8601String(),
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

    // Register default stubs to prevent type errors on automatic reactive fetches
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

  testWidgets('JoinCampaignScreen searches and joins campaign successfully', (
    tester,
  ) async {
    final authenticatedUser = models.User.fromMap({
      '\$id': 'user_123',
      '\$createdAt': '',
      '\$updatedAt': '',
      'name': 'Grog',
      'email': 'grog@vox.com',
      'phone': '',
      'emailVerification': false,
      'phoneVerification': false,
      'status': true,
      'labels': <String>[],
      'passwordUpdate': '',
      'mfa': false,
      'prefs': <String, dynamic>{},
      'accessedAt': '',
      'registration': '',
      'targets': <Map<String, dynamic>>[],
    });

    final authenticatedState = AuthState(
      status: AuthStatus.authenticated,
      user: authenticatedUser,
      displayName: 'Grog',
    );

    final campaignRow = buildCampaignRow(
      id: 'camp_123',
      name: 'Lost Mine of Phandelver',
      hexId: 'abc12345',
    );
    final characterRow = buildCharacterRow(
      id: 'char_123',
      name: 'Grog Strongjaw',
    );

    // Stub for campaign search by hexId
    when(
      () => mockTablesDb.listRows(
        databaseId: any(named: 'databaseId'),
        tableId: 'campaigns',
        queries: any(named: 'queries'),
      ),
    ).thenAnswer(
      (_) async => models.RowList.fromMap({
        'total': 1,
        'rows': [campaignRow.toMap()..['\$id'] = 'camp_123'],
      }),
    );

    // Stub for character fetch
    when(
      () => mockTablesDb.listRows(
        databaseId: any(named: 'databaseId'),
        tableId: 'characters',
        queries: any(named: 'queries'),
      ),
    ).thenAnswer(
      (_) async => models.RowList.fromMap({
        'total': 1,
        'rows': [characterRow.toMap()..['\$id'] = 'char_123'],
      }),
    );

    // Stub for campaign members list (to check if already joined)
    when(
      () => mockTablesDb.listRows(
        databaseId: any(named: 'databaseId'),
        tableId: 'campaign_members',
        queries: any(named: 'queries'),
      ),
    ).thenAnswer(
      (_) async => models.RowList.fromMap({
        'total': 0,
        'rows': <Map<String, dynamic>>[],
      }),
    );

    // Stub for creating campaign member row
    when(
      () => mockTablesDb.createRow(
        databaseId: any(named: 'databaseId'),
        tableId: 'campaign_members',
        rowId: any(named: 'rowId'),
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => models.Row.fromMap({
        '\$id': 'member_new',
        '\$tableId': 'campaign_members',
        '\$databaseId': 'main',
        '\$createdAt': '',
        '\$updatedAt': '',
        '\$permissions': <String>[],
        '\$sequence': 0,
        'campaignId': 'camp_123',
        'userId': 'user_123',
        'role': 'player',
        'joinedAt': DateTime.now().toIso8601String(),
      }),
    );

    final router = GoRouter(
      initialLocation: '/join',
      routes: [
        GoRoute(
          path: '/join',
          builder: (context, state) => const JoinCampaignScreen(),
        ),
        GoRoute(
          path: '/campaigns/:hexId',
          builder: (context, state) => const Scaffold(body: Text('Dashboard')),
        ),
      ],
    );

    // Build the widget
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
          appwriteRealtimeProvider.overrideWithValue(mockRealtime),
          authProvider.overrideWith(() => FakeAuthNotifier(authenticatedState)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    // Verify initial state
    expect(find.byKey(const Key('hex_id_field')), findsOneWidget);
    expect(find.byKey(const Key('search_campaign_button')), findsOneWidget);

    // Enter hexId code
    await tester.enterText(find.byKey(const Key('hex_id_field')), 'abc12345');
    await tester.tap(find.byKey(const Key('search_campaign_button')));
    await tester.pumpAndSettle();

    // Verify campaign details are displayed
    expect(find.text('Lost Mine of Phandelver'), findsOneWidget);

    // Verify character is listed
    expect(find.text('Grog Strongjaw'), findsOneWidget);

    // Select character
    await tester.tap(find.text('Grog Strongjaw'));
    await tester.pumpAndSettle();

    // Tap Join button
    expect(
      find.byKey(const Key('join_campaign_submit_button')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('join_campaign_submit_button')));
    await tester.pumpAndSettle();
  });
}
