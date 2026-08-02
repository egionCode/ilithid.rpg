import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilithid/features/combat/domain/log_entry.dart';
import 'package:ilithid/features/combat/domain/relative_time.dart';
import 'package:ilithid/features/combat/presentation/providers/logs_provider.dart';
import 'package:ilithid/features/combat/presentation/providers/logs_state.dart';
import 'package:ilithid/shared/theme/app_colors.dart';

/// Icon/color per [LogEntryType], shared by any log-related UI.
class _LogTypeStyle {
  final IconData icon;
  final Color color;

  const _LogTypeStyle(this.icon, this.color);

  static _LogTypeStyle of(LogEntryType type) {
    switch (type) {
      case LogEntryType.damage:
        return const _LogTypeStyle(
          Icons.local_fire_department,
          AppColors.damage,
        );
      case LogEntryType.heal:
        return const _LogTypeStyle(Icons.favorite, AppColors.heal);
      case LogEntryType.tempHp:
        return const _LogTypeStyle(Icons.shield, AppColors.tempHp);
      case LogEntryType.itemUse:
        return const _LogTypeStyle(Icons.inventory_2, AppColors.masterMagic);
      case LogEntryType.death:
        return const _LogTypeStyle(
          Icons.emoji_events_outlined,
          AppColors.textMuted,
        );
      case LogEntryType.custom:
        return const _LogTypeStyle(Icons.edit_note, AppColors.primary);
    }
  }
}

/// Scrollable feed of combat log entries for a session (Story 8.2). Newest
/// entries appear at the top (live via Realtime); scrolling near the
/// bottom loads the next page of older entries.
class LogFeed extends ConsumerStatefulWidget {
  final String sessionId;

  const LogFeed({super.key, required this.sessionId});

  @override
  ConsumerState<LogFeed> createState() => _LogFeedState();
}

class _LogFeedState extends ConsumerState<LogFeed> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(logsProvider(widget.sessionId).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsState = ref.watch(logsProvider(widget.sessionId));

    if (logsState.status == LogsStatus.loading && logsState.logs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (logsState.status == LogsStatus.error && logsState.logs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          logsState.errorMessage ?? 'Erro ao carregar o log.',
          style: const TextStyle(color: AppColors.damage),
        ),
      );
    }

    if (logsState.logs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Nenhum evento registrado ainda.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      // A distinct PageStorageKey (not just a plain Key) is required here:
      // this list can live inside an ExpansionTile (Story 11.1's
      // collapsible sections), which stores its own expanded/collapsed
      // bool via PageStorage under the nearest PageStorageKey ancestor.
      // Without an explicit key of its own, this ListView's scroll
      // position restoration resolves to that same ancestor identifier,
      // and reads back the ExpansionTile's bool where a double? is
      // expected - crashing with "type 'bool' is not a subtype of type
      // 'double?'".
      key: PageStorageKey<String>('log_feed_list_${widget.sessionId}'),
      controller: _scrollController,
      itemCount: logsState.logs.length + (logsState.isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index >= logsState.logs.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return _LogFeedItem(
          key: ValueKey(logsState.logs[index].id),
          entry: logsState.logs[index],
        );
      },
    );
  }
}

class _LogFeedItem extends StatelessWidget {
  final LogEntry entry;

  const _LogFeedItem({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final style = _LogTypeStyle.of(entry.type);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * -8),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(style.icon, color: style.color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.message,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.actorName} · ${formatRelativeTime(entry.timestamp)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
