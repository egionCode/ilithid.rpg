import 'package:ilithid/features/sessions/domain/session.dart';

enum SessionsStatus { initial, loading, success, error }

class SessionsState {
  final SessionsStatus status;
  final Session? activeSession;
  final List<Session> sessions;
  final String? errorMessage;

  const SessionsState({
    required this.status,
    this.activeSession,
    this.sessions = const [],
    this.errorMessage,
  });

  factory SessionsState.initial() =>
      const SessionsState(status: SessionsStatus.initial);
  factory SessionsState.loading() =>
      const SessionsState(status: SessionsStatus.loading);
  factory SessionsState.success(
    Session? activeSession, [
    List<Session> sessions = const [],
  ]) => SessionsState(
    status: SessionsStatus.success,
    activeSession: activeSession,
    sessions: sessions,
  );
  factory SessionsState.error(String message) =>
      SessionsState(status: SessionsStatus.error, errorMessage: message);

  SessionsState copyWith({
    SessionsStatus? status,
    Session? activeSession,
    List<Session>? sessions,
    String? errorMessage,
  }) {
    return SessionsState(
      status: status ?? this.status,
      activeSession: activeSession ?? this.activeSession,
      sessions: sessions ?? this.sessions,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
