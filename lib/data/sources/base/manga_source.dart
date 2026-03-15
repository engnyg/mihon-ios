import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/manga.dart';
import '../../../domain/entities/mangas_page.dart';
import '../../../domain/entities/page.dart';
import 'filter.dart';

/// Core contract that every manga source must implement.
/// Mirrors Mihon's `eu.kanade.tachiyomi.source.MangaSource`.
abstract interface class MangaSource {
  /// Unique identifier for this source (should be stable across updates).
  String get id;

  /// Display name shown in the Browse tab.
  String get name;

  /// ISO 639-1 language code, e.g. 'en', 'ja', 'zh'.
  String get lang;

  /// Base URL of the source site (used for deep-link detection).
  String get baseUrl;

  /// Returns a page of popular/featured manga.
  Future<MangasPage> getPopularManga(int page);

  /// Returns a page of recently updated manga.
  Future<MangasPage> getLatestUpdates(int page);

  /// Searches for manga matching [query] with optional [filters].
  Future<MangasPage> searchManga(int page, String query, FilterList filters);

  /// Fetches full details for [manga] (description, genres, status, etc.).
  /// May mutate fields not set by the list endpoints.
  Future<Manga> getMangaDetails(Manga manga);

  /// Returns the chapter list for [manga], newest first.
  Future<List<Chapter>> getChapterList(Manga manga);

  /// Returns page data for [chapter].
  /// Each [MangaPage] has a [url] that may need to be resolved via [getImageUrl].
  Future<List<MangaPage>> getPageList(Chapter chapter);

  /// Resolves a page's URL to the actual image URL.
  /// Override only if the source requires a secondary HTTP request per page.
  Future<String> getImageUrl(MangaPage page) async {
    if (page.imageUrl != null) return page.imageUrl!;
    if (page.url != null) return page.url!;
    throw ArgumentError('Page has neither imageUrl nor url');
  }

  /// Whether this source supports latest-updates browsing.
  bool get supportsLatest => true;

  /// Filters supported by this source's search.
  FilterList getFilterList() => FilterList([]);
}
