import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/manga.dart';
import '../router/app_router.dart';
import '../common/widgets/manga_grid_item.dart';
import '../common/widgets/loading_indicator.dart';
import '../common/widgets/error_view.dart';
import 'browse_providers.dart';

class SourceCatalogScreen extends ConsumerStatefulWidget {
  const SourceCatalogScreen({super.key, required this.sourceId});
  final String sourceId;

  @override
  ConsumerState<SourceCatalogScreen> createState() =>
      _SourceCatalogScreenState();
}

class _SourceCatalogScreenState
    extends ConsumerState<SourceCatalogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  border: InputBorder.none,
                ),
                onSubmitted: (q) {
                  ref
                      .read(catalogSearchQueryProvider(widget.sourceId)
                          .notifier)
                      .state = q;
                },
              )
            : Text(widget.sourceId),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _isSearching = !_isSearching);
              if (!_isSearching) {
                _searchController.clear();
                ref
                    .read(catalogSearchQueryProvider(widget.sourceId)
                        .notifier)
                    .state = '';
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Popular'),
            Tab(text: 'Latest'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MangaGrid(
            sourceId: widget.sourceId,
            mode: CatalogMode.popular,
          ),
          _MangaGrid(
            sourceId: widget.sourceId,
            mode: CatalogMode.latest,
          ),
        ],
      ),
    );
  }
}

class _MangaGrid extends ConsumerWidget {
  const _MangaGrid({required this.sourceId, required this.mode});
  final String sourceId;
  final CatalogMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mode == CatalogMode.popular
        ? popularMangaProvider(sourceId)
        : latestMangaProvider(sourceId);

    final mangaAsync = ref.watch(provider);

    return mangaAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (mangas) => GridView.builder(
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
                'sourceId': sourceId,
                'mangaId': manga.id,
              },
            ),
          );
        },
      ),
    );
  }
}
