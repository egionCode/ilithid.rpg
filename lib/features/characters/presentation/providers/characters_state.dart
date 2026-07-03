import 'package:equatable/equatable.dart';
import 'package:ilithid/features/characters/domain/character.dart';

enum CharactersStatus { initial, loading, success, error }

class CharactersState extends Equatable {
  final CharactersStatus status;
  final List<Character> characters;
  final String? errorMessage;

  const CharactersState({
    required this.status,
    required this.characters,
    this.errorMessage,
  });

  factory CharactersState.initial() {
    return const CharactersState(
      status: CharactersStatus.initial,
      characters: [],
    );
  }

  factory CharactersState.loading({
    List<Character> currentCharacters = const [],
  }) {
    return CharactersState(
      status: CharactersStatus.loading,
      characters: currentCharacters,
    );
  }

  factory CharactersState.success(List<Character> characters) {
    return CharactersState(
      status: CharactersStatus.success,
      characters: characters,
    );
  }

  factory CharactersState.error(
    String message, {
    List<Character> currentCharacters = const [],
  }) {
    return CharactersState(
      status: CharactersStatus.error,
      characters: currentCharacters,
      errorMessage: message,
    );
  }

  @override
  List<Object?> get props => [status, characters, errorMessage];
}
