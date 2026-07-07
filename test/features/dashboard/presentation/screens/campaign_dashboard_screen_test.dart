import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/campaigns/domain/campaign.dart';
import 'package:ilithid/features/campaigns/domain/campaign_member.dart';
import 'package:ilithid/features/campaigns/domain/user_campaign.dart';
import 'package:ilithid/features/campaigns/presentation/providers/campaigns_provider.dart';
import 'package:ilithid/features/campaigns/presentation/providers/campaigns_state.dart';
import 'package:ilithid/features/characters/domain/character.dart';
import 'package:ilithid/features/characters/presentation/providers/characters_provider.dart';
import 'package:ilithid/features/characters/presentation/providers/characters_state.dart';
import 'package:ilithid/features/dashboard/presentation/screens/campaign_dashboard_screen.dart';
import 'package:ilithid/features/sessions/presentation/providers/sessions_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MockTablesDB extends Mock implements TablesDB {}

class MockRealtime extends Mock implements Realtime {}

class MockRealtimeSubscription extends Mock implements RealtimeSubscription {}

class FakeAuthNotifier extends AuthNotifier {
  final AuthState _initialState;
  FakeAuthNotifier(this._initialState);
  @override
  AuthState build() => _initialState;
}

class FakeCampaignsNotifier extends CampaignsNotifier {
  final CampaignsState _initialState;
  final CampaignMember? _mockMember;

  FakeCampaignsNotifier(this._initialState, this._mockMember);

  @override
  CampaignsState build() {
    return _initialState;
  }

  @override
  Future<CampaignMember?> checkMembership(String campaignId) async {
    return _mockMember;
  }

  @override
  Future<bool> updateActiveCharacter({
    required String campaignId,
    required String? activeCharacterId,
  }) async {
    return true;
  }
}

class FakeCharactersNotifier extends CharactersNotifier {
  final CharactersState _initialState;
  FakeCharactersNotifier(this._initialState);
  @override
  CharactersState build() => _initialState;
}

void main() {
  late MockTablesDB mockTablesDb;
  late MockRealtime mockRealtime;
  late MockRealtimeSubscription mockRealtimeSubscription;

  final authUser = models.User.fromMap({
    '\$id': 'user_123',
    '\$createdAt': '',
    '\$updatedAt': '',
    'name': 'Grog',
    'email': 'grog@vox.com',
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

  final authState = AuthState(
    status: AuthStatus.authenticated,
    user: authUser,
    displayName: 'Grog',
  );

  final campaign = Campaign(
    id: 'camp_123',
    hexId: 'abc12345',
    name: 'Lost Mine of Phandelver',
    gmUserId: 'gm_456',
    status: 'active',
    createdAt: DateTime.now(),
  );

  final mockCharacter = Character(
    id: 'char_789',
    userId: 'user_123',
    name: 'Grog Strongjaw',
    hpCurrent: 120,
    hpMax: 120,
    ac: 17,
    createdAt: DateTime.now(),
  );

  models.Row buildSessionRow({
    required String id,
    required String campaignId,
    required String status,
    DateTime? startedAt,
    DateTime? endedAt,
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
      'startedAt': (startedAt ?? DateTime.now()).toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
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

  testWidgets(
    'CampaignDashboardScreen renders correctly as Player and shows Active Character card',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final campaignsState = CampaignsState.success([
        UserCampaign(campaign: campaign, role: 'player'),
      ]);

      final charactersState = CharactersState.success([mockCharacter]);

      final member = CampaignMember(
        id: 'member_111',
        campaignId: 'camp_123',
        userId: 'user_123',
        activeCharacterId: 'char_789',
        role: 'player',
        joinedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
            appwriteRealtimeProvider.overrideWithValue(mockRealtime),
            authProvider.overrideWith(() => FakeAuthNotifier(authState)),
            campaignsProvider.overrideWith(
              () => FakeCampaignsNotifier(campaignsState, member),
            ),
            charactersProvider.overrideWith(
              () => FakeCharactersNotifier(charactersState),
            ),
          ],
          child: const MaterialApp(
            home: CampaignDashboardScreen(hexId: 'abc12345'),
          ),
        ),
      );

      await tester.pump(); // Start fetching
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Lost Mine of Phandelver'), findsWidgets);
      expect(find.text('JOGADOR'), findsOneWidget);
      expect(find.text('Grog Strongjaw'), findsOneWidget);
      expect(find.text('HP Máx: 120 | CA: 17'), findsOneWidget);
      expect(
        find.byKey(const Key('change_active_char_button')),
        findsOneWidget,
      );

      // Verify tabs exist
      expect(find.byKey(const Key('tab_general')), findsOneWidget);
      expect(find.byKey(const Key('tab_sessions')), findsOneWidget);

      // Switch tab to Sessions
      await tester.tap(find.byKey(const Key('tab_sessions')));
      await tester.pumpAndSettle();

      expect(
        find.text('Nenhuma sessão registrada nesta campanha.'),
        findsOneWidget,
      );

      // Switch back to General
      await tester.tap(find.byKey(const Key('tab_general')));
      await tester.pumpAndSettle();

      // Tap share button
      await tester.tap(find.byKey(const Key('dashboard_share_button')));
      await tester.pumpAndSettle();

      expect(find.text('Compartilhar Campanha'), findsWidgets);
      expect(find.byType(QrImageView), findsOneWidget);
    },
  );

  testWidgets(
    'CampaignDashboardScreen renders list of sessions in Sessões tab',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      final activeRow = buildSessionRow(
        id: 'sess_active',
        campaignId: 'camp_123',
        status: 'active',
        startedAt: now,
      );
      final finishedRow = buildSessionRow(
        id: 'sess_finished',
        campaignId: 'camp_123',
        status: 'finished',
        startedAt: now.subtract(const Duration(hours: 2)),
        endedAt: now.subtract(const Duration(hours: 1)),
      );

      when(
        () => mockTablesDb.listRows(
          databaseId: any(named: 'databaseId'),
          tableId: any(named: 'tableId'),
          queries: any(named: 'queries'),
        ),
      ).thenAnswer(
        (_) async => models.RowList.fromMap({
          'total': 2,
          'rows': [activeRow.toMap(), finishedRow.toMap()],
        }),
      );

      final campaignsState = CampaignsState.success([
        UserCampaign(campaign: campaign, role: 'player'),
      ]);

      final charactersState = CharactersState.success([mockCharacter]);

      final member = CampaignMember(
        id: 'member_111',
        campaignId: 'camp_123',
        userId: 'user_123',
        activeCharacterId: 'char_789',
        role: 'player',
        joinedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
            appwriteRealtimeProvider.overrideWithValue(mockRealtime),
            authProvider.overrideWith(() => FakeAuthNotifier(authState)),
            campaignsProvider.overrideWith(
              () => FakeCampaignsNotifier(campaignsState, member),
            ),
            charactersProvider.overrideWith(
              () => FakeCharactersNotifier(charactersState),
            ),
          ],
          child: const MaterialApp(
            home: CampaignDashboardScreen(hexId: 'abc12345'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the Sessões tab
      await tester.tap(find.byKey(const Key('tab_sessions')));
      await tester.pumpAndSettle();

      // Check both sessions are rendered
      expect(find.byKey(const Key('session_card_sess_active')), findsOneWidget);
      expect(
        find.byKey(const Key('session_card_sess_finished')),
        findsOneWidget,
      );
      expect(find.text('Sessão Ativa'), findsOneWidget);
      expect(find.text('Sessão Finalizada'), findsOneWidget);
    },
  );

  testWidgets(
    'CampaignDashboardScreen renders Encerrar Sessão button for GM and triggers confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      final activeRow = buildSessionRow(
        id: 'sess_active',
        campaignId: 'camp_123',
        status: 'active',
        startedAt: now,
      );

      when(
        () => mockTablesDb.listRows(
          databaseId: any(named: 'databaseId'),
          tableId: any(named: 'tableId'),
          queries: any(named: 'queries'),
        ),
      ).thenAnswer(
        (_) async => models.RowList.fromMap({
          'total': 1,
          'rows': [activeRow.toMap()],
        }),
      );

      final finishedRow = buildSessionRow(
        id: 'sess_active',
        campaignId: 'camp_123',
        status: 'finished',
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 30)),
      );

      when(
        () => mockTablesDb.updateRow(
          databaseId: any(named: 'databaseId'),
          tableId: any(named: 'tableId'),
          rowId: 'sess_active',
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => finishedRow);

      final campaignsState = CampaignsState.success([
        UserCampaign(campaign: campaign, role: 'gm'),
      ]);

      final charactersState = CharactersState.success(const []);

      final member = CampaignMember(
        id: 'member_gm',
        campaignId: 'camp_123',
        userId: 'user_123',
        activeCharacterId: null,
        role: 'gm',
        joinedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
            appwriteRealtimeProvider.overrideWithValue(mockRealtime),
            authProvider.overrideWith(() => FakeAuthNotifier(authState)),
            campaignsProvider.overrideWith(
              () => FakeCampaignsNotifier(campaignsState, member),
            ),
            charactersProvider.overrideWith(
              () => FakeCharactersNotifier(charactersState),
            ),
          ],
          child: const MaterialApp(
            home: CampaignDashboardScreen(hexId: 'abc12345'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // GM sees end_session_button
      expect(find.byKey(const Key('end_session_button')), findsOneWidget);

      // Tap to trigger confirmation modal
      await tester.tap(find.byKey(const Key('end_session_button')));
      await tester.pumpAndSettle();

      // Dialog is shown
      expect(find.text('Encerrar Sessão'), findsWidgets);
      expect(
        find.text(
          'Tem certeza que deseja encerrar a sessão ativa? Esta ação é irreversível.',
        ),
        findsOneWidget,
      );

      // When we confirm, stub listRows to return empty active sessions
      when(
        () => mockTablesDb.listRows(
          databaseId: any(named: 'databaseId'),
          tableId: any(named: 'tableId'),
          queries: any(named: 'queries'),
        ),
      ).thenAnswer(
        (_) async => models.RowList.fromMap({
          'total': 1,
          'rows': [finishedRow.toMap()],
        }),
      );

      // Tap confirm button
      await tester.tap(find.byKey(const Key('confirm_end_session_button')));
      await tester.pumpAndSettle();

      // Toast is shown and modal is closed
      expect(find.text('Sessão encerrada com sucesso!'), findsOneWidget);
    },
  );

  testWidgets(
    'CampaignDashboardScreen renders Finalizar Campanha button for GM and triggers double confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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

      final campaignsState = CampaignsState.success([
        UserCampaign(campaign: campaign, role: 'gm'),
      ]);

      final charactersState = CharactersState.success(const []);

      final member = CampaignMember(
        id: 'member_gm',
        campaignId: 'camp_123',
        userId: 'user_123',
        activeCharacterId: null,
        role: 'gm',
        joinedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
            appwriteRealtimeProvider.overrideWithValue(mockRealtime),
            authProvider.overrideWith(() => FakeAuthNotifier(authState)),
            campaignsProvider.overrideWith(
              () => FakeCampaignsNotifier(campaignsState, member),
            ),
            charactersProvider.overrideWith(
              () => FakeCharactersNotifier(charactersState),
            ),
          ],
          child: const MaterialApp(
            home: CampaignDashboardScreen(hexId: 'abc12345'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // GM sees end_campaign_button
      expect(find.byKey(const Key('end_campaign_button')), findsOneWidget);

      // Tap to trigger first confirmation dialog
      await tester.tap(find.byKey(const Key('end_campaign_button')));
      await tester.pumpAndSettle();

      // First Dialog is shown
      expect(find.text('Finalizar Campanha'), findsWidgets);
      expect(
        find.text(
          'Tem certeza que deseja finalizar esta campanha? Isso impedirá novos logins e sessões.',
        ),
        findsOneWidget,
      );

      // Tap Confirmar to trigger second confirmation dialog
      await tester.tap(
        find.byKey(const Key('confirm_end_campaign_first_button')),
      );
      await tester.pumpAndSettle();

      // Second Dialog is shown
      expect(find.text('AVISO: Ação Irreversível'), findsOneWidget);
      expect(
        find.text(
          'Esta ação é permanente e não poderá ser desfeita. Deseja mesmo finalizar a campanha?',
        ),
        findsOneWidget,
      );

      // Tap Finalizar Permanentemente button
      await tester.tap(
        find.byKey(const Key('confirm_end_campaign_second_button')),
      );
      await tester.pumpAndSettle();
    },
  );
}
