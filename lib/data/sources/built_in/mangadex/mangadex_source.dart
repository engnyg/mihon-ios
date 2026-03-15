import '../../../../domain/entities/chapter.dart';
import '../../../../domain/entities/manga.dart';
import '../../../../domain/entities/mangas_page.dart';
import '../../../../domain/entities/page.dart';
import '../../base/filter.dart';
import '../../base/http_source.dart';
import 'mangadex_api.dart';
import 'mangadex_filters.dart';

class MangaDexSource extends HttpSource {
  @override
  String get id => 'mangadex';

  @override
  String get name => 'MangaDex';

  @override
  String get lang => 'en';

  @override
  String get baseUrl => 'https://api.mangadex.org';

  @override
  Map<String, String> get headers => {
        'User-Agent': 'mihon-ios/0.1.0',
        'Referer': 'https://mangadex.org',
      };

  final _api = MangaDexApi();

  // ── Browse ─────────────────────────────────────────────────────────────────

  @override
  Future<MangasPage> getPopularManga(int page) =>
      _api.getMangaList(page, order: {'rating': 'desc'});

  @override
  Future<MangasPage> getLatestUpdates(int page) =>
      _api.getMangaList(page, order: {'updatedAt': 'desc'});

  @override
  Future<MangasPage> searchManga(
    int page,
    String query,
    FilterList filters,
  ) =>
      _api.getMangaList(page, query: query.isEmpty ? null : query);

  // ── Detail ────────────────────────────────────────────────────────────────

  @override
  Future<Manga> getMangaDetails(Manga manga) => _api.getMangaDetail(manga);

  // ── Chapters ──────────────────────────────────────────────────────────────

  @override
  Future<List<Chapter>> getChapterList(Manga manga) =>
      _api.getChapterList(manga);

  // ── Pages ─────────────────────────────────────────────────────────────────

  @override
  Future<List<MangaPage>> getPageList(Chapter chapter) =>
      _api.getPageList(chapter);

  // ── Filters ───────────────────────────────────────────────────────────────

  @override
  FilterList getFilterList() => MangaDexFilters.filterList;
}
