import '../../domain/entities/chapter.dart';
import '../../domain/entities/manga.dart';
import '../../domain/entities/mangas_page.dart';
import '../../domain/entities/page.dart';
import 'base/filter.dart';
import 'base/manga_source.dart';

/// Placeholder source for installed keiyoushi extensions that don't have
/// a native iOS (Dart) implementation yet.
/// Shows up in Sources so the user knows the extension is installed,
/// but throws a descriptive error when browsed.
class StubSource implements MangaSource {
  const StubSource({
    required this.id,
    required this.name,
    required this.lang,
    required this.baseUrl,
    required this.extensionName,
  });

  @override
  final String id;
  @override
  final String name;
  @override
  final String lang;
  @override
  final String baseUrl;

  /// The parent extension name (for the error message).
  final String extensionName;

  @override
  bool get supportsLatest => false;

  @override
  FilterList getFilterList() => FilterList([]);

  Never _notSupported() => throw Exception(
      '"$extensionName" is installed but does not have a native iOS '
      'implementation yet. Only built-in sources (MangaDex, MANGA Plus, '
      'LINE Webtoons) are fully functional on iOS.');

  @override
  Future<MangasPage> getPopularManga(int page) async => _notSupported();

  @override
  Future<MangasPage> getLatestUpdates(int page) async => _notSupported();

  @override
  Future<MangasPage> searchManga(
          int page, String query, FilterList filters) async =>
      _notSupported();

  @override
  Future<Manga> getMangaDetails(Manga manga) async => manga;

  @override
  Future<List<Chapter>> getChapterList(Manga manga) async => [];

  @override
  Future<List<MangaPage>> getPageList(Chapter chapter) async => [];
}
