import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/npcs/presentation/providers/npc_templates_provider.dart';
import 'package:ilithid/features/npcs/presentation/providers/npc_templates_state.dart';
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

  /// Helper to mock an NPC Template Row.
  models.Row buildNpcTemplateRow({
    required String id,
    required String creatorId,
    required String name,
    required int hpMax,
    required int ac,
    String sourceSystem = 'manual',
    bool isPublic = true,
  }) {
    return models.Row.fromMap({
      '\$id': id,
      '\$tableId': 'npc_templates',
      '\$databaseId': 'main',
      '\$createdAt': '',
      '\$updatedAt': '',
      '\$permissions': <String>[],
      '\$sequence': 0,
      'creatorId': creatorId,
      'name': name,
      'hpMax': hpMax,
      'ac': ac,
      'sourceSystem': sourceSystem,
      'isPublic': isPublic,
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

    // Default profile lookup used when resolving a template creator's name.
    when(
      () => mockTablesDb.getRow(
        databaseId: any(named: 'databaseId'),
        tableId: 'profiles',
        rowId: any(named: 'rowId'),
      ),
    ).thenThrow(Exception('profile not found'));
  });

  tearDown(() {
    container.dispose();
  });

  group('NpcTemplatesNotifier Tests', () {
    test(
      'fetchPublicTemplates should fail if user is not authenticated',
      () async {
        final guestState = AuthState.unauthenticated();
        container = ProviderContainer(
          overrides: [
            appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
            appwriteRealtimeProvider.overrideWithValue(mockRealtime),
            authProvider.overrideWith(() => FakeAuthNotifier(guestState)),
          ],
        );

        final notifier = container.read(npcTemplatesProvider.notifier);
        await notifier.fetchPublicTemplates();

        final state = container.read(npcTemplatesProvider);
        expect(state.status, equals(NpcTemplatesStatus.error));
        expect(state.errorMessage, contains('User must be logged in'));
      },
    );

    test('fetchPublicTemplates should succeed and load templates', () async {
      final authUser = models.User.fromMap({
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
        user: authUser,
        displayName: 'Grog',
      );

      container = ProviderContainer(
        overrides: [
          appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
          appwriteRealtimeProvider.overrideWithValue(mockRealtime),
          authProvider.overrideWith(() => FakeAuthNotifier(authenticatedState)),
        ],
      );

      final npcRow = buildNpcTemplateRow(
        id: 'npc_abc',
        creatorId: 'user_123',
        name: 'Goblin',
        hpMax: 12,
        ac: 13,
      );

      when(
        () => mockTablesDb.listRows(
          databaseId: any(named: 'databaseId'),
          tableId: 'npc_templates',
          queries: any(named: 'queries'),
        ),
      ).thenAnswer(
        (_) async => models.RowList.fromMap({
          'total': 1,
          'rows': [npcRow.toMap()..['\$id'] = 'npc_abc'],
        }),
      );

      final notifier = container.read(npcTemplatesProvider.notifier);
      await notifier.fetchPublicTemplates();

      final state = container.read(npcTemplatesProvider);
      expect(state.status, equals(NpcTemplatesStatus.success));
      expect(state.publicTemplates, hasLength(1));
      expect(state.publicTemplates.first.name, equals('Goblin'));
    });

    test('fetchMyTemplates should filter by creatorId', () async {
      final authUser = models.User.fromMap({
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
        user: authUser,
        displayName: 'Grog',
      );

      container = ProviderContainer(
        overrides: [
          appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
          appwriteRealtimeProvider.overrideWithValue(mockRealtime),
          authProvider.overrideWith(() => FakeAuthNotifier(authenticatedState)),
        ],
      );

      final npcRow = buildNpcTemplateRow(
        id: 'npc_mine',
        creatorId: 'user_123',
        name: 'Bandit Leader',
        hpMax: 20,
        ac: 15,
      );

      when(
        () => mockTablesDb.listRows(
          databaseId: any(named: 'databaseId'),
          tableId: 'npc_templates',
          queries: any(named: 'queries'),
        ),
      ).thenAnswer(
        (_) async => models.RowList.fromMap({
          'total': 1,
          'rows': [npcRow.toMap()..['\$id'] = 'npc_mine'],
        }),
      );

      final notifier = container.read(npcTemplatesProvider.notifier);
      await notifier.fetchMyTemplates();

      final state = container.read(npcTemplatesProvider);
      expect(state.status, equals(NpcTemplatesStatus.success));
      expect(state.myTemplates, hasLength(1));
      expect(state.myTemplates.first.name, equals('Bandit Leader'));
      // fetchMyTemplates must not touch the public list.
      expect(state.publicTemplates, isEmpty);
    });

    test(
      'fetchPublicTemplates resolves creator display names from profiles',
      () async {
        final authUser = models.User.fromMap({
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
          user: authUser,
          displayName: 'Grog',
        );

        container = ProviderContainer(
          overrides: [
            appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
            appwriteRealtimeProvider.overrideWithValue(mockRealtime),
            authProvider.overrideWith(
              () => FakeAuthNotifier(authenticatedState),
            ),
          ],
        );

        final npcRow = buildNpcTemplateRow(
          id: 'npc_abc',
          creatorId: 'creator_456',
          name: 'Goblin',
          hpMax: 12,
          ac: 13,
        );

        when(
          () => mockTablesDb.listRows(
            databaseId: any(named: 'databaseId'),
            tableId: 'npc_templates',
            queries: any(named: 'queries'),
          ),
        ).thenAnswer(
          (_) async => models.RowList.fromMap({
            'total': 1,
            'rows': [npcRow.toMap()..['\$id'] = 'npc_abc'],
          }),
        );

        when(
          () => mockTablesDb.getRow(
            databaseId: any(named: 'databaseId'),
            tableId: 'profiles',
            rowId: 'creator_456',
          ),
        ).thenAnswer(
          (_) async => models.Row.fromMap({
            '\$id': 'creator_456',
            '\$tableId': 'profiles',
            '\$databaseId': 'main',
            '\$createdAt': '',
            '\$updatedAt': '',
            '\$permissions': <String>[],
            '\$sequence': 0,
            'displayName': 'Percy',
          }),
        );

        final notifier = container.read(npcTemplatesProvider.notifier);
        await notifier.fetchPublicTemplates();

        final state = container.read(npcTemplatesProvider);
        expect(state.creatorNames['creator_456'], equals('Percy'));
      },
    );

    test('createNpcTemplate should create template successfully', () async {
      final authUser = models.User.fromMap({
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
        user: authUser,
        displayName: 'Grog',
      );

      container = ProviderContainer(
        overrides: [
          appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
          appwriteRealtimeProvider.overrideWithValue(mockRealtime),
          authProvider.overrideWith(() => FakeAuthNotifier(authenticatedState)),
        ],
      );

      final npcRow = buildNpcTemplateRow(
        id: 'npc_abc',
        creatorId: 'user_123',
        name: 'Orc',
        hpMax: 15,
        ac: 14,
        sourceSystem: 'dnd5e',
      );

      when(
        () => mockTablesDb.createRow(
          databaseId: any(named: 'databaseId'),
          tableId: 'npc_templates',
          rowId: any(named: 'rowId'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => npcRow..data['\$id'] = 'npc_abc');

      final notifier = container.read(npcTemplatesProvider.notifier);
      final newNpc = await notifier.createNpcTemplate(
        'Orc',
        15,
        14,
        sourceSystem: 'dnd5e',
      );

      expect(newNpc, isNotNull);
      expect(newNpc!.name, equals('Orc'));
      expect(newNpc.hpMax, equals(15));
      expect(newNpc.ac, equals(14));
      expect(newNpc.sourceSystem, equals('dnd5e'));

      final state = container.read(npcTemplatesProvider);
      expect(state.myTemplates, contains(newNpc));
      expect(state.publicTemplates, contains(newNpc));
      expect(state.creatorNames['user_123'], equals('Grog'));
    });

    test(
      'createNpcTemplate should not add private templates to the public list',
      () async {
        final authUser = models.User.fromMap({
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
          user: authUser,
          displayName: 'Grog',
        );

        container = ProviderContainer(
          overrides: [
            appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
            appwriteRealtimeProvider.overrideWithValue(mockRealtime),
            authProvider.overrideWith(
              () => FakeAuthNotifier(authenticatedState),
            ),
          ],
        );

        final npcRow = buildNpcTemplateRow(
          id: 'npc_secret',
          creatorId: 'user_123',
          name: 'Secret Boss',
          hpMax: 50,
          ac: 18,
          isPublic: false,
        );

        when(
          () => mockTablesDb.createRow(
            databaseId: any(named: 'databaseId'),
            tableId: 'npc_templates',
            rowId: any(named: 'rowId'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => npcRow..data['\$id'] = 'npc_secret');

        final notifier = container.read(npcTemplatesProvider.notifier);
        final newNpc = await notifier.createNpcTemplate(
          'Secret Boss',
          50,
          18,
          isPublic: false,
        );

        final state = container.read(npcTemplatesProvider);
        expect(state.myTemplates, contains(newNpc));
        expect(state.publicTemplates, isNot(contains(newNpc)));
      },
    );
  });
}
