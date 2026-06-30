import 'package:appwrite/models.dart' as models;

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.displayName,
    this.errorMessage,
  });

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);

  factory AuthState.unauthenticated({String? errorMessage}) =>
      AuthState(status: AuthStatus.unauthenticated, errorMessage: errorMessage);

  factory AuthState.authenticated(models.User user, String displayName) =>
      AuthState(
        status: AuthStatus.authenticated,
        user: user,
        displayName: displayName,
      );

  factory AuthState.loading() => const AuthState(status: AuthStatus.loading);

  final AuthStatus status;
  final models.User? user;
  final String? displayName;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    models.User? user,
    String? displayName,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      displayName: displayName ?? this.displayName,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
