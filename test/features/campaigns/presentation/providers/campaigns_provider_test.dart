import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/campaigns/presentation/providers/campaigns_provider.dart';
import 'package:ilithid/features/campaigns/presentation/providers/campaigns_state.dart';
import 'package:ilithid/features/sessions/presentation/providers/sessions_provider.dart';
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
  late ProviderContainer container;

  /// Helper to mock a Campaign Row.
  models.Row buildCampaignRow({
    required String id,
    required String name,
    required String hexId,
    required String gmUserId,
    String status = 'active',
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
      'gmUserId': gmUserId,
      'status': status,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Helper to mock a CampaignMember Row.
  models.Row buildMemberRow({
    required String id,
    required String campaignId,
    required String userId,
    String role = 'gm',
  }) {
    return models.Row.fromMap({
      '\$id': id,
      '\$tableId': 'campaign_members',
      '\$databaseId': 'main',
      '\$createdAt': '',
      '\$updatedAt': '',
      '\$permissions': <String>[],
      '\$sequence': 0,
      'campaignId': campaignId,
      'userId': userId,
      'role': role,
      'joinedAt': DateTime.now().toIso8601String(),
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

    // Register default stub to prevent type errors on automatic reactive fetches
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

  group('CampaignsNotifier Tests', () {
    test('createCampaign should fail if user is not authenticated', () async {
      final guestState = AuthState.unauthenticated();
      container = ProviderContainer(
        overrides: [
          appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
          appwriteRealtimeProvider.overrideWithValue(mockRealtime),
          authProvider.overrideWith(() => FakeAuthNotifier(guestState)),
        ],
      );

      final result = await container
          .read(campaignsProvider.notifier)
          .createCampaign('Curse of Strahd');

      expect(result, isNull);
      final state = container.read(campaignsProvider);
      expect(state.status, equals(CampaignsStatus.error));
      expect(state.errorMessage, contains('User must be logged in'));
    });

    test(
      'createCampaign should succeed and save campaign & gm member',
      () async {
        final mockUser = models.User.fromMap({
          '\$id': 'user_gm_123',
          '\$createdAt': '',
          '\$updatedAt': '',
          'name': 'Garen',
          'email': 'garen@demacia.com',
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
        final authenticatedState = AuthState.authenticated(mockUser, 'Garen');

        container = ProviderContainer(
          overrides: [
            appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
            appwriteRealtimeProvider.overrideWithValue(mockRealtime),
            authProvider.overrideWith(
              () => FakeAuthNotifier(authenticatedState),
            ),
          ],
        );

        when(
          () => mockTablesDb.createRow(
            databaseId: any(named: 'databaseId'),
            tableId: appwriteCampaignsTableId,
            rowId: any(named: 'rowId'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((invocation) async {
          final data = invocation.namedArguments[#data] as Map;
          return buildCampaignRow(
            id: invocation.namedArguments[#rowId] as String,
            name: data['name'] as String,
            hexId: data['hexId'] as String,
            gmUserId: data['gmUserId'] as String,
          );
        });

        when(
          () => mockTablesDb.createRow(
            databaseId: any(named: 'databaseId'),
            tableId: appwriteCampaignMembersTableId,
            rowId: any(named: 'rowId'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((invocation) async {
          final data = invocation.namedArguments[#data] as Map;
          return buildMemberRow(
            id: invocation.namedArguments[#rowId] as String,
            campaignId: data['campaignId'] as String,
            userId: data['userId'] as String,
          );
        });

        // Allow the automatic reactive fetch to complete first
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final campaign = await container
            .read(campaignsProvider.notifier)
            .createCampaign('Phandelver');

        expect(campaign, isNotNull);
        expect(campaign!.name, equals('Phandelver'));
        expect(campaign.gmUserId, equals('user_gm_123'));
        expect(campaign.hexId.length, equals(8));

        final state = container.read(campaignsProvider);
        expect(state.status, equals(CampaignsStatus.success));
        expect(state.newCampaign, equals(campaign));
        expect(state.campaigns.length, equals(1));
        expect(state.campaigns.first.campaign, equals(campaign));
        expect(state.campaigns.first.role, equals('gm'));

        verify(
          () => mockTablesDb.createRow(
            databaseId: any(named: 'databaseId'),
            tableId: appwriteCampaignsTableId,
            rowId: any(named: 'rowId'),
            data: any(named: 'data'),
          ),
        ).called(1);

        verify(
          () => mockTablesDb.createRow(
            databaseId: any(named: 'databaseId'),
            tableId: appwriteCampaignMembersTableId,
            rowId: any(named: 'rowId'),
            data: any(named: 'data'),
          ),
        ).called(1);
      },
    );

    test('createCampaign should fail and handle Appwrite exception', () async {
      final mockUser = models.User.fromMap({
        '\$id': 'user_gm_123',
        '\$createdAt': '',
        '\$updatedAt': '',
        'name': 'Garen',
        'email': 'garen@demacia.com',
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
      final authenticatedState = AuthState.authenticated(mockUser, 'Garen');

      container = ProviderContainer(
        overrides: [
          appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
          appwriteRealtimeProvider.overrideWithValue(mockRealtime),
          authProvider.overrideWith(() => FakeAuthNotifier(authenticatedState)),
        ],
      );

      when(
        () => mockTablesDb.createRow(
          databaseId: any(named: 'databaseId'),
          tableId: any(named: 'tableId'),
          rowId: any(named: 'rowId'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) =>
            Future<models.Row>.error(AppwriteException('Database error', 500)),
      );

      // Allow the automatic reactive fetch to complete first
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final result = await container
          .read(campaignsProvider.notifier)
          .createCampaign('Phandelver');

      expect(result, isNull);
      final state = container.read(campaignsProvider);
      expect(state.status, equals(CampaignsStatus.error));
      expect(state.errorMessage, equals('Database error'));
    });

    test('fetchCampaigns should succeed and load user campaigns', () async {
      final mockUser = models.User.fromMap({
        '\$id': 'user_gm_123',
        '\$createdAt': '',
        '\$updatedAt': '',
        'name': 'Garen',
        'email': 'garen@demacia.com',
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
      final authenticatedState = AuthState.authenticated(mockUser, 'Garen');

      container = ProviderContainer(
        overrides: [
          appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
          appwriteRealtimeProvider.overrideWithValue(mockRealtime),
          authProvider.overrideWith(() => FakeAuthNotifier(authenticatedState)),
        ],
      );

      // Mock listRows to return one member row
      when(
        () => mockTablesDb.listRows(
          databaseId: any(named: 'databaseId'),
          tableId: appwriteCampaignMembersTableId,
          queries: any(named: 'queries'),
        ),
      ).thenAnswer(
        (_) async => models.RowList.fromMap({
          'total': 1,
          'rows': [
            buildMemberRow(
              id: 'member_123',
              campaignId: 'campaign_abc',
              userId: 'user_gm_123',
            ).toMap(),
          ],
        }),
      );

      // Mock getRow to return the campaign row
      when(
        () => mockTablesDb.getRow(
          databaseId: any(named: 'databaseId'),
          tableId: appwriteCampaignsTableId,
          rowId: 'campaign_abc',
        ),
      ).thenAnswer(
        (_) async => buildCampaignRow(
          id: 'campaign_abc',
          name: 'Phandelver',
          hexId: 'abc12345',
          gmUserId: 'user_gm_123',
        ),
      );

      await container.read(campaignsProvider.notifier).fetchCampaigns();

      final state = container.read(campaignsProvider);
      expect(state.status, equals(CampaignsStatus.success));
      expect(state.campaigns.length, equals(1));
      expect(state.campaigns.first.campaign.name, equals('Phandelver'));
      expect(state.campaigns.first.role, equals('gm'));
    });

    test(
      'fetchCampaigns should skip corrupted campaign references gracefully',
      () async {
        final mockUser = models.User.fromMap({
          '\$id': 'user_gm_123',
          '\$createdAt': '',
          '\$updatedAt': '',
          'name': 'Garen',
          'email': 'garen@demacia.com',
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
        final authenticatedState = AuthState.authenticated(mockUser, 'Garen');

        container = ProviderContainer(
          overrides: [
            appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
            appwriteRealtimeProvider.overrideWithValue(mockRealtime),
            authProvider.overrideWith(
              () => FakeAuthNotifier(authenticatedState),
            ),
          ],
        );

        // Mock listRows to return two membership rows
        when(
          () => mockTablesDb.listRows(
            databaseId: any(named: 'databaseId'),
            tableId: appwriteCampaignMembersTableId,
            queries: any(named: 'queries'),
          ),
        ).thenAnswer(
          (_) async => models.RowList.fromMap({
            'total': 2,
            'rows': [
              buildMemberRow(
                id: 'member_1',
                campaignId: 'campaign_valid',
                userId: 'user_gm_123',
              ).toMap(),
              buildMemberRow(
                id: 'member_2',
                campaignId: 'campaign_corrupt',
                userId: 'user_gm_123',
              ).toMap(),
            ],
          }),
        );

        // Mock getRow for valid campaign
        when(
          () => mockTablesDb.getRow(
            databaseId: any(named: 'databaseId'),
            tableId: appwriteCampaignsTableId,
            rowId: 'campaign_valid',
          ),
        ).thenAnswer(
          (_) async => buildCampaignRow(
            id: 'campaign_valid',
            hexId: 'valid123',
            name: 'Valid Campaign',
            gmUserId: 'user_gm_123',
          ),
        );

        // Mock getRow for corrupt campaign to throw exception
        when(
          () => mockTablesDb.getRow(
            databaseId: any(named: 'databaseId'),
            tableId: appwriteCampaignsTableId,
            rowId: 'campaign_corrupt',
          ),
        ).thenThrow(AppwriteException('Campaign not found', 404));

        await container.read(campaignsProvider.notifier).fetchCampaigns();

        final state = container.read(campaignsProvider);
        expect(state.status, equals(CampaignsStatus.success));
        expect(state.campaigns.length, equals(1));
        expect(state.campaigns.first.campaign.id, equals('campaign_valid'));
      },
    );

    test(
      'fetchCampaigns should handle list failure and report error',
      () async {
        final mockUser = models.User.fromMap({
          '\$id': 'user_gm_123',
          '\$createdAt': '',
          '\$updatedAt': '',
          'name': 'Garen',
          'email': 'garen@demacia.com',
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
        final authenticatedState = AuthState.authenticated(mockUser, 'Garen');

        container = ProviderContainer(
          overrides: [
            appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
            appwriteRealtimeProvider.overrideWithValue(mockRealtime),
            authProvider.overrideWith(
              () => FakeAuthNotifier(authenticatedState),
            ),
          ],
        );

        when(
          () => mockTablesDb.listRows(
            databaseId: any(named: 'databaseId'),
            tableId: appwriteCampaignMembersTableId,
            queries: any(named: 'queries'),
          ),
        ).thenThrow(AppwriteException('Network Timeout', 408));

        await container.read(campaignsProvider.notifier).fetchCampaigns();

        final state = container.read(campaignsProvider);
        expect(state.status, equals(CampaignsStatus.error));
        expect(state.errorMessage, equals('Network Timeout'));
      },
    );

    test(
      'endCampaign should update status of campaign to finished and end active session',
      () async {
        final mockUser = models.User.fromMap({
          '\$id': 'user_gm_123',
          '\$createdAt': '',
          '\$updatedAt': '',
          'name': 'Garen',
          'email': 'garen@demacia.com',
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
        final authenticatedState = AuthState.authenticated(mockUser, 'Garen');

        container = ProviderContainer(
          overrides: [
            appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
            appwriteRealtimeProvider.overrideWithValue(mockRealtime),
            authProvider.overrideWith(
              () => FakeAuthNotifier(authenticatedState),
            ),
          ],
        );

        final finishedCampaignRow = buildCampaignRow(
          id: 'campaign_abc',
          name: 'Phandelver',
          hexId: 'abc12345',
          gmUserId: 'user_gm_123',
          status: 'finished',
        );

        // Stub updateRow for campaigns table
        when(
          () => mockTablesDb.updateRow(
            databaseId: any(named: 'databaseId'),
            tableId: appwriteCampaignsTableId,
            rowId: 'campaign_abc',
            data: {'status': 'finished'},
          ),
        ).thenAnswer((_) async => finishedCampaignRow);

        // Stub listRows for active sessions
        final activeSessionRow = models.Row.fromMap({
          '\$id': 'sess_123',
          '\$tableId': 'sessions',
          '\$databaseId': 'main',
          '\$createdAt': '',
          '\$updatedAt': '',
          '\$permissions': <String>[],
          '\$sequence': 0,
          'campaignId': 'campaign_abc',
          'status': 'active',
          'startedAt': DateTime.now().toIso8601String(),
          'endedAt': null,
        });

        when(
          () => mockTablesDb.listRows(
            databaseId: any(named: 'databaseId'),
            tableId: appwriteSessionsTableId,
            queries: any(named: 'queries'),
          ),
        ).thenAnswer(
          (_) async => models.RowList.fromMap({
            'total': 1,
            'rows': [activeSessionRow.toMap()],
          }),
        );

        // Stub updateRow for sessions table
        final finishedSessionRow = models.Row.fromMap({
          ...activeSessionRow.toMap(),
          'status': 'finished',
          'endedAt': DateTime.now().toIso8601String(),
        });

        when(
          () => mockTablesDb.updateRow(
            databaseId: any(named: 'databaseId'),
            tableId: appwriteSessionsTableId,
            rowId: 'sess_123',
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => finishedSessionRow);

        // Stub fetchCampaigns calls: listRows and getRow
        when(
          () => mockTablesDb.listRows(
            databaseId: any(named: 'databaseId'),
            tableId: appwriteCampaignMembersTableId,
            queries: any(named: 'queries'),
          ),
        ).thenAnswer(
          (_) async => models.RowList.fromMap({
            'total': 1,
            'rows': [
              buildMemberRow(
                id: 'member_123',
                campaignId: 'campaign_abc',
                userId: 'user_gm_123',
              ).toMap(),
            ],
          }),
        );

        when(
          () => mockTablesDb.getRow(
            databaseId: any(named: 'databaseId'),
            tableId: appwriteCampaignsTableId,
            rowId: 'campaign_abc',
          ),
        ).thenAnswer((_) async => finishedCampaignRow);

        // Allow automatic reactive fetch to complete first
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final success = await container
            .read(campaignsProvider.notifier)
            .endCampaign('campaign_abc');
        expect(success, isTrue);

        final state = container.read(campaignsProvider);
        expect(state.status, equals(CampaignsStatus.success));
        expect(state.campaigns.length, equals(1));
        expect(state.campaigns.first.campaign.status, equals('finished'));

        verify(
          () => mockTablesDb.updateRow(
            databaseId: any(named: 'databaseId'),
            tableId: appwriteCampaignsTableId,
            rowId: 'campaign_abc',
            data: {'status': 'finished'},
          ),
        ).called(1);

        verify(
          () => mockTablesDb.updateRow(
            databaseId: any(named: 'databaseId'),
            tableId: appwriteSessionsTableId,
            rowId: 'sess_123',
            data: any(named: 'data'),
          ),
        ).called(1);
      },
    );

    group('Verification Matchers', () {
      test('fake match registration for eq', () {});
    });

    group('transferGm', () {
      final gmUser = models.User.fromMap({
        '\$id': 'gm-id',
        '\$createdAt': '',
        '\$updatedAt': '',
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

      ProviderContainer buildContainer() {
        return ProviderContainer(
          overrides: [
            appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
            appwriteRealtimeProvider.overrideWithValue(mockRealtime),
            authProvider.overrideWith(
              () => FakeAuthNotifier(AuthState.authenticated(gmUser, 'GM')),
            ),
          ],
        );
      }

      test('updates campaigns.gmUserId and both members\' roles', () async {
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
              buildMemberRow(
                id: 'member-gm',
                campaignId: 'campaign-1',
                userId: 'gm-id',
                role: 'gm',
              ),
              buildMemberRow(
                id: 'member-player',
                campaignId: 'campaign-1',
                userId: 'player-id',
                role: 'player',
              ),
            ],
          ),
        );

        when(
          () => mockTablesDb.updateRow(
            databaseId: any(named: 'databaseId'),
            tableId: any(named: 'tableId'),
            rowId: any(named: 'rowId'),
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) async => buildCampaignRow(
            id: 'campaign-1',
            name: 'Test',
            hexId: 'abc123',
            gmUserId: 'player-id',
          ),
        );

        container = buildContainer();

        final result = await container
            .read(campaignsProvider.notifier)
            .transferGm(campaignId: 'campaign-1', newGmUserId: 'player-id');

        expect(result, isTrue);

        verify(
          () => mockTablesDb.updateRow(
            databaseId: appwriteDatabaseId,
            tableId: appwriteCampaignsTableId,
            rowId: 'campaign-1',
            data: {'gmUserId': 'player-id'},
          ),
        ).called(1);

        verify(
          () => mockTablesDb.updateRow(
            databaseId: appwriteDatabaseId,
            tableId: appwriteCampaignMembersTableId,
            rowId: 'member-gm',
            data: {'role': 'player'},
          ),
        ).called(1);

        verify(
          () => mockTablesDb.updateRow(
            databaseId: appwriteDatabaseId,
            tableId: appwriteCampaignMembersTableId,
            rowId: 'member-player',
            data: {'role': 'gm'},
          ),
        ).called(1);
      });

      test('fails when the caller is not the current GM', () async {
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
              buildMemberRow(
                id: 'member-gm',
                campaignId: 'campaign-1',
                userId: 'gm-id',
                role: 'player',
              ),
              buildMemberRow(
                id: 'member-player',
                campaignId: 'campaign-1',
                userId: 'player-id',
                role: 'gm',
              ),
            ],
          ),
        );

        container = buildContainer();

        final result = await container
            .read(campaignsProvider.notifier)
            .transferGm(campaignId: 'campaign-1', newGmUserId: 'player-id');

        expect(result, isFalse);
        verifyNever(
          () => mockTablesDb.updateRow(
            databaseId: any(named: 'databaseId'),
            tableId: any(named: 'tableId'),
            rowId: any(named: 'rowId'),
            data: any(named: 'data'),
          ),
        );
      });

      test(
        'rolls back campaigns.gmUserId when demoting the old GM fails',
        () async {
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
                buildMemberRow(
                  id: 'member-gm',
                  campaignId: 'campaign-1',
                  userId: 'gm-id',
                  role: 'gm',
                ),
                buildMemberRow(
                  id: 'member-player',
                  campaignId: 'campaign-1',
                  userId: 'player-id',
                  role: 'player',
                ),
              ],
            ),
          );

          when(
            () => mockTablesDb.updateRow(
              databaseId: appwriteDatabaseId,
              tableId: appwriteCampaignsTableId,
              rowId: 'campaign-1',
              data: any(named: 'data'),
            ),
          ).thenAnswer(
            (_) async => buildCampaignRow(
              id: 'campaign-1',
              name: 'Test',
              hexId: 'abc123',
              gmUserId: 'player-id',
            ),
          );

          when(
            () => mockTablesDb.updateRow(
              databaseId: appwriteDatabaseId,
              tableId: appwriteCampaignMembersTableId,
              rowId: 'member-gm',
              data: any(named: 'data'),
            ),
          ).thenThrow(Exception('network error'));

          container = buildContainer();

          final result = await container
              .read(campaignsProvider.notifier)
              .transferGm(campaignId: 'campaign-1', newGmUserId: 'player-id');

          expect(result, isFalse);

          // gmUserId set to the new GM, then rolled back to the caller.
          verify(
            () => mockTablesDb.updateRow(
              databaseId: appwriteDatabaseId,
              tableId: appwriteCampaignsTableId,
              rowId: 'campaign-1',
              data: any(named: 'data'),
            ),
          ).called(2);

          // Never promoted the new GM, since the demotion step failed first.
          verifyNever(
            () => mockTablesDb.updateRow(
              databaseId: appwriteDatabaseId,
              tableId: appwriteCampaignMembersTableId,
              rowId: 'member-player',
              data: any(named: 'data'),
            ),
          );
        },
      );
    });
  });
}
