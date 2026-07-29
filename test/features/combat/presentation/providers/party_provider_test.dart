import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/combat/presentation/providers/party_provider.dart';
import 'package:ilithid/features/combat/presentation/providers/party_state.dart';
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
  required String campaignId,
  required String userId,
  String? activeCharacterId,
  String role = 'player',
}) {
  return models.Row.fromMap({
    r'$id': id,
    r'$tableId': appwriteCampaignMembersTableId,
    r'$databaseId': appwriteDatabaseId,
    r'$createdAt': '',
    r'$updatedAt': '',
    r'$permissions': <String>[],
    r'$sequence': 0,
    'campaignId': campaignId,
    'userId': userId,
    'activeCharacterId': activeCharacterId,
    'role': role,
    'joinedAt': DateTime.now().toIso8601String(),
  });
}

models.Row _characterRow({required String id, required String name}) {
  return models.Row.fromMap({
    r'$id': id,
    r'$tableId': appwriteCharactersTableId,
    r'$databaseId': appwriteDatabaseId,
    r'$createdAt': '',
    r'$updatedAt': '',
    r'$permissions': <String>[],
    r'$sequence': 0,
    'userId': 'owner',
    'name': name,
    'hpCurrent': 10,
    'hpMax': 10,
    'hpTemp': 0,
    'ac': 12,
    'sourceSystem': 'manual',
    'createdAt': DateTime.now().toIso8601String(),
  });
}

models.User _buildMockUser() {
  return models.User.fromMap({
    r'$id': 'gm-id',
    r'$createdAt': '',
    r'$updatedAt': '',
    'name': 'GM',
    'email': 'gm@example.com',
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

void main() {
  late MockTablesDB mockTablesDb;
  late MockRealtime mockRealtime;
  late MockRealtimeSubscription mockRealtimeSubscription;
  ProviderContainer? container;
  const campaignId = 'campaign-1';

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

  test('merges campaign members with their active characters', () async {
    when(
      () => mockTablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteCampaignMembersTableId,
        queries: any(named: 'queries'),
      ),
    ).thenAnswer(
      (_) async => models.RowList(
        total: 2,
        rows: [
          _memberRow(
            id: 'member-1',
            campaignId: campaignId,
            userId: 'user-1',
            activeCharacterId: 'char-1',
            role: 'gm',
          ),
          _memberRow(id: 'member-2', campaignId: campaignId, userId: 'user-2'),
        ],
      ),
    );

    when(
      () => mockTablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteCharactersTableId,
        queries: any(named: 'queries'),
      ),
    ).thenAnswer(
      (_) async => models.RowList(
        total: 1,
        rows: [_characterRow(id: 'char-1', name: 'Aria')],
      ),
    );

    container = ProviderContainer(
      overrides: [
        appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
        realtimeClientProvider.overrideWithValue(mockRealtime),
        authProvider.overrideWith(
          () =>
              FakeAuthNotifier(AuthState.authenticated(_buildMockUser(), 'GM')),
        ),
      ],
    );

    container!.read(partyProvider(campaignId));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = container!.read(partyProvider(campaignId));
    expect(state.status, PartyStatus.success);
    expect(state.members, hasLength(2));

    final withCharacter = state.members.firstWhere(
      (m) => m.member.id == 'member-1',
    );
    expect(withCharacter.character, isNotNull);
    expect(withCharacter.character!.name, 'Aria');

    final withoutCharacter = state.members.firstWhere(
      (m) => m.member.id == 'member-2',
    );
    expect(withoutCharacter.character, isNull);
  });

  test('reports an error when fetching members fails', () async {
    when(
      () => mockTablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteCampaignMembersTableId,
        queries: any(named: 'queries'),
      ),
    ).thenThrow(Exception('network error'));

    container = ProviderContainer(
      overrides: [
        appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
        realtimeClientProvider.overrideWithValue(mockRealtime),
        authProvider.overrideWith(
          () =>
              FakeAuthNotifier(AuthState.authenticated(_buildMockUser(), 'GM')),
        ),
      ],
    );

    container!.read(partyProvider(campaignId));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = container!.read(partyProvider(campaignId));
    expect(state.status, PartyStatus.error);
  });
}
