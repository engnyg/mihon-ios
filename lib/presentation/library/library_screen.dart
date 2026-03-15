import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../domain/entities/manga.dart';
import '../router/app_router.dart';
import 'library_providers.dart';
import '../common/widgets/manga_grid_item.dart';
import '../common/widgets/empty_state_view.dart';
import '../common/widgets/loading_indicator.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final libraryAsync = ref.watch(libraryProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.searchLibrary,
                  border: InputBorder.none,
                ),
                onChanged: (q) =>
                    ref.read(librarySearchQueryProvider.notifier).state = q,
              )
            : Text(l10n.library),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _isSearching = !_isSearching);
              if (!_isSearching) {
                _searchController.clear();
                ref.read(librarySearchQueryProvider.notifier).state = '';
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: libraryAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (mangas) {
          if (mangas.isEmpty) {
            return EmptyStateView(
              icon: Icons.collections_bookmark_outlined,
              title: l10n.emptyLibrary,
              subtitle: l10n.emptyLibrarySubtitle,
            );
          }
          return _LibraryGrid(mangas: mangas);
        },
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => const _FilterSheet(),
    );
  }
}

class _LibraryGrid extends StatelessWidget {
  const _LibraryGrid({required this.mangas});
  final List<Manga> mangas;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: mangas.length,
      itemBuilder: (context, i) {
        final manga = mangas[i];
        return MangaGridItem(
          manga: manga,
          onTap: () => context.push(
            Routes.mangaDetail,
            extra: {
              'mangaUrl': manga.url,
              'sourceId': manga.sourceId,
              'mangaId': manga.id,
            },
          ),
        );
      },
    );
  }
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: 300,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.filterSort,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Expanded(child: Center(child: Text(l10n.filtersComingSoon))),
        ],
      ),
    );
  }
}
