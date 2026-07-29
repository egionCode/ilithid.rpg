import 'package:equatable/equatable.dart';
import 'package:ilithid/features/combat/domain/log_entry.dart';

enum LogsStatus { initial, loading, success, error }

class LogsState extends Equatable {
  final LogsStatus status;
  final List<LogEntry> logs;
  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;

  const LogsState({
    required this.status,
    this.logs = const [],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  factory LogsState.initial() => const LogsState(status: LogsStatus.initial);

  factory LogsState.loading({List<LogEntry> current = const []}) =>
      LogsState(status: LogsStatus.loading, logs: current);

  factory LogsState.success(List<LogEntry> logs, {required bool hasMore}) =>
      LogsState(status: LogsStatus.success, logs: logs, hasMore: hasMore);

  factory LogsState.error(
    String message, {
    List<LogEntry> current = const [],
  }) =>
      LogsState(status: LogsStatus.error, logs: current, errorMessage: message);

  LogsState copyWith({
    LogsStatus? status,
    List<LogEntry>? logs,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
  }) {
    return LogsState(
      status: status ?? this.status,
      logs: logs ?? this.logs,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    logs,
    hasMore,
    isLoadingMore,
    errorMessage,
  ];
}
