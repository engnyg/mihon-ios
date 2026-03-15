import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../domain/entities/chapter.dart';
import '../../../../domain/entities/manga.dart';
import '../../../../domain/entities/mangas_page.dart';
import '../../../../domain/entities/page.dart';

/// Native Dart implementation for CopyManga (拷貝漫畫).
/// API base: https://api.copymanga.info/api/v3/
class CopyMangaApi {
  static const _apiUrl = 'https://api.copymanga.info';
  static const sourceId = 'copymanga';
  static const _limit = 21;

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'user-agent': 'ANDROID  1.7.0',
      'region': '1',
      'webp': '1',
      'version': '2.1.0',
      'platform': '3',
    },
  ));

  // ── Browse ──────────────────────────────────────────────────────────────────

  Future<MangasPage> getPopular(int page) =>
      _fetchComics('-popular', page);

  Future<MangasPage> getLatest(int page) =>
      _fetchComics('-datetime_updated', page);

  Future<MangasPage> search(int page, String query) async {
    final offset = (page - 1) * _limit;
    try {
      final resp = await _dio.get<dynamic>(
        '$_apiUrl/api/v3/search/comic',
        queryParameters: {
          'platform': 3,
          'q': query,
          'limit': _limit,
          'offset': offset,
          'q_type': '',
        },
      );
      return _parseList(_toMap(resp.data), page);
    } catch (_) {
      return const MangasPage(mangas: [], hasNextPage: false);
    }
  }

  Future<MangasPage> _fetchComics(String ordering, int page) async {
    final offset = (page - 1) * _limit;
    try {
      final resp = await _dio.get<dynamic>(
        '$_apiUrl/api/v3/comics',
        queryParameters: {
          'ordering': ordering,
          'platform': 3,
          'limit': _limit,
          'offset': offset,
        },
      );
      return _parseList(_toMap(resp.data), page);
    } catch (_) {
      return const MangasPage(mangas: [], hasNextPage: false);
    }
  }

  MangasPage _parseList(Map<String, dynamic> body, int page) {
    final results = (body['results'] as Map<String, dynamic>?) ?? {};
    final list = (results['list'] as List<dynamic>?) ?? [];
    final total = (results['total'] as num?)?.toInt() ?? 0;
    final offset = (page - 1) * _limit;
    return MangasPage(
      mangas: list.map((e) => _parseComic(e as Map<String, dynamic>)).toList(),
      hasNextPage: offset + list.length < total,
    );
  }

  // ── Detail ──────────────────────────────────────────────────────────────────

  Future<Manga> getDetail(Manga manga) async {
    try {
      final resp = await _dio.get<dynamic>(
        '$_apiUrl/api/v3/comic2/${manga.url}',
        queryParameters: {'platform': 3},
      );
      final results = (_toMap(resp.data)['results'] as Map<String, dynamic>?) ?? {};
      final comic = (results['comic'] as Map<String, dynamic>?) ?? {};
      return manga.copyWith(
        title: comic['name'] as String? ?? manga.title,
        coverUrl: comic['cover'] as String? ?? manga.coverUrl,
        description: comic['brief'] as String?,
        author: _authorsStr(comic['author']),
        genres: _themeList(comic['theme']),
        status: _parseStatus(comic['status']),
      );
    } catch (_) {
      return manga;
    }
  }

  // ── Chapters ────────────────────────────────────────────────────────────────

  Future<List<Chapter>> getChapterList(Manga manga) async {
    // Try to find the chapter group (default first)
    String? groupPathWord = await _getDefaultGroup(manga.url);
    groupPathWord ??= 'default';

    try {
      final resp = await _dio.get<dynamic>(
        '$_apiUrl/api/v3/comic/${manga.url}/group/$groupPathWord/chapters',
        queryParameters: {'limit': 500, 'offset': 0, 'platform': 3},
      );
      final results = (_toMap(resp.data)['results'] as Map<String, dynamic>?) ?? {};
      final list = (results['list'] as List<dynamic>?) ?? [];

      return list.asMap().entries.map((e) {
        final ch = e.value as Map<String, dynamic>;
        final uuid = ch['uuid'] as String? ?? '';
        final dateStr = ch['datetime_created'] as String?;
        return Chapter(
          id: null,
          mangaId: manga.id ?? 0,
          url: '${manga.url}/$uuid',
          name: ch['name'] as String? ?? 'Chapter ${e.key + 1}',
          chapterNumber: (ch['index'] as num?)?.toDouble() ?? e.key.toDouble(),
          totalPages: (ch['count'] as num?)?.toInt() ?? 0,
          dateUpload: dateStr != null ? DateTime.tryParse(dateStr) : null,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> _getDefaultGroup(String pathWord) async {
    try {
      final resp = await _dio.get<dynamic>(
        '$_apiUrl/api/v3/comic/$pathWord/groups',
      );
      final results = (_toMap(resp.data)['results'] as Map<String, dynamic>?) ?? {};
      // results is a map of group_path_word → group info
      if (results.containsKey('default')) return 'default';
      return results.keys.firstOrNull;
    } catch (_) {
      return null;
    }
  }

  // ── Pages ────────────────────────────────────────────────────────────────────

  Future<List<MangaPage>> getPages(Chapter chapter) async {
    // chapter.url format: "{path_word}/{uuid}"
    final parts = chapter.url.split('/');
    if (parts.length < 2) return [];
    final uuid = parts.last;
    final pathWord = parts.sublist(0, parts.length - 1).join('/');

    try {
      final resp = await _dio.get<dynamic>(
        '$_apiUrl/api/v3/comic/$pathWord/chapter2/$uuid',
        queryParameters: {'platform': 3},
      );
      final results = (_toMap(resp.data)['results'] as Map<String, dynamic>?) ?? {};
      final chapterData = (results['chapter'] as Map<String, dynamic>?) ?? {};
      final contents = (chapterData['contents'] as List<dynamic>?) ?? [];
      return contents.asMap().entries.map((e) {
        final url = (e.value as Map<String, dynamic>)['url'] as String? ?? '';
        return MangaPage(index: e.key, imageUrl: url);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Parsers ──────────────────────────────────────────────────────────────────

  Manga _parseComic(Map<String, dynamic> m) {
    return Manga(
      id: null,
      sourceId: sourceId,
      url: m['path_word'] as String? ?? '',
      title: m['name'] as String? ?? '',
      coverUrl: m['cover'] as String?,
      author: _authorsStr(m['author']),
      genres: _themeList(m['theme']),
      status: _parseStatus(m['status']),
    );
  }

  String? _authorsStr(dynamic authors) {
    if (authors is! List) return null;
    final names = authors
        .map((a) => (a as Map<String, dynamic>)['name'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    return names.isEmpty ? null : names.join(', ');
  }

  List<String> _themeList(dynamic themes) {
    if (themes is! List) return [];
    return themes
        .map((t) => (t as Map<String, dynamic>)['name'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  MangaStatus _parseStatus(dynamic status) {
    if (status is Map) {
      final val = status['value'];
      if (val == 1) return MangaStatus.completed;
    }
    return MangaStatus.ongoing;
  }

  Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) return jsonDecode(data) as Map<String, dynamic>;
    throw Exception('CopyManga: unexpected ${data.runtimeType}');
  }
}
