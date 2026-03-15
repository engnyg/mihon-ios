import 'dart:convert';

/// Declarative JSON-based extension definition (Tachimanga format).
///
/// URL templates support `{page}` and `{query}` placeholders.
/// CSS selector strings support `selector@attribute` syntax to extract
/// element attributes (e.g. `img@src`), or plain `selector` for text content.
/// An empty selector prefix means "the element itself" (e.g. `@href`).
class TachiExtDef {
  const TachiExtDef({
    required this.id,
    required this.name,
    required this.lang,
    required this.baseUrl,
    this.version = '1.0',
    this.nsfw = false,
    this.popularMangaUrl,
    this.latestMangaUrl,
    this.searchMangaUrl,
    this.mangaListSelector = '',
    this.mangaUrlSelector,
    this.titleSelector = '',
    this.thumbnailSelector,
    this.nextPageSelector,
    this.descriptionSelector,
    this.authorSelector,
    this.statusSelector,
    this.genreSelector,
    this.chapterListSelector,
    this.chapterTitleSelector,
    this.chapterUrlSelector,
    this.chapterDateSelector,
    this.chapterNumberSelector,
    this.pageListSelector = '',
    this.headers = const {},
  });

  final String id;
  final String name;
  final String lang;
  final String baseUrl;
  final String version;
  final bool nsfw;

  // ── Browse / search URL templates ──────────────────────────────────────────
  final String? popularMangaUrl;
  final String? latestMangaUrl;
  final String? searchMangaUrl;

  // ── Manga list selectors ───────────────────────────────────────────────────
  /// CSS selector for each manga item on a list page.
  final String mangaListSelector;

  /// Selector+attr for the manga's detail page URL.
  /// Defaults to `@href` on the list item element if null.
  final String? mangaUrlSelector;

  /// Selector+attr for the manga title.
  final String titleSelector;

  /// Selector+attr for the manga cover image URL.
  final String? thumbnailSelector;

  /// If this element exists in the DOM the page has a next page.
  final String? nextPageSelector;

  // ── Manga detail selectors ─────────────────────────────────────────────────
  final String? descriptionSelector;
  final String? authorSelector;
  final String? statusSelector;

  /// For multi-value genres; querySelectorAll is used.
  final String? genreSelector;

  // ── Chapter list selectors ─────────────────────────────────────────────────
  /// If null, the entire manga URL is treated as a single chapter.
  final String? chapterListSelector;
  final String? chapterTitleSelector;
  final String? chapterUrlSelector;
  final String? chapterDateSelector;
  final String? chapterNumberSelector;

  // ── Reader page selector ───────────────────────────────────────────────────
  /// Selector+attr for each page image URL on a chapter reader page.
  final String pageListSelector;

  // ── Optional HTTP headers ──────────────────────────────────────────────────
  final Map<String, String> headers;

  // ── Serialisation ──────────────────────────────────────────────────────────

  factory TachiExtDef.fromJson(Map<String, dynamic> j) => TachiExtDef(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        lang: j['lang'] as String? ?? 'en',
        baseUrl: (j['baseUrl'] as String? ?? '').replaceAll(RegExp(r'/$'), ''),
        version: j['version']?.toString() ?? '1.0',
        nsfw: _parseBool(j['nsfw']),
        popularMangaUrl: j['popularMangaUrl'] as String?,
        latestMangaUrl: j['latestMangaUrl'] as String?,
        searchMangaUrl: j['searchMangaUrl'] as String?,
        mangaListSelector: j['mangaListSelector'] as String? ?? '',
        mangaUrlSelector: j['mangaUrlSelector'] as String?,
        titleSelector: j['titleSelector'] as String? ?? '',
        thumbnailSelector: j['thumbnailSelector'] as String?,
        nextPageSelector: j['nextPageSelector'] as String?,
        descriptionSelector: j['descriptionSelector'] as String?,
        authorSelector: j['authorSelector'] as String?,
        statusSelector: j['statusSelector'] as String?,
        genreSelector: j['genreSelector'] as String?,
        chapterListSelector: j['chapterListSelector'] as String?,
        chapterTitleSelector: j['chapterTitleSelector'] as String?,
        chapterUrlSelector: j['chapterUrlSelector'] as String?,
        chapterDateSelector: j['chapterDateSelector'] as String?,
        chapterNumberSelector: j['chapterNumberSelector'] as String?,
        pageListSelector: j['pageListSelector'] as String? ?? '',
        headers: (j['headers'] as Map<String, dynamic>?)
                ?.cast<String, String>() ??
            {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lang': lang,
        'baseUrl': baseUrl,
        'version': version,
        'nsfw': nsfw,
        if (popularMangaUrl != null) 'popularMangaUrl': popularMangaUrl,
        if (latestMangaUrl != null) 'latestMangaUrl': latestMangaUrl,
        if (searchMangaUrl != null) 'searchMangaUrl': searchMangaUrl,
        'mangaListSelector': mangaListSelector,
        if (mangaUrlSelector != null) 'mangaUrlSelector': mangaUrlSelector,
        'titleSelector': titleSelector,
        if (thumbnailSelector != null) 'thumbnailSelector': thumbnailSelector,
        if (nextPageSelector != null) 'nextPageSelector': nextPageSelector,
        if (descriptionSelector != null)
          'descriptionSelector': descriptionSelector,
        if (authorSelector != null) 'authorSelector': authorSelector,
        if (statusSelector != null) 'statusSelector': statusSelector,
        if (genreSelector != null) 'genreSelector': genreSelector,
        if (chapterListSelector != null)
          'chapterListSelector': chapterListSelector,
        if (chapterTitleSelector != null)
          'chapterTitleSelector': chapterTitleSelector,
        if (chapterUrlSelector != null) 'chapterUrlSelector': chapterUrlSelector,
        if (chapterDateSelector != null) 'chapterDateSelector': chapterDateSelector,
        if (chapterNumberSelector != null)
          'chapterNumberSelector': chapterNumberSelector,
        'pageListSelector': pageListSelector,
        if (headers.isNotEmpty) 'headers': headers,
      };

  String toJsonString() => jsonEncode(toJson());

  static bool _parseBool(dynamic v) {
    if (v is bool) return v;
    if (v is int) return v != 0;
    return false;
  }

  @override
  String toString() => 'TachiExtDef($id, $name, $lang)';
}
