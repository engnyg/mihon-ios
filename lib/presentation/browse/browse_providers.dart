import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sources/source_registry.dart';
import '../../domain/entities/manga.dart';
import '../../data/sources/base/filter.dart';

enum CatalogMode { popular, latest, search }

final catalogSearchQueryProvider =
    StateProvider.family<String, String>((ref, sourceId) => '');

final popularMangaProvider =
    FutureProvider.family<List<Manga>, String>((ref, sourceId) async {
  final source = SourceRegistry.instance.getSource(sourceId);
  if (source == null) throw Exception('Source not found: $sourceId');
  final page = await source.getPopularManga(1);
  return page.mangas;
});

final latestMangaProvider =
    FutureProvider.family<List<Manga>, String>((ref, sourceId) async {
  final source = SourceRegistry.instance.getSource(sourceId);
  if (source == null) throw Exception('Source not found: $sourceId');
  final page = await source.getLatestUpdates(1);
  return page.mangas;
});

final searchMangaProvider = FutureProvider.family<List<Manga>,
    ({String sourceId, String query})>((ref, params) async {
  final source = SourceRegistry.instance.getSource(params.sourceId);
  if (source == null) throw Exception('Source not found: ${params.sourceId}');
  final page =
      await source.searchManga(1, params.query, FilterList([]));
  return page.mangas;
});
