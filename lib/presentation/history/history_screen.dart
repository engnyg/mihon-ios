import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/reading_history.dart';
import '../../domain/repositories/history_repository.dart';
import '../router/app_router.dart';

final _historyProvider = StreamProvider<List<ReadingHistory>>((ref) {
  return GetIt.I<HistoryRepository>().watchHistory();
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          historyAsync.maybeWhen(
            data: (items) => items.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: 'Clear all',
                    onPressed: () => _confirmClearAll(context),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No reading history',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => _HistoryTile(item: items[i]),
          );
        },
      ),
    );
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This will remove all reading history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              GetIt.I<HistoryRepository>().clearAllHistory();
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});
  final ReadingHistory item;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, y  HH:mm').format(item.lastRead);

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: item.manga.coverUrl != null
            ? Image.network(
                item.manga.coverUrl!,
                width: 40,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.book_outlined, size: 40),
              )
            : const Icon(Icons.book_outlined, size: 40),
      ),
      title: Text(item.manga.title,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.chapter.name,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(dateStr,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      isThreeLine: true,
      onTap: () => context.push(
        Routes.reader,
        extra: {
          'chapterId': item.chapter.id!,
          'mangaId': item.manga.id!,
        },
      ),
    );
  }
}
