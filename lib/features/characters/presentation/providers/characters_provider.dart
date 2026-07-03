import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/characters/domain/character.dart';
import 'package:ilithid/features/characters/presentation/providers/characters_state.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';

final charactersProvider =
    NotifierProvider<CharactersNotifier, CharactersState>(
      () => CharactersNotifier(),
    );

class CharactersNotifier extends Notifier<CharactersState> {
  late TablesDB _tablesDb;

  @override
  CharactersState build() {
    _tablesDb = ref.watch(appwriteTablesDbProvider);

    final authState = ref.watch(authProvider);
    if (authState.status == AuthStatus.authenticated) {
      Future.microtask(() => fetchCharacters());
    } else {
      return CharactersState.initial();
    }

    return CharactersState.initial();
  }

  Future<void> fetchCharacters() async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) {
      state = CharactersState.error(
        'User must be logged in to fetch characters.',
      );
      return;
    }

    state = CharactersState.loading(currentCharacters: state.characters);

    try {
      final response = await _tablesDb.listRows(
        databaseId: appwriteDatabaseId,
        tableId: appwriteCharactersTableId,
        queries: [Query.equal('userId', user.$id)],
      );

      final characters = response.rows
          .map((row) => Character.fromRow(row))
          .toList();
      state = CharactersState.success(characters);
    } catch (e) {
      state = CharactersState.error(
        e.toString(),
        currentCharacters: state.characters,
      );
    }
  }

  Future<Character?> createQuickCharacter(
    String name,
    int hpMax,
    int ac,
  ) async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) {
      state = CharactersState.error(
        'User must be logged in to create characters.',
      );
      return null;
    }

    state = CharactersState.loading(currentCharacters: state.characters);

    try {
      final characterId = ID.unique();
      final now = DateTime.now();

      final characterData = {
        'userId': user.$id,
        'name': name,
        'hpCurrent': hpMax,
        'hpMax': hpMax,
        'hpTemp': 0,
        'ac': ac,
        'sourceSystem': 'manual',
        'createdAt': now.toIso8601String(),
      };

      final row = await _tablesDb.createRow(
        databaseId: appwriteDatabaseId,
        tableId: appwriteCharactersTableId,
        rowId: characterId,
        data: characterData,
      );

      final newCharacter = Character.fromRow(row);

      // Update state with new character added to list
      final updatedList = List<Character>.from(state.characters)
        ..add(newCharacter);
      state = CharactersState.success(updatedList);

      return newCharacter;
    } catch (e) {
      state = CharactersState.error(
        e.toString(),
        currentCharacters: state.characters,
      );
      return null;
    }
  }
}
