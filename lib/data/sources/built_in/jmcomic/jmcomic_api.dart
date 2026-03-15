import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../../domain/entities/chapter.dart';
import '../../../../domain/entities/manga.dart';
import '../../../../domain/entities/mangas_page.dart';
import '../../../../domain/entities/page.dart';

/// Native Dart implementation for JMComic (禁漫天堂 / 18comic).
/// Scrapes the web interface; requires a VPN in mainland China.
/// Note: images for older albums (id ≲ 320000) may appear scrambled —
/// full descrambling requires Flutter canvas manipulation (not yet implemented).
class JMComicApi {
  static const _baseUrl = 'https://18comic.vip';
  static const sourceId = 'jmcomic';

  final _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    followRedirects: true,
    headers: {
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
      'Referer': '$_baseUrl/',
    },
  ));

  // Inject cookies required by the site
  JMComicApi() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['cookie'] = 'isAdult=1; age_gate_pass=1';
        handler.next(options);
      },
    ));
  }

  // ── Browse ──────────────────────────────────────────────────────────────────

  Future<MangasPage> getPopular(int page) =>
      _fetchAlbums('/albums?o=mv&page=$page', page);

  Future<MangasPage> getLatest(int page) =>
      _fetchAlbums('/albums?o=mr&page=$page', page);

  Future<MangasPage> search(int page, String query) =>
      _fetchAlbums(
          '/search/photos?main_tag=0&search_query=${Uri.encodeComponent(query)}&page=$page',
          page);

  Future<MangasPage> _fetchAlbums(String path, int page) async {
    try {
      final resp = await _dio.get<String>(path);
      final doc = html_parser.parse(resp.data ?? '');

      // Album grid items
      final items = doc.querySelectorAll(
          '.col-xs-6.col-sm-6.col-md-3, .list-col-3, .comic-block');

      final mangas = items.map((el) {
        final a = el.querySelector('a[href*="/album/"]');
        final img = el.querySelector('img');
        final titleEl = el.querySelector('.video-title, .title, [class*=title]');

        final href = a?.attributes['href'] ?? '';
        final title = titleEl?.text.trim() ??
            img?.attributes['alt']?.trim() ??
            '';
        final cover = img?.attributes['data-original'] ??
            img?.attributes['data-src'] ??
            img?.attributes['src'];
        final urlPath = _toRelative(href);

        return Manga(
          id: null,
          sourceId: sourceId,
          url: urlPath,
          title: title,
          coverUrl: cover,
        );
      }).where((m) => m.url.isNotEmpty && m.title.isNotEmpty).toList();

      final hasNext =
          doc.querySelector('.pager a[rel=next], .pagination .next') != null;

      return MangasPage(mangas: mangas, hasNextPage: hasNext);
    } catch (_) {
      return const MangasPage(mangas: [], hasNextPage: false);
    }
  }

  // ── Detail ──────────────────────────────────────────────────────────────────

  Future<Manga> getDetail(Manga manga) async {
    try {
      final resp = await _dio.get<String>(manga.url);
      final doc = html_parser.parse(resp.data ?? '');

      final title =
          doc.querySelector('#album_title, .video-title')?.text.trim() ??
              manga.title;
      final cover = doc
          .querySelector('.thumb-overlay img, .cover img, .album-cover img')
          ?.attributes['src'];
      final description =
          doc.querySelector('#intro-block, .p-description')?.text.trim();
      final author = doc
          .querySelectorAll('a[href*="/?search_query="], a[href*="/author/"]')
          .map((e) => e.text.trim())
          .where((s) => s.isNotEmpty)
          .join(', ');
      final genres = doc
          .querySelectorAll('a[href*="/search/?main_tag="], a[href*="/tag/"]')
          .map((e) => e.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      return manga.copyWith(
        title: title.isNotEmpty ? title : manga.title,
        coverUrl: cover ?? manga.coverUrl,
        description: description,
        author: author.isNotEmpty ? author : manga.author,
        genres: genres,
      );
    } catch (_) {
      return manga;
    }
  }

  // ── Chapters ────────────────────────────────────────────────────────────────

  Future<List<Chapter>> getChapterList(Manga manga) async {
    try {
      final resp = await _dio.get<String>(manga.url);
      final doc = html_parser.parse(resp.data ?? '');

      final links = doc.querySelectorAll(
          'a[href*="/photo/"], .chapter-item a, .chapter_list a');

      if (links.isEmpty) {
        // Single-chapter album — the album itself is the chapter
        return [
          Chapter(
            id: null,
            mangaId: manga.id ?? 0,
            url: manga.url,
            name: 'Read',
            chapterNumber: 1.0,
          ),
        ];
      }

      return links.asMap().entries.map((e) {
        final href = e.value.attributes['href'] ?? '';
        final name =
            e.value.text.trim().isNotEmpty ? e.value.text.trim() : 'Chapter ${e.key + 1}';
        return Chapter(
          id: null,
          mangaId: manga.id ?? 0,
          url: _toRelative(href),
          name: name,
          chapterNumber: (e.key + 1).toDouble(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Pages ────────────────────────────────────────────────────────────────────

  Future<List<MangaPage>> getPages(Chapter chapter) async {
    try {
      final resp = await _dio.get<String>(chapter.url);
      final doc = html_parser.parse(resp.data ?? '');

      final imgs = doc.querySelectorAll(
          '#image-list img, .read-img img, [class*=scramble] img, .viewer img');

      int i = 0;
      return imgs.map((img) {
        final url = img.attributes['data-original'] ??
            img.attributes['data-src'] ??
            img.attributes['src'] ??
            '';
        if (url.isEmpty) return null;
        return MangaPage(index: i++, imageUrl: url);
      }).whereType<MangaPage>().toList();
    } catch (_) {
      return [];
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _toRelative(String href) {
    if (href.startsWith('http')) {
      try {
        return Uri.parse(href).path;
      } catch (_) {}
    }
    return href;
  }
}
