import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../../domain/entities/chapter.dart';
import '../../../../domain/entities/manga.dart';
import '../../../../domain/entities/mangas_page.dart';
import '../../../../domain/entities/page.dart';

/// LINE Webtoons API — Traditional Chinese (zh-Hant) variant.
class WebtoonsZhApi {
  static const _baseUrl = 'https://www.webtoons.com';
  static const _apiBase = 'https://www.webtoons.com/zh-hant/webtoon-api/v1';
  static const _langPath = 'zh-hant';
  static const _langCode = 'TRADITIONAL_CHINESE';
  static const _sourceId = 'webtoons_zh';

  final _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
      'Referer': '$_baseUrl/',
      'cookie': 'ageGatePass=true; locale=zh-Hant; needGDPR=false',
    },
  ));

  Future<MangasPage> getPopularManga(int page) async {
    try {
      final resp = await _dio.get<dynamic>(
        '$_apiBase/title-list',
        queryParameters: {
          'sortOrder': 'POPULAR',
          'language': _langCode,
          'offset': (page - 1) * 30,
          'limit': 30,
        },
      );
      return _parseTitleList(_toMap(resp.data));
    } catch (_) {
      return const MangasPage(mangas: [], hasNextPage: false);
    }
  }

  Future<MangasPage> getLatestUpdates(int page) async {
    try {
      final resp = await _dio.get<dynamic>(
        '$_apiBase/title-list',
        queryParameters: {
          'sortOrder': 'UPDATE',
          'language': _langCode,
          'offset': (page - 1) * 30,
          'limit': 30,
        },
      );
      return _parseTitleList(_toMap(resp.data));
    } catch (_) {
      return const MangasPage(mangas: [], hasNextPage: false);
    }
  }

  Future<MangasPage> searchManga(String query) async {
    try {
      final resp = await _dio.get<String>(
        '/$_langPath/search',
        queryParameters: {'keyword': query, 'searchType': 'WEBTOON'},
      );
      final doc = html_parser.parse(resp.data ?? '');
      final items = doc.querySelectorAll('li.on ul li, .card_item');
      final mangas = items.map((el) {
        final a = el.querySelector('a');
        final img = el.querySelector('img');
        final title =
            el.querySelector('.subj, .title')?.text.trim() ?? 'Unknown';
        final url = a?.attributes['href'] ?? '';
        final cover = img?.attributes['src'];
        return Manga(
          id: null,
          sourceId: _sourceId,
          url: url,
          title: title,
          coverUrl: cover,
        );
      }).where((m) => m.url.isNotEmpty).toList();
      return MangasPage(mangas: mangas, hasNextPage: false);
    } catch (_) {
      return const MangasPage(mangas: [], hasNextPage: false);
    }
  }

  Future<Manga> getMangaDetails(Manga manga) async {
    try {
      final resp = await _dio.get<String>(manga.url);
      final doc = html_parser.parse(resp.data ?? '');
      final description =
          doc.querySelector('.summary, .synopsis, [class*=synopsis]')?.text.trim();
      final author = doc.querySelector('.author, [class*=author]')?.text.trim();
      final cover =
          doc.querySelector('.detail_header img, .thmb img')?.attributes['src'];
      final genres =
          doc.querySelectorAll('.genre, [class*=genre]').map((e) => e.text.trim()).toList();
      return manga.copyWith(
        description: description,
        author: author,
        coverUrl: cover ?? manga.coverUrl,
        genres: genres,
      );
    } catch (_) {
      return manga;
    }
  }

  Future<List<Chapter>> getChapterList(Manga manga) async {
    try {
      final uri = Uri.tryParse(manga.url);
      final titleNo = uri?.queryParameters['title_no'] ??
          uri?.pathSegments.lastWhere(
            (s) => int.tryParse(s) != null,
            orElse: () => '',
          );
      if (titleNo == null || titleNo.isEmpty) return [];

      final resp = await _dio.get<dynamic>(
        '/$_langPath/webtoon-api/v1/episode-list',
        queryParameters: {'titleNo': titleNo, 'page': 1},
      );
      final body = _toMap(resp.data);
      final episodes =
          (body['episodeList'] as List?) ?? (body['result'] as List?) ?? [];

      return episodes.asMap().entries.map((e) {
        final ep = e.value as Map<String, dynamic>;
        return Chapter(
          id: null,
          mangaId: manga.id ?? 0,
          url: ep['episodeUrl'] as String? ??
              '${manga.url}?episode_no=${ep['episodeNo']}',
          name: ep['episodeTitle'] as String? ??
              ep['title'] as String? ??
              'Episode ${e.key + 1}',
          chapterNumber: (e.key + 1).toDouble(),
          scanlator: 'LINE Webtoons',
          dateUpload: DateTime.tryParse(ep['registerDate'] as String? ?? ''),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<MangaPage>> getPageList(Chapter chapter) async {
    try {
      final resp = await _dio.get<String>(chapter.url);
      final doc = html_parser.parse(resp.data ?? '');
      final imgs = doc.querySelectorAll(
          '#_imageList img, .viewer_lst img, [class*=viewer] img');
      int i = 0;
      return imgs.map((img) {
        final url = img.attributes['data-url'] ?? img.attributes['src'] ?? '';
        if (url.isEmpty) return null;
        return MangaPage(index: i++, imageUrl: url);
      }).whereType<MangaPage>().toList();
    } catch (_) {
      return [];
    }
  }

  MangasPage _parseTitleList(Map<String, dynamic> body) {
    final items = (body['titleList'] as List?) ??
        (body['result'] as List?) ??
        [];
    final mangas = items.map((item) {
      final m = item as Map<String, dynamic>;
      return Manga(
        id: null,
        sourceId: _sourceId,
        url: m['url'] as String? ??
            '$_baseUrl/$_langPath/${m['genreCode'] ?? 'drama'}/${m['titleNo']}',
        title: m['title'] as String? ?? '',
        coverUrl: m['thumbnail'] as String? ?? m['thumbnailUrl'] as String?,
        author: m['author'] as String?,
      );
    }).toList();
    return MangasPage(mangas: mangas, hasNextPage: items.length >= 30);
  }

  Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) return jsonDecode(data) as Map<String, dynamic>;
    return {};
  }
}
