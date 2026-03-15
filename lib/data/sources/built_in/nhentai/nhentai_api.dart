import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../domain/entities/chapter.dart';
import '../../../../domain/entities/manga.dart';
import '../../../../domain/entities/mangas_page.dart';
import '../../../../domain/entities/page.dart';

class NHentaiApi {
  static const _apiUrl = 'https://nhentai.net';
  static const _imgUrl = 'https://i.nhentai.net';
  static const _thumbUrl = 'https://t.nhentai.net';
  static const sourceId = 'nhentai';

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
      'Referer': 'https://nhentai.net/',
    },
  ));

  Future<MangasPage> getPopular(int page) =>
      _fetchList('/api/galleries/all', {'page': page, 'sort': 'popular-today'}, page);

  Future<MangasPage> getLatest(int page) =>
      _fetchList('/api/galleries/all', {'page': page, 'sort': 'date'}, page);

  Future<MangasPage> search(int page, String query) {
    if (query.isEmpty) return getLatest(page);
    return _fetchList('/api/galleries/search', {'query': query, 'page': page}, page);
  }

  Future<MangasPage> _fetchList(
      String path, Map<String, dynamic> params, int page) async {
    try {
      final resp = await _dio.get<dynamic>('$_apiUrl$path', queryParameters: params);
      final json = _toMap(resp.data);
      final results = (json['result'] as List<dynamic>?) ?? [];
      final totalItems = (json['num_pages'] as num?)?.toInt() ?? 0;
      final perPage = (json['per_page'] as num?)?.toInt() ?? 25;
      return MangasPage(
        mangas: results.map((e) => _parseGallery(e as Map<String, dynamic>)).toList(),
        hasNextPage: page * perPage < totalItems,
      );
    } catch (_) {
      return const MangasPage(mangas: [], hasNextPage: false);
    }
  }

  Future<Manga> getDetail(Manga manga) async {
    try {
      final id = _id(manga.url);
      final resp = await _dio.get<dynamic>('$_apiUrl/api/gallery/$id');
      return _parseGallery(_toMap(resp.data), existing: manga);
    } catch (_) {
      return manga;
    }
  }

  // NHentai: each gallery is one "chapter"
  List<Chapter> chaptersFor(Manga manga) => [
        Chapter(
          id: null,
          mangaId: manga.id ?? 0,
          url: manga.url,
          name: 'Read',
          chapterNumber: 1.0,
        ),
      ];

  Future<List<MangaPage>> getPages(String galleryUrl) async {
    try {
      final id = _id(galleryUrl);
      final resp = await _dio.get<dynamic>('$_apiUrl/api/gallery/$id');
      final json = _toMap(resp.data);
      final mediaId = json['media_id'] as String;
      final pages = (json['images']['pages'] as List<dynamic>);
      return pages.asMap().entries.map((e) {
        final ext = _ext(e.value['t'] as String? ?? 'j');
        return MangaPage(
          index: e.key,
          imageUrl: '$_imgUrl/galleries/$mediaId/${e.key + 1}.$ext',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Manga _parseGallery(Map<String, dynamic> j, {Manga? existing}) {
    final id = (j['id'] as num).toString();
    final mediaId = j['media_id'] as String? ?? '';
    final titleMap = (j['title'] as Map<String, dynamic>?) ?? {};
    final title = titleMap['english'] as String? ??
        titleMap['pretty'] as String? ??
        titleMap['japanese'] as String? ??
        '';
    final coverExt = _ext((j['images']?['cover']?['t'] as String?) ?? 'j');
    final coverUrl = '$_thumbUrl/galleries/$mediaId/cover.$coverExt';
    final uploadDate = (j['upload_date'] as num?)?.toInt();

    final allTags = (j['tags'] as List<dynamic>?) ?? [];
    final genres = allTags
        .map((t) => (t as Map)['name'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    final artists = allTags
        .where((t) => (t as Map)['type'] == 'artist')
        .map((t) => (t as Map)['name'] as String? ?? '')
        .toList();

    final base = existing ??
        const Manga(id: null, sourceId: sourceId, url: '', title: '');
    return base.copyWith(
      url: '/g/$id',
      title: title,
      coverUrl: coverUrl,
      author: artists.isNotEmpty ? artists.join(', ') : null,
      genres: genres,
      status: MangaStatus.completed,
      lastUpdated: uploadDate != null
          ? DateTime.fromMillisecondsSinceEpoch(uploadDate * 1000)
          : null,
    );
  }

  String _id(String url) =>
      url.split('/').where((s) => s.isNotEmpty).last;

  String _ext(String t) => switch (t) {
        'p' => 'png',
        'g' => 'gif',
        'w' => 'webp',
        _ => 'jpg',
      };

  Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) return jsonDecode(data) as Map<String, dynamic>;
    throw Exception('NHentai: unexpected response type ${data.runtimeType}');
  }
}
