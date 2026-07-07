import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/characters/domain/character.dart';
import 'package:ilithid/features/characters/presentation/providers/characters_provider.dart';
import 'package:ilithid/features/characters/presentation/providers/characters_state.dart';
import 'package:ilithid/features/characters/presentation/screens/character_form_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockTablesDB extends Mock implements TablesDB {}

class FakeAuthNotifier extends AuthNotifier {
  final AuthState _initialState;
  FakeAuthNotifier(this._initialState);
  @override
  AuthState build() => _initialState;
}

class FakeCharactersNotifier extends CharactersNotifier {
  final CharactersState _initialState;
  FakeCharactersNotifier(this._initialState);

  @override
  CharactersState build() => _initialState;

  @override
  Future<Character?> createQuickCharacter(
    String name,
    int hpMax,
    int ac,
  ) async {
    return Character(
      id: 'char_new_123',
      userId: 'user_123',
      name: name,
      hpCurrent: hpMax,
      hpMax: hpMax,
      ac: ac,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<Character?> updateCharacter(
    String characterId, {
    required String name,
    required int hpMax,
    required int ac,
  }) async {
    return Character(
      id: characterId,
      userId: 'user_123',
      name: name,
      hpCurrent: hpMax,
      hpMax: hpMax,
      ac: ac,
      createdAt: DateTime.now(),
    );
  }
}

void main() {
  late MockTablesDB mockTablesDb;

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

  final mockCharacter = Character(
    id: 'char_789',
    userId: 'user_123',
    name: 'Grog Strongjaw',
    hpCurrent: 120,
    hpMax: 120,
    ac: 17,
    createdAt: DateTime.now(),
  );

  setUp(() {
    mockTablesDb = MockTablesDB();
  });

  testWidgets('CharacterFormScreen validation and creation works', (
    tester,
  ) async {
    final charactersState = CharactersState.success(const []);

    final router = GoRouter(
      initialLocation: '/characters/new',
      routes: [
        GoRoute(
          path: '/characters/new',
          builder: (context, state) => const CharacterFormScreen(),
        ),
        GoRoute(
          path: '/characters',
          builder: (context, state) => const Scaffold(body: Text('List')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
          authProvider.overrideWith(() => FakeAuthNotifier(authState)),
          charactersProvider.overrideWith(
            () => FakeCharactersNotifier(charactersState),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    // Form inputs and submit button are present
    expect(find.byKey(const Key('char_name_field')), findsOneWidget);
    expect(find.byKey(const Key('char_hp_field')), findsOneWidget);
    expect(find.byKey(const Key('char_ac_field')), findsOneWidget);
    expect(find.byKey(const Key('char_submit_button')), findsOneWidget);

    // Clear name and tap submit to trigger validation error
    await tester.enterText(find.byKey(const Key('char_name_field')), '');
    await tester.tap(find.byKey(const Key('char_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('O nome do personagem é obrigatório'), findsOneWidget);

    // Fill valid data
    await tester.enterText(find.byKey(const Key('char_name_field')), 'Scanlan');
    await tester.enterText(find.byKey(const Key('char_hp_field')), '50');
    await tester.enterText(find.byKey(const Key('char_ac_field')), '14');

    await tester.tap(find.byKey(const Key('char_submit_button')));
    await tester.pumpAndSettle();
  });

  testWidgets('CharacterFormScreen edit mode pre-fills values', (tester) async {
    final charactersState = CharactersState.success([mockCharacter]);

    final router = GoRouter(
      initialLocation: '/characters/char_789/edit',
      routes: [
        GoRoute(
          path: '/characters/:id/edit',
          builder: (context, state) {
            final id = state.pathParameters['id'];
            return CharacterFormScreen(characterId: id);
          },
        ),
        GoRoute(
          path: '/characters',
          builder: (context, state) => const Scaffold(body: Text('List')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appwriteTablesDbProvider.overrideWithValue(mockTablesDb),
          authProvider.overrideWith(() => FakeAuthNotifier(authState)),
          charactersProvider.overrideWith(
            () => FakeCharactersNotifier(charactersState),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    // Pre-filled fields check
    expect(find.text('Grog Strongjaw'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);

    // Edit fields and submit
    await tester.enterText(
      find.byKey(const Key('char_name_field')),
      'Grog Grand',
    );
    await tester.tap(find.byKey(const Key('char_submit_button')));
    await tester.pumpAndSettle();
  });
}
