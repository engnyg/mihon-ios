import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/manga.dart';
import '../../../domain/entities/mangas_page.dart';
import '../../../domain/entities/page.dart';
import '../base/filter.dart';
import '../base/manga_source.dart';
import 'tachi_extension_def.dart';

/// A [MangaSource] driven entirely by a [TachiExtDef] JSON definition.
///
/// CSS selector syntax: `"css.selector@attribute"` extracts an attribute;
/// `"css.selector"` extracts trimmed text content; `"@attribute"` extracts
/// an attribute from the matched root element itself.
class TachiExtSource implements MangaSource {
  TachiExtSource(this.def)
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
                    'AppleWebKit/605.1.15 (KHTML, like Gecko) '
                    'Version/17.0 Mobile/15E148 Safari/604.1',
            ...def.headers,
          },
        ));

  final TachiExtDef def;
  final Dio _dio;

  // ── MangaSource identity ───────────────────────────────────────────────────

  @override
  String get id => def.id;
  @override
  String get name => def.name;
  @override
  String get lang => def.lang;
  @override
  String get baseUrl => def.baseUrl;
  @override
  bool get supportsLatest => def.latestMangaUrl != null;
  @override
  FilterList getFilterList() => FilterList([]);

  // ── URL helpers ────────────────────────────────────────────────────────────

  String _abs(String url) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) return '${def.baseUrl}$url';
    if (url.isEmpty) return '';
    return '${def.baseUrl}/$url';
  }

  String _template(String tpl, {int page = 1, String query = ''}) => tpl
      .replaceAll('{page}', page.toString())
      .replaceAll('{query}', Uri.encodeComponent(query));

  // ── Selector helpers ───────────────────────────────────────────────────────

  /// Extracts a single string value using `css@attr` or `css` (text) syntax.
  String _pick(dom.Element root, String selector) {
    final atIdx = selector.lastIndexOf('@');
    if (atIdx == -1) {
      // Text content
      final el = selector.isEmpty ? root : root.querySelector(selector);
      return el?.text.trim() ?? '';
    }
    final css = selector.substring(0, atIdx);
    final attr = selector.substring(atIdx + 1);
    final el = css.isEmpty ? root : root.querySelector(css);
    if (el == null) return '';
    // Prefer data-src over src for lazy-loaded images
    if (attr == 'src') {
      return el.attributes['data-src'] ??
          el.attributes['data-original'] ??
          el.attributes['src'] ??
          '';
    }
    return el.attributes[attr] ?? '';
  }

  /// Extracts multiple values from all matching elements.
  List<String> _pickAll(dom.Element root, String selector) {
    final atIdx = selector.lastIndexOf('@');
    if (atIdx == -1) {
      return root
          .querySelectorAll(selector)
          .map((e) => e.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final css = selector.substring(0, atIdx);
    final attr = selector.substring(atIdx + 1);
    return root.querySelectorAll(css).map((e) {
      if (attr == 'src') {
        return e.attributes['data-src'] ??
            e.attributes['data-original'] ??
            e.attributes['src'] ??
            '';
      }
      return e.attributes[attr] ?? '';
    }).where((s) => s.isNotEmpty).toList();
  }

  // ── HTTP ───────────────────────────────────────────────────────────────────

  Future<dom.Document> _get(String url) async {
    final resp = await _dio.get<String>(_abs(url));
    return html_parser.parse(resp.data ?? '');
  }

  // ── List page parsing ──────────────────────────────────────────────────────

  Future<MangasPage> _parsePage(String url) async {
    try {
      final doc = await _get(url);
      final root = doc.documentElement;
      if (root == null) return const MangasPage(mangas: [], hasNextPage: false);

      final items = doc.querySelectorAll(def.mangaListSelector);
      final mangas = <Manga>[];
      for (final el in items) {
        final title = _pick(el, def.titleSelector);
        final rawUrl = def.mangaUrlSelector != null
            ? _pick(el, def.mangaUrlSelector!)
            : (el.attributes['href'] ??
                el.querySelector('a')?.attributes['href'] ??
                '');
        if (title.isEmpty || rawUrl.isEmpty) continue;
        final thumb = def.thumbnailSelector != null
            ? _pick(el, def.thumbnailSelector!)
            : null;
        mangas.add(Manga(
          id: null,
          sourceId: def.id,
          url: _abs(rawUrl),
          title: title,
          coverUrl:
              (thumb != null && thumb.isNotEmpty) ? _abs(thumb) : null,
        ));
      }
      final hasNext = def.nextPageSelector != null
          ? doc.querySelector(def.nextPageSelector!) != null
          : false;
      return MangasPage(mangas: mangas, hasNextPage: hasNext);
    } catch (_) {
      return const MangasPage(mangas: [], hasNextPage: false);
    }
  }

  // ── MangaSource impl ───────────────────────────────────────────────────────

  @override
  Future<MangasPage> getPopularManga(int page) async {
    if (def.popularMangaUrl == null) {
      return const MangasPage(mangas: [], hasNextPage: false);
    }
    return _parsePage(_template(def.popularMangaUrl!, page: page));
  }

  @override
  Future<MangasPage> getLatestUpdates(int page) async {
    if (def.latestMangaUrl == null) {
      return const MangasPage(mangas: [], hasNextPage: false);
    }
    return _parsePage(_template(def.latestMangaUrl!, page: page));
  }

  @override
  Future<MangasPage> searchManga(
      int page, String query, FilterList filters) async {
    if (def.searchMangaUrl == null) {
      return const MangasPage(mangas: [], hasNextPage: false);
    }
    return _parsePage(_template(def.searchMangaUrl!, page: page, query: query));
  }

  @override
  Future<Manga> getMangaDetails(Manga manga) async {
    try {
      final doc = await _get(manga.url);
      final root = doc.documentElement;
      if (root == null) return manga;

      final desc = def.descriptionSelector != null
          ? _pick(root, def.descriptionSelector!)
          : null;
      final author = def.authorSelector != null
          ? _pick(root, def.authorSelector!)
          : null;
      final genres = def.genreSelector != null
          ? _pickAll(root, def.genreSelector!)
          : <String>[];
      final cover = def.thumbnailSelector != null
          ? _pick(root, def.thumbnailSelector!)
          : null;

      return manga.copyWith(
        description:
            desc != null && desc.isNotEmpty ? desc : manga.description,
        author: author != null && author.isNotEmpty ? author : manga.author,
        genres: genres.isNotEmpty ? genres : manga.genres,
        coverUrl: (cover != null && cover.isNotEmpty)
            ? _abs(cover)
            : manga.coverUrl,
      );
    } catch (_) {
      return manga;
    }
  }

  @override
  Future<List<Chapter>> getChapterList(Manga manga) async {
    try {
      final doc = await _get(manga.url);

      if (def.chapterListSelector == null) {
        // Treat entire manga as a single chapter (e.g. one-shots / doujins)
        return [
          Chapter(
            id: null,
            mangaId: manga.id ?? 0,
            url: manga.url,
            name: 'Chapter 1',
            chapterNumber: 1.0,
          ),
        ];
      }

      final items = doc.querySelectorAll(def.chapterListSelector!);
      if (items.isEmpty) {
        return [
          Chapter(
            id: null,
            mangaId: manga.id ?? 0,
            url: manga.url,
            name: 'Chapter 1',
            chapterNumber: 1.0,
          ),
        ];
      }

      final total = items.length;
      return items.asMap().entries.map((entry) {
        final i = entry.key;
        final el = entry.value;

        final title = def.chapterTitleSelector != null
            ? _pick(el, def.chapterTitleSelector!)
            : '';
        final rawUrl = def.chapterUrlSelector != null
            ? _pick(el, def.chapterUrlSelector!)
            : (el.attributes['href'] ??
                el.querySelector('a')?.attributes['href'] ??
                '');
        final numStr = def.chapterNumberSelector != null
            ? _pick(el, def.chapterNumberSelector!)
            : '';
        final chNum =
            double.tryParse(numStr) ?? (total - i).toDouble();

        DateTime? date;
        if (def.chapterDateSelector != null) {
          date = DateTime.tryParse(_pick(el, def.chapterDateSelector!));
        }

        return Chapter(
          id: null,
          mangaId: manga.id ?? 0,
          url: _abs(rawUrl.isNotEmpty ? rawUrl : manga.url),
          name: title.isNotEmpty ? title : 'Chapter ${total - i}',
          chapterNumber: chNum,
          dateUpload: date,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<MangaPage>> getPageList(Chapter chapter) async {
    try {
      final doc = await _get(chapter.url);
      if (def.pageListSelector.isEmpty) return [];

      final urls = _pickAll(
        doc.documentElement ?? dom.Element.tag('html'),
        def.pageListSelector,
      );

      return urls
          .asMap()
          .entries
          .map((e) => MangaPage(index: e.key, imageUrl: _abs(e.value)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<String> getImageUrl(MangaPage page) async {
    if (page.imageUrl != null) return page.imageUrl!;
    if (page.url != null) return page.url!;
    throw ArgumentError('Page has neither imageUrl nor url');
  }
}
