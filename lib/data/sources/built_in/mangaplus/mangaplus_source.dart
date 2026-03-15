import '../../../../domain/entities/chapter.dart';
import '../../../../domain/entities/manga.dart';
import '../../../../domain/entities/mangas_page.dart';
import '../../../../domain/entities/page.dart';
import '../../base/filter.dart';
import '../../base/manga_source.dart';
import 'mangaplus_api.dart';

class MangaPlusSource implements MangaSource {
  @override
  String get id => 'mangaplus';
  @override
  String get name => 'MANGA Plus';
  @override
  String get lang => 'en';
  @override
  String get baseUrl => 'https://mangaplus.shueisha.co.jp';
  @override
  bool get supportsLatest => true;

  final _api = MangaPlusApi();

  @override
  Future<MangasPage> getPopularManga(int page) => _api.getPopularManga(page);

  @override
  Future<MangasPage> getLatestUpdates(int page) => _api.getLatestUpdates(page);

  @override
  Future<MangasPage> searchManga(int page, String query, FilterList filters) =>
      _api.searchManga(query);

  @override
  Future<Manga> getMangaDetails(Manga manga) => _api.getMangaDetails(manga);

  @override
  Future<List<Chapter>> getChapterList(Manga manga) =>
      _api.getChapterList(manga);

  @override
  Future<List<MangaPage>> getPageList(Chapter chapter) =>
      _api.getPageList(chapter);

  @override
  Future<String> getImageUrl(MangaPage page) async =>
      page.imageUrl ?? page.url ?? '';

  @override
  FilterList getFilterList() => FilterList([]);
}
