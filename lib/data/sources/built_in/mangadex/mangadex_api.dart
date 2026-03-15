import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../domain/entities/chapter.dart';
import '../../../../domain/entities/manga.dart';
import '../../../../domain/entities/mangas_page.dart';
import '../../../../domain/entities/page.dart';

/// Wraps the MangaDex REST API v5.
/// Docs: https://api.mangadex.org/docs/
class MangaDexApi {
  static const _baseUrl = 'https://api.mangadex.org';
  static const _coverBaseUrl = 'https://uploads.mangadex.org/covers';
  static const _limit = 20;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {'User-Agent': 'mihon-ios/0.1.0'},
    ),
  );

  // ── Manga list ─────────────────────────────────────────────────────────────

  Future<MangasPage> getMangaList(
    int page, {
    String? query,
    Map<String, String>? order,
  }) async {
    final offset = (page - 1) * _limit;

    final params = <String, dynamic>{
      'limit': _limit,
      'offset': offset,
      'includes[]': ['cover_art', 'author', 'artist'],
      'availableTranslatedLanguage[]': ['en'],
      'contentRating[]': ['safe', 'suggestive'],
    };

    if (query != null) params['title'] = query;

    if (order != null) {
      order.forEach((key, value) => params['order[$key]'] = value);
    } else {
      params['order[followedCount]'] = 'desc';
    }

    final response = await _get('/manga', queryParameters: params);
    final data = response['data'] as List<dynamic>;
    final total = response['total'] as int;

    final mangas = data
        .map((e) => _parseManga(e as Map<String, dynamic>))
        .toList();

    return MangasPage(
      mangas: mangas,
      hasNextPage: offset + _limit < total,
    );
  }

  // ── Manga detail ───────────────────────────────────────────────────────────

  Future<Manga> getMangaDetail(Manga manga) async {
    final id = _extractMangaId(manga.url);
    final response = await _get(
      '/manga/$id',
      queryParameters: {
        'includes[]': ['cover_art', 'author', 'artist'],
      },
    );
    return _parseManga(response['data'] as Map<String, dynamic>);
  }

  // ── Chapter list ──────────────────────────────────────────────────────────

  Future<List<Chapter>> getChapterList(Manga manga) async {
    final mangaId = _extractMangaId(manga.url);
    final chapters = <Chapter>[];
    int offset = 0;
    const limit = 100;

    while (true) {
      final response = await _get(
        '/manga/$mangaId/feed',
        queryParameters: {
          'limit': limit,
          'offset': offset,
          'translatedLanguage[]': ['en'],
          'order[chapter]': 'desc',
          'includes[]': ['scanlation_group'],
          'contentRating[]': ['safe', 'suggestive'],
        },
      );

      final data = response['data'] as List<dynamic>;
      final total = response['total'] as int;

      for (final item in data) {
        final chapter = _parseChapter(
          item as Map<String, dynamic>,
          manga.id ?? 0,
        );
        chapters.add(chapter);
      }

      offset += limit;
      if (offset >= total) break;
    }

    return chapters;
  }

  // ── Page list ─────────────────────────────────────────────────────────────

  Future<List<MangaPage>> getPageList(Chapter chapter) async {
    final chapterId = _extractChapterId(chapter.url);
    final response = await _get('/at-home/server/$chapterId');

    final baseUrl = response['baseUrl'] as String;
    final chapterData = response['chapter'] as Map<String, dynamic>;
    final hash = chapterData['hash'] as String;
    final data = chapterData['data'] as List<dynamic>;

    return data.asMap().entries.map((entry) {
      final filename = entry.value as String;
      return MangaPage(
        index: entry.key,
        url: '$baseUrl/data/$hash/$filename',
        imageUrl: '$baseUrl/data/$hash/$filename',
      );
    }).toList();
  }

  // ── Parsers ───────────────────────────────────────────────────────────────

  Manga _parseManga(Map<String, dynamic> data) {
    final id = data['id'] as String;
    final attrs = data['attributes'] as Map<String, dynamic>;
    final relationships = data['relationships'] as List<dynamic>? ?? [];

    // Title — prefer English
    final titleMap = attrs['title'] as Map<String, dynamic>? ?? {};
    final title = (titleMap['en'] ??
            titleMap.values.firstOrNull ??
            'Unknown') as String;

    // Description
    final descMap = attrs['description'] as Map<String, dynamic>? ?? {};
    final description = descMap['en'] as String?;

    // Author / Artist
    String? author;
    String? artist;
    String? coverId;

    for (final rel in relationships) {
      final relMap = rel as Map<String, dynamic>;
      final type = relMap['type'] as String;
      final relAttrs = relMap['attributes'] as Map<String, dynamic>?;

      switch (type) {
        case 'author':
          author = relAttrs?['name'] as String?;
        case 'artist':
          artist = relAttrs?['name'] as String?;
        case 'cover_art':
          coverId = relAttrs?['fileName'] as String?;
      }
    }

    final coverUrl =
        coverId != null ? '$_coverBaseUrl/$id/$coverId.256.jpg' : null;

    // Genres / Tags
    final tags = (attrs['tags'] as List<dynamic>? ?? [])
        .map((t) {
          final tagAttrs =
              (t as Map<String, dynamic>)['attributes'] as Map<String, dynamic>;
          final nameMap = tagAttrs['name'] as Map<String, dynamic>;
          return nameMap['en'] as String? ?? '';
        })
        .where((t) => t.isNotEmpty)
        .toList();

    // Status
    final statusStr = attrs['status'] as String? ?? 'unknown';
    final status = switch (statusStr) {
      'ongoing' => MangaStatus.ongoing,
      'completed' => MangaStatus.completed,
      'cancelled' => MangaStatus.cancelled,
      'hiatus' => MangaStatus.onHiatus,
      _ => MangaStatus.unknown,
    };

    return Manga(
      id: null,
      sourceId: 'mangadex',
      url: '/manga/$id',
      title: title,
      coverUrl: coverUrl,
      author: author,
      artist: artist,
      description: description,
      genres: tags,
      status: status,
    );
  }

  Chapter _parseChapter(Map<String, dynamic> data, int mangaId) {
    final id = data['id'] as String;
    final attrs = data['attributes'] as Map<String, dynamic>;
    final relationships = data['relationships'] as List<dynamic>? ?? [];

    final chapterStr = attrs['chapter'] as String?;
    final volumeStr = attrs['volume'] as String?;
    final title = attrs['title'] as String?;
    final pages = (attrs['pages'] as num?)?.toInt() ?? 0;

    // Scanlation group name
    String? scanlator;
    for (final rel in relationships) {
      final relMap = rel as Map<String, dynamic>;
      if (relMap['type'] == 'scanlation_group') {
        final relAttrs = relMap['attributes'] as Map<String, dynamic>?;
        scanlator = relAttrs?['name'] as String?;
        break;
      }
    }

    final chapterNum = chapterStr != null ? double.tryParse(chapterStr) : null;
    final volumeNum = volumeStr != null ? double.tryParse(volumeStr) : null;

    final publishDate = attrs['publishAt'] as String?;

    // Build display name
    final nameParts = <String>[];
    if (volumeStr != null) nameParts.add('Vol.$volumeStr');
    if (chapterStr != null) nameParts.add('Ch.$chapterStr');
    if (title != null && title.isNotEmpty) nameParts.add(title);
    final name = nameParts.isEmpty ? 'Oneshot' : nameParts.join(' ');

    return Chapter(
      id: null,
      mangaId: mangaId,
      url: '/chapter/$id',
      name: name,
      chapterNumber: chapterNum,
      volume: volumeNum,
      scanlator: scanlator,
      totalPages: pages,
      dateUpload: publishDate != null ? DateTime.tryParse(publishDate) : null,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _extractMangaId(String url) {
    // url: /manga/{uuid}
    return url.split('/').last;
  }

  String _extractChapterId(String url) {
    // url: /chapter/{uuid}
    return url.split('/').last;
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.json),
      );
      if (response.data == null) throw const ParseException('Empty response');
      return response.data!;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw const RateLimitException(retryAfterSeconds: 60);
      }
      throw ServerException(e.message);
    }
  }
}
