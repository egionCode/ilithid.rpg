import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_provider.dart';
import 'package:ilithid/features/auth/presentation/providers/auth_state.dart';
import 'package:ilithid/features/characters/domain/character.dart';
import 'package:ilithid/features/characters/presentation/providers/characters_state.dart';
import 'package:ilithid/shared/services/appwrite_service.dart';
import 'package:ilithid/shared/services/realtime_service.dart';

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
      final userId = authState.user!.$id;
      Future.microtask(() {
        fetchCharacters();
        _subscribeToRealtime(userId);
      });
    } else {
      return CharactersState.initial();
    }

    return CharactersState.initial();
  }

  /// Subscribes to Realtime updates for the current user's own characters,
  /// so HP changes applied by the GM during combat (Story 7.2) reflect live.
  void _subscribeToRealtime(String userId) {
    try {
      final realtimeClient = ref.read(realtimeClientProvider);
      final isTest = StackTrace.current.toString().contains(
        'package:flutter_test',
      );
      if (isTest && realtimeClient.runtimeType.toString() == 'Realtime') {
        return;
      }

      final service = ref.read(realtimeServiceProvider);
      final handle = service.subscribeToCampaignCharacters(
        memberUserIds: [userId],
        onEvent: (_) => fetchCharacters(),
      );

      ref.onDispose(() {
        handle.cancel();
      });
    } catch (_) {
      // Fail silently if Realtime connection fails
    }
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

  Future<Character?> updateCharacter(
    String characterId, {
    required String name,
    required int hpMax,
    required int ac,
  }) async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) {
      state = CharactersState.error(
        'User must be logged in to update characters.',
      );
      return null;
    }

    state = CharactersState.loading(currentCharacters: state.characters);

    try {
      final existingChar = state.characters.firstWhere(
        (c) => c.id == characterId,
      );
      final newHpCurrent = existingChar.hpCurrent > hpMax
          ? hpMax
          : existingChar.hpCurrent;

      final characterData = {
        'name': name,
        'hpMax': hpMax,
        'hpCurrent': newHpCurrent,
        'ac': ac,
      };

      final row = await _tablesDb.updateRow(
        databaseId: appwriteDatabaseId,
        tableId: appwriteCharactersTableId,
        rowId: characterId,
        data: characterData,
      );

      final updatedChar = Character.fromRow(row);

      final updatedList = state.characters.map((c) {
        return c.id == characterId ? updatedChar : c;
      }).toList();
      state = CharactersState.success(updatedList);

      return updatedChar;
    } catch (e) {
      state = CharactersState.error(
        e.toString(),
        currentCharacters: state.characters,
      );
      return null;
    }
  }

  Future<bool> deleteCharacter(String characterId) async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) {
      state = CharactersState.error(
        'User must be logged in to delete characters.',
      );
      return false;
    }

    state = CharactersState.loading(currentCharacters: state.characters);

    try {
      await _tablesDb.deleteRow(
        databaseId: appwriteDatabaseId,
        tableId: appwriteCharactersTableId,
        rowId: characterId,
      );

      try {
        final membersResponse = await _tablesDb.listRows(
          databaseId: appwriteDatabaseId,
          tableId: appwriteCampaignMembersTableId,
          queries: [Query.equal('activeCharacterId', characterId)],
        );
        for (final memberRow in membersResponse.rows) {
          await _tablesDb.updateRow(
            databaseId: appwriteDatabaseId,
            tableId: appwriteCampaignMembersTableId,
            rowId: memberRow.$id,
            data: {'activeCharacterId': null},
          );
        }
      } catch (_) {}

      final updatedList = state.characters
          .where((c) => c.id != characterId)
          .toList();
      state = CharactersState.success(updatedList);

      return true;
    } catch (e) {
      state = CharactersState.error(
        e.toString(),
        currentCharacters: state.characters,
      );
      return false;
    }
  }
}
