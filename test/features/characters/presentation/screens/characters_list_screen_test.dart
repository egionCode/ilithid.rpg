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
import 'package:ilithid/features/characters/presentation/screens/characters_list_screen.dart';
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
  Future<bool> deleteCharacter(String characterId) async {
    return true;
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

  testWidgets('CharactersListScreen renders empty state', (tester) async {
    final charactersState = CharactersState.success(const []);

    final router = GoRouter(
      initialLocation: '/characters',
      routes: [
        GoRoute(
          path: '/characters',
          builder: (context, state) => const CharactersListScreen(),
        ),
        GoRoute(
          path: '/characters/new',
          builder: (context, state) =>
              const Scaffold(body: Text('New Character')),
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

    expect(find.text('Nenhuma ficha encontrada'), findsOneWidget);
    expect(
      find.byKey(const Key('empty_state_add_char_button')),
      findsOneWidget,
    );
  });

  testWidgets(
    'CharactersListScreen renders list of characters and confirm delete works',
    (tester) async {
      final charactersState = CharactersState.success([mockCharacter]);

      final router = GoRouter(
        initialLocation: '/characters',
        routes: [
          GoRoute(
            path: '/characters',
            builder: (context, state) => const CharactersListScreen(),
          ),
          GoRoute(
            path: '/characters/:id/edit',
            builder: (context, state) => const Scaffold(body: Text('Edit')),
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

      expect(find.text('Grog Strongjaw'), findsOneWidget);
      expect(find.text('HP: 120/120 | CA: 17'), findsOneWidget);

      // Tap delete button
      final deleteButton = find.byKey(Key('delete_char_${mockCharacter.id}'));
      expect(deleteButton, findsOneWidget);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.text('Excluir Ficha'), findsWidgets);
      expect(find.byKey(const Key('confirm_delete_button')), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.byKey(const Key('confirm_delete_button')));
      await tester.pumpAndSettle();
    },
  );
}
