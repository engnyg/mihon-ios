import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/manga.dart';
import '../../domain/repositories/chapter_repository.dart';
import '../../domain/repositories/manga_repository.dart';
import '../router/app_router.dart';
import 'manga_detail_providers.dart';

class MangaDetailScreen extends ConsumerWidget {
  const MangaDetailScreen({
    super.key,
    required this.mangaUrl,
    required this.sourceId,
    this.mangaId,
  });

  final String mangaUrl;
  final String sourceId;
  final int? mangaId;

  MangaDetailParams get _params =>
      (mangaUrl: mangaUrl, sourceId: sourceId, mangaId: mangaId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mangaAsync = ref.watch(mangaDetailProvider(_params));
    final chaptersAsync = ref.watch(chapterListProvider(_params));
    final libraryState = ref.watch(libraryNotifierProvider(mangaId));

    return Scaffold(
      body: mangaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (manga) => _MangaDetailContent(
          manga: manga,
          chaptersAsync: chaptersAsync,
          libraryState: libraryState,
          onToggleLibrary: () =>
              ref.read(libraryNotifierProvider(mangaId).notifier).toggle(manga),
          onChapterTap: (chapter, allChapters) async {
            int effectiveMangaId = manga.id ?? 0;

            // Ensure manga is in DB
            if (manga.id == null) {
              effectiveMangaId = await GetIt.I<MangaRepository>()
                  .insertManga(manga.copyWith(inLibrary: false));
            }

            // Save all chapters to DB
            final chaptersToSave = allChapters
                .map((c) => c.copyWith(mangaId: effectiveMangaId))
                .toList();
            await GetIt.I<ChapterRepository>()
                .insertChapters(chaptersToSave);

            // Find the saved chapter by URL
            final saved = await GetIt.I<ChapterRepository>()
                .getChaptersByMangaId(effectiveMangaId);
            final target = saved.firstWhere(
              (c) => c.url == chapter.url,
              orElse: () => saved.first,
            );

            if (context.mounted) {
              context.push(Routes.reader, extra: {
                'chapterId': target.id!,
                'mangaId': effectiveMangaId,
              });
            }
          },
        ),
      ),
    );
  }
}

class _MangaDetailContent extends StatelessWidget {
  const _MangaDetailContent({
    required this.manga,
    required this.chaptersAsync,
    required this.libraryState,
    required this.onToggleLibrary,
    required this.onChapterTap,
  });

  final Manga manga;
  final AsyncValue<List<Chapter>> chaptersAsync;
  final AsyncValue<bool> libraryState;
  final VoidCallback onToggleLibrary;
  final void Function(Chapter chapter, List<Chapter> allChapters) onChapterTap;

  @override
  Widget build(BuildContext context) {
    final inLibrary = libraryState.value ?? false;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: _CoverBackground(coverUrl: manga.coverUrl),
            title: Text(
              manga.title,
              style: const TextStyle(
                shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                inLibrary ? Icons.favorite : Icons.favorite_border,
                color: inLibrary ? Colors.pinkAccent : null,
              ),
              tooltip: inLibrary ? context.l10n.removeFromLibrary : context.l10n.addToLibrary,
              onPressed: onToggleLibrary,
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: _MangaInfo(manga: manga),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              context.l10n.chapters,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        chaptersAsync.when(
          loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) =>
              SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
          data: (chapters) => SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _ChapterTile(
                chapter: chapters[i],
                onTap: () => onChapterTap(chapters[i], chapters),
              ),
              childCount: chapters.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _CoverBackground extends StatelessWidget {
  const _CoverBackground({required this.coverUrl});
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    if (coverUrl == null) {
      return Container(color: Theme.of(context).colorScheme.surfaceContainerHighest);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(imageUrl: coverUrl!, fit: BoxFit.cover),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
            ),
          ),
        ),
      ],
    );
  }
}

class _MangaInfo extends StatefulWidget {
  const _MangaInfo({required this.manga});
  final Manga manga;

  @override
  State<_MangaInfo> createState() => _MangaInfoState();
}

class _MangaInfoState extends State<_MangaInfo> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final manga = widget.manga;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (manga.author != null)
            Text(manga.author!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatusChip(status: manga.status),
              const SizedBox(width: 8),
              Chip(
                label: Text(widget.manga.genres.isNotEmpty
                    ? manga.genres.first
                    : 'Unknown genre'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (manga.description != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                manga.description!,
                maxLines: _expanded ? null : 3,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? context.l10n.showLess : context.l10n.showMore),
            ),
          ],
          if (manga.genres.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: manga.genres
                  .map((g) => Chip(
                        label: Text(g, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final MangaStatus status;

  String _label(BuildContext context) {
    final l = context.l10n;
    return switch (status) {
      MangaStatus.ongoing => l.statusOngoing,
      MangaStatus.completed => l.statusCompleted,
      MangaStatus.cancelled => l.statusCancelled,
      MangaStatus.onHiatus => l.statusHiatus,
      MangaStatus.licensed => l.statusLicensed,
      MangaStatus.publishingFinished => l.statusFinished,
      MangaStatus.unknown => l.statusUnknown,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(_label(context)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({required this.chapter, required this.onTap});
  final Chapter chapter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        chapter.name,
        style: TextStyle(
          color: chapter.read
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : null,
        ),
      ),
      subtitle: chapter.scanlator != null ? Text(chapter.scanlator!) : null,
      trailing: chapter.read
          ? Icon(Icons.check_circle,
              color: Theme.of(context).colorScheme.primary, size: 18)
          : null,
      onTap: onTap,
    );
  }
}
