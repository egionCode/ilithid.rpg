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
import 'package:ilithid/features/sessions/presentation/providers/sessions_provider.dart';
import 'package:ilithid/features/sessions/presentation/screens/session_dashboard_screen.dart';
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

class FakeCampaignsNotifier extends CampaignsNotifier {
  final CampaignsState _initialState;
  final CampaignMember? _mockMember;

  FakeCampaignsNotifier(this._initialState, this._mockMember);

  @override
  CampaignsState build() => _initialState;

  @override
  Future<CampaignMember?> checkMembership(String campaignId) async {
    return _mockMember;
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
    r'$id': 'user_123',
    r'$createdAt': '',
    r'$updatedAt': '',
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

  final myCharacter = Character(
    id: 'char_789',
    userId: 'user_123',
    name: 'Grog Strongjaw',
    hpCurrent: 80,
    hpMax: 120,
    ac: 17,
    createdAt: DateTime.now(),
  );

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

    // Default: empty lists for campaign_members / npc_instances queries.
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

  Widget buildTestWidget({required CampaignMember member}) {
    return ProviderScope(
      overrides: [
        appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
        realtimeClientProvider.overrideWithValue(mockRealtime),
        appwriteRealtimeProvider.overrideWithValue(mockRealtime),
        authProvider.overrideWith(() => FakeAuthNotifier(authState)),
        campaignsProvider.overrideWith(
          () => FakeCampaignsNotifier(
            CampaignsState.success([
              UserCampaign(campaign: campaign, role: member.role),
            ]),
            member,
          ),
        ),
        charactersProvider.overrideWith(
          () => FakeCharactersNotifier(CharactersState.success([myCharacter])),
        ),
      ],
      child: const MaterialApp(
        home: SessionDashboardScreen(hexId: 'abc12345', sessionId: 'session_1'),
      ),
    );
  }

  testWidgets('shows Minha Ficha with own active character HP', (tester) async {
    final member = CampaignMember(
      id: 'member_1',
      campaignId: 'camp_123',
      userId: 'user_123',
      activeCharacterId: 'char_789',
      role: 'player',
      joinedAt: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(member: member));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Minha Ficha'), findsOneWidget);
    expect(find.text('Grog Strongjaw'), findsOneWidget);
    expect(find.text('80 / 120 HP'), findsOneWidget);
    expect(
      find.byKey(const Key('my_character_combat_action_char_789')),
      findsOneWidget,
    );

    // A regular player must not see the GM party management section.
    expect(find.text('Jogadores'), findsNothing);
  });

  testWidgets('GM sees the Jogadores section', (tester) async {
    final gmMember = CampaignMember(
      id: 'member_1',
      campaignId: 'camp_123',
      userId: 'user_123',
      activeCharacterId: 'char_789',
      role: 'gm',
      joinedAt: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(member: gmMember));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Jogadores'), findsOneWidget);
  });

  testWidgets('player sees companions in Grupo with read-only HP', (
    tester,
  ) async {
    final member = CampaignMember(
      id: 'member_1',
      campaignId: 'camp_123',
      userId: 'user_123',
      activeCharacterId: 'char_789',
      role: 'player',
      joinedAt: DateTime.now(),
    );

    final companionMemberRow = models.Row.fromMap({
      r'$id': 'member_2',
      r'$tableId': appwriteCampaignMembersTableId,
      r'$databaseId': appwriteDatabaseId,
      r'$createdAt': '',
      r'$updatedAt': '',
      r'$permissions': <String>[],
      r'$sequence': 0,
      'campaignId': 'camp_123',
      'userId': 'user_456',
      'activeCharacterId': 'char_456',
      'role': 'player',
      'joinedAt': DateTime.now().toIso8601String(),
    });

    final companionCharacterRow = models.Row.fromMap({
      r'$id': 'char_456',
      r'$tableId': appwriteCharactersTableId,
      r'$databaseId': appwriteDatabaseId,
      r'$createdAt': '',
      r'$updatedAt': '',
      r'$permissions': <String>[],
      r'$sequence': 0,
      'userId': 'user_456',
      'name': 'Vex Vaneth',
      'hpCurrent': 40,
      'hpMax': 60,
      'hpTemp': 0,
      'ac': 15,
      'sourceSystem': 'manual',
      'createdAt': DateTime.now().toIso8601String(),
    });

    when(
      () => mockTablesDb.listRows(
        databaseId: any(named: 'databaseId'),
        tableId: any(named: 'tableId'),
        queries: any(named: 'queries'),
      ),
    ).thenAnswer((invocation) async {
      final tableId =
          invocation.namedArguments[const Symbol('tableId')] as String;
      if (tableId == appwriteCampaignMembersTableId) {
        return models.RowList.fromMap({
          'total': 1,
          'rows': [companionMemberRow.toMap()],
        });
      }
      if (tableId == appwriteCharactersTableId) {
        return models.RowList.fromMap({
          'total': 1,
          'rows': [companionCharacterRow.toMap()],
        });
      }
      return models.RowList.fromMap({
        'total': 0,
        'rows': <Map<String, dynamic>>[],
      });
    });

    await tester.pumpWidget(buildTestWidget(member: member));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Grupo'), findsOneWidget);
    expect(find.text('Vex Vaneth'), findsOneWidget);
    expect(find.text('40 / 60 HP'), findsOneWidget);
  });
}
