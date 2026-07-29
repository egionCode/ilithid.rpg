import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/characters/presentation/providers/characters_provider.dart';
import 'package:ilithid/features/characters/presentation/providers/characters_state.dart';
import 'package:ilithid/shared/services/realtime_service.dart';
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

  models.Row buildCharacterRow({
    required String id,
    required String userId,
    required String name,
    required int hpMax,
    required int ac,
  }) {
    return models.Row.fromMap({
      '\$id': id,
      '\$tableId': 'characters',
      '\$databaseId': 'main',
      '\$createdAt': '',
      '\$updatedAt': '',
      '\$permissions': <String>[],
      '\$sequence': 0,
      'userId': userId,
      'name': name,
      'hpCurrent': hpMax,
      'hpMax': hpMax,
      'hpTemp': 0,
      'ac': ac,
      'sourceSystem': 'manual',
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
    when(() => mockRealtimeSubscription.close).thenReturn(() async {});

    // Default fallback stub for listRows queries
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

  group('CharactersNotifier Tests', () {
    final authenticatedUser = models.User.fromMap({
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

    final authenticatedState = AuthState(
      status: AuthStatus.authenticated,
      user: authenticatedUser,
      displayName: 'Grog',
    );

    test('should fail if user is not authenticated', () async {
      container = ProviderContainer(
        overrides: [
          appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
          realtimeClientProvider.overrideWithValue(mockRealtime),
          authProvider.overrideWith(
            () => FakeAuthNotifier(AuthState.initial()),
          ),
        ],
      );

      final state = container.read(charactersProvider);
      expect(state.status, equals(CharactersStatus.initial));
      expect(state.characters, isEmpty);
    });

    test('should fetch user characters successfully', () async {
      final characterRow = buildCharacterRow(
        id: 'char_abc',
        userId: 'user_123',
        name: 'Grog Strongjaw',
        hpMax: 120,
        ac: 17,
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
          'rows': [characterRow.toMap()..['\$id'] = 'char_abc'],
        }),
      );

      container = ProviderContainer(
        overrides: [
          appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
          realtimeClientProvider.overrideWithValue(mockRealtime),
          authProvider.overrideWith(() => FakeAuthNotifier(authenticatedState)),
        ],
      );

      // Trigger build() and schedule fetchCharacters microtask
      container.read(charactersProvider);

      // Wait for fetchCharacters microtask triggered in build() to complete
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(charactersProvider);
      expect(state.status, equals(CharactersStatus.success));
      expect(state.characters.length, equals(1));
      expect(state.characters.first.name, equals('Grog Strongjaw'));
    });

    test(
      'createQuickCharacter should create character sheet successfully',
      () async {
        final newCharRow = buildCharacterRow(
          id: 'char_new',
          userId: 'user_123',
          name: 'Pike Trickfoot',
          hpMax: 70,
          ac: 19,
        );

        when(
          () => mockTablesDb.createRow(
            databaseId: any(named: 'databaseId'),
            tableId: any(named: 'tableId'),
            rowId: any(named: 'rowId'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => newCharRow);

        container = ProviderContainer(
          overrides: [
            appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
            realtimeClientProvider.overrideWithValue(mockRealtime),
            authProvider.overrideWith(
              () => FakeAuthNotifier(authenticatedState),
            ),
          ],
        );

        // Trigger build() and schedule fetchCharacters microtask
        container.read(charactersProvider);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final character = await container
            .read(charactersProvider.notifier)
            .createQuickCharacter('Pike Trickfoot', 70, 19);

        expect(character, isNotNull);
        expect(character!.name, equals('Pike Trickfoot'));

        final state = container.read(charactersProvider);
        expect(state.status, equals(CharactersStatus.success));
        expect(state.characters.any((c) => c.id == 'char_new'), isTrue);
      },
    );

    test(
      'updateCharacter should update character sheet successfully',
      () async {
        final existingCharRow = buildCharacterRow(
          id: 'char_abc',
          userId: 'user_123',
          name: 'Grog Strongjaw',
          hpMax: 120,
          ac: 17,
        );

        final updatedCharRow = buildCharacterRow(
          id: 'char_abc',
          userId: 'user_123',
          name: 'Grog Grand',
          hpMax: 150,
          ac: 18,
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
            'rows': [existingCharRow.toMap()..['\$id'] = 'char_abc'],
          }),
        );

        when(
          () => mockTablesDb.updateRow(
            databaseId: any(named: 'databaseId'),
            tableId: any(named: 'tableId'),
            rowId: any(named: 'rowId'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => updatedCharRow);

        container = ProviderContainer(
          overrides: [
            appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
            realtimeClientProvider.overrideWithValue(mockRealtime),
            authProvider.overrideWith(
              () => FakeAuthNotifier(authenticatedState),
            ),
          ],
        );

        container.read(charactersProvider);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final character = await container
            .read(charactersProvider.notifier)
            .updateCharacter(
              'char_abc',
              name: 'Grog Grand',
              hpMax: 150,
              ac: 18,
            );

        expect(character, isNotNull);
        expect(character!.name, equals('Grog Grand'));
        expect(character.hpMax, equals(150));

        final state = container.read(charactersProvider);
        expect(state.status, equals(CharactersStatus.success));
        expect(
          state.characters.firstWhere((c) => c.id == 'char_abc').name,
          equals('Grog Grand'),
        );
      },
    );

    test(
      'deleteCharacter should delete character and unlink from campaign members',
      () async {
        final existingCharRow = buildCharacterRow(
          id: 'char_abc',
          userId: 'user_123',
          name: 'Grog Strongjaw',
          hpMax: 120,
          ac: 17,
        );

        final memberRow = models.Row.fromMap({
          '\$id': 'member_999',
          '\$tableId': 'campaign_members',
          '\$databaseId': 'main',
          '\$createdAt': '',
          '\$updatedAt': '',
          '\$permissions': <String>[],
          '\$sequence': 0,
          'campaignId': 'camp_1',
          'userId': 'user_123',
          'activeCharacterId': 'char_abc',
          'role': 'player',
          'joinedAt': DateTime.now().toIso8601String(),
        });

        when(
          () => mockTablesDb.listRows(
            databaseId: any(named: 'databaseId'),
            tableId: any(named: 'tableId'),
            queries: any(named: 'queries'),
          ),
        ).thenAnswer((invocation) async {
          final tableId = invocation.namedArguments[const Symbol('tableId')];
          if (tableId == 'characters') {
            return models.RowList.fromMap({
              'total': 1,
              'rows': [existingCharRow.toMap()..['\$id'] = 'char_abc'],
            });
          } else if (tableId == 'campaign_members') {
            return models.RowList.fromMap({
              'total': 1,
              'rows': [memberRow.toMap()..['\$id'] = 'member_999'],
            });
          }
          return models.RowList.fromMap({
            'total': 0,
            'rows': <Map<String, dynamic>>[],
          });
        });

        when(
          () => mockTablesDb.deleteRow(
            databaseId: any(named: 'databaseId'),
            tableId: any(named: 'tableId'),
            rowId: any(named: 'rowId'),
          ),
        ).thenAnswer((_) async => {});

        when(
          () => mockTablesDb.updateRow(
            databaseId: any(named: 'databaseId'),
            tableId: any(named: 'tableId'),
            rowId: any(named: 'rowId'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => memberRow);

        container = ProviderContainer(
          overrides: [
            appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
            realtimeClientProvider.overrideWithValue(mockRealtime),
            authProvider.overrideWith(
              () => FakeAuthNotifier(authenticatedState),
            ),
          ],
        );

        container.read(charactersProvider);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final success = await container
            .read(charactersProvider.notifier)
            .deleteCharacter('char_abc');

        expect(success, isTrue);

        verify(
          () => mockTablesDb.deleteRow(
            databaseId: any(named: 'databaseId'),
            tableId: 'characters',
            rowId: 'char_abc',
          ),
        ).called(1);

        verify(
          () => mockTablesDb.updateRow(
            databaseId: any(named: 'databaseId'),
            tableId: 'campaign_members',
            rowId: 'member_999',
            data: {'activeCharacterId': null},
          ),
        ).called(1);

        final state = container.read(charactersProvider);
        expect(state.status, equals(CharactersStatus.success));
        expect(state.characters.any((c) => c.id == 'char_abc'), isFalse);
      },
    );
  });
}
