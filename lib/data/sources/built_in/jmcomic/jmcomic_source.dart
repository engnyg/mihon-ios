import '../../../../domain/entities/chapter.dart';
import '../../../../domain/entities/manga.dart';
import '../../../../domain/entities/mangas_page.dart';
import '../../../../domain/entities/page.dart';
import '../../base/filter.dart';
import '../../base/manga_source.dart';
import 'jmcomic_api.dart';

class JMComicSource implements MangaSource {
  @override
  String get id => JMComicApi.sourceId;
  @override
  String get name => '禁漫天堂';
  @override
  String get lang => 'zh';
  @override
  String get baseUrl => 'https://18comic.vip';
  @override
  bool get supportsLatest => true;

  final _api = JMComicApi();

  @override
  Future<MangasPage> getPopularManga(int page) => _api.getPopular(page);

  @override
  Future<MangasPage> getLatestUpdates(int page) => _api.getLatest(page);

  @override
  Future<MangasPage> searchManga(int page, String query, FilterList filters) =>
      _api.search(page, query);

  @override
  Future<Manga> getMangaDetails(Manga manga) => _api.getDetail(manga);

  @override
  Future<List<Chapter>> getChapterList(Manga manga) =>
      _api.getChapterList(manga);

  @override
  Future<List<MangaPage>> getPageList(Chapter chapter) =>
      _api.getPages(chapter);

  @override
  Future<String> getImageUrl(MangaPage page) async =>
      page.imageUrl ?? page.url ?? '';

  @override
  FilterList getFilterList() => FilterList([]);
}
