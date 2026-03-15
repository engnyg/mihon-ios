import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../domain/entities/chapter.dart';
import '../../../../domain/entities/manga.dart';
import '../../../../domain/entities/mangas_page.dart';
import '../../../../domain/entities/page.dart';

/// Native Dart implementation of the MANGA Plus (Shueisha) API.
/// Uses the same protobuf-encoded REST endpoints as the keiyoushi extension.
class MangaPlusApi {
  static const _apiUrl = 'https://jumpg-webapi.tokyo-cdn.com';
  static const _baseUrl = 'https://mangaplus.shueisha.co.jp';
  static const _sourceId = 'mangaplus';

  final _dio = Dio(BaseOptions(
    headers: {
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
      'Origin': _baseUrl,
      'Referer': '$_baseUrl/',
    },
    responseType: ResponseType.bytes,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  // ── Public API ──────────────────────────────────────────────────────────────

  Future<MangasPage> getPopularManga(int page) async {
    if (page > 1) return const MangasPage(mangas: [], hasNextPage: false);
    final bytes = await _fetchBytes('$_apiUrl/api/title_list/ranking');
    final data = _parseResponse(bytes);
    final mangas =
        ((data['allTitles'] as List?) ?? []).map(_titleToManga).toList();
    return MangasPage(mangas: mangas, hasNextPage: false);
  }

  Future<MangasPage> getLatestUpdates(int page) async {
    if (page > 1) return const MangasPage(mangas: [], hasNextPage: false);
    final bytes = await _fetchBytes('$_apiUrl/api/title_list/allV2');
    final data = _parseResponse(bytes);
    final mangas =
        ((data['allTitles'] as List?) ?? []).map(_titleToManga).toList();
    return MangasPage(mangas: mangas, hasNextPage: false);
  }

  Future<MangasPage> searchManga(String query) async {
    final bytes = await _fetchBytes('$_apiUrl/api/title_list/allV2');
    final data = _parseResponse(bytes);
    final q = query.toLowerCase();
    final mangas = ((data['allTitles'] as List?) ?? [])
        .where((t) =>
            ((t as Map<String, dynamic>)['name'] as String? ?? '')
                .toLowerCase()
                .contains(q))
        .map(_titleToManga)
        .toList();
    return MangasPage(mangas: mangas, hasNextPage: false);
  }

  Future<Manga> getMangaDetails(Manga manga) async {
    final titleId = _extractTitleId(manga.url);
    final bytes =
        await _fetchBytes('$_apiUrl/api/title_detailV3?title_id=$titleId');
    final data = _parseResponse(bytes);
    final detail = (data['titleDetail'] as Map<String, dynamic>?) ?? {};
    final title = (detail['title'] as Map<String, dynamic>?) ?? {};
    return manga.copyWith(
      author: title['author'] as String?,
      description: detail['overview'] as String?,
    );
  }

  Future<List<Chapter>> getChapterList(Manga manga) async {
    final titleId = _extractTitleId(manga.url);
    final bytes =
        await _fetchBytes('$_apiUrl/api/title_detailV3?title_id=$titleId');
    final data = _parseResponse(bytes);
    final detail = (data['titleDetail'] as Map<String, dynamic>?) ?? {};
    final first = (detail['firstChapters'] as List?) ?? [];
    final last = (detail['lastChapters'] as List?) ?? [];
    final all = [...first, ...last];
    return all.asMap().entries.map((e) {
      final c = e.value as Map<String, dynamic>;
      final name = '${c['name'] ?? ''} ${c['subTitle'] ?? ''}'.trim();
      final ts = (c['startTimeStamp'] as int?) ?? 0;
      return Chapter(
        id: null,
        mangaId: manga.id ?? 0,
        url: '${c['chapterId']}',
        name: name.isEmpty ? 'Chapter ${e.key + 1}' : name,
        chapterNumber: (e.key + 1).toDouble(),
        scanlator: 'MANGA Plus',
        dateUpload: DateTime.fromMillisecondsSinceEpoch(ts * 1000),
      );
    }).toList();
  }

  Future<List<MangaPage>> getPageList(Chapter chapter) async {
    final bytes = await _fetchBytes(
        '$_apiUrl/api/manga_viewer?chapter_id=${chapter.url}'
        '&split=no&img_quality=super_high');
    final data = _parseResponse(bytes);
    final viewer = (data['mangaViewer'] as Map<String, dynamic>?) ?? {};
    final rawPages = (viewer['pages'] as List?) ?? [];
    int i = 0;
    final result = <MangaPage>[];
    for (final p in rawPages) {
      final page = p as Map<String, dynamic>;
      final imageUrl = page['imageUrl'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        result.add(MangaPage(index: i++, imageUrl: imageUrl));
      }
    }
    return result;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _extractTitleId(String url) => url.split('/').last;

  Manga _titleToManga(dynamic t) {
    final m = t as Map<String, dynamic>;
    final id = m['titleId'] as int? ?? 0;
    return Manga(
      id: null,
      sourceId: _sourceId,
      url: '$_baseUrl/titles/$id',
      title: m['name'] as String? ?? '',
      coverUrl: m['portraitImageUrl'] as String?,
      author: m['author'] as String?,
    );
  }

  Future<Uint8List> _fetchBytes(String url) async {
    final resp = await _dio.get<dynamic>(url);
    return resp.data as Uint8List;
  }

  /// Parses the binary protobuf MangaPlusResponse into a plain Dart map.
  Map<String, dynamic> _parseResponse(Uint8List bytes) {
    try {
      final reader = _ProtoReader(bytes);
      while (reader.hasMore) {
        final tag = reader.readTag();
        if (tag.field == 11 && tag.wireType == 2) {
          return _parseSuccess(_ProtoReader(reader.readBytes()));
        } else {
          reader.skipField(tag.wireType);
        }
      }
    } catch (_) {
      // Return empty on parse errors
    }
    return {};
  }

  Map<String, dynamic> _parseSuccess(_ProtoReader r) {
    while (r.hasMore) {
      final tag = r.readTag();
      switch (tag.field) {
        case 8: // TitleDetailView
          if (tag.wireType == 2) {
            return {'titleDetail': _parseTitleDetail(_ProtoReader(r.readBytes()))};
          }
          break;
        case 14: // MangaViewer
          if (tag.wireType == 2) {
            return {'mangaViewer': _parseMangaViewer(_ProtoReader(r.readBytes()))};
          }
          break;
        case 18: // AllTitlesViewV2
          if (tag.wireType == 2) {
            return {'allTitles': _parseAllTitlesV2(_ProtoReader(r.readBytes()))};
          }
          break;
        default:
          r.skipField(tag.wireType);
      }
    }
    return {};
  }

  List<Map<String, dynamic>> _parseAllTitlesV2(_ProtoReader r) {
    final titles = <Map<String, dynamic>>[];
    while (r.hasMore) {
      final tag = r.readTag();
      if (tag.field == 1 && tag.wireType == 2) {
        titles.addAll(_parseTitleGroup(_ProtoReader(r.readBytes())));
      } else {
        r.skipField(tag.wireType);
      }
    }
    return titles;
  }

  List<Map<String, dynamic>> _parseTitleGroup(_ProtoReader r) {
    final titles = <Map<String, dynamic>>[];
    while (r.hasMore) {
      final tag = r.readTag();
      if (tag.field == 2 && tag.wireType == 2) {
        titles.add(_parseTitle(_ProtoReader(r.readBytes())));
      } else {
        r.skipField(tag.wireType);
      }
    }
    return titles;
  }

  Map<String, dynamic> _parseTitle(_ProtoReader r) {
    final result = <String, dynamic>{};
    while (r.hasMore) {
      final tag = r.readTag();
      switch (tag.field) {
        case 1:
          result['titleId'] = r.readVarint();
          break;
        case 2:
          result['name'] = r.readString();
          break;
        case 3:
          result['author'] = r.readString();
          break;
        case 4:
          result['portraitImageUrl'] = r.readString();
          break;
        default:
          r.skipField(tag.wireType);
      }
    }
    return result;
  }

  Map<String, dynamic> _parseTitleDetail(_ProtoReader r) {
    final result = <String, dynamic>{};
    final first = <Map<String, dynamic>>[];
    final last = <Map<String, dynamic>>[];
    while (r.hasMore) {
      final tag = r.readTag();
      switch (tag.field) {
        case 1:
          result['title'] = _parseTitle(_ProtoReader(r.readBytes()));
          break;
        case 5:
          result['overview'] = r.readString();
          break;
        case 6:
          first.add(_parseChapter(_ProtoReader(r.readBytes())));
          break;
        case 7:
          last.add(_parseChapter(_ProtoReader(r.readBytes())));
          break;
        default:
          r.skipField(tag.wireType);
      }
    }
    result['firstChapters'] = first;
    result['lastChapters'] = last;
    return result;
  }

  Map<String, dynamic> _parseChapter(_ProtoReader r) {
    final result = <String, dynamic>{};
    while (r.hasMore) {
      final tag = r.readTag();
      switch (tag.field) {
        case 1:
          result['titleId'] = r.readVarint();
          break;
        case 2:
          result['chapterId'] = r.readVarint();
          break;
        case 3:
          result['name'] = r.readString();
          break;
        case 4:
          result['subTitle'] = r.readString();
          break;
        case 14:
          result['startTimeStamp'] = r.readVarint();
          break;
        default:
          r.skipField(tag.wireType);
      }
    }
    return result;
  }

  Map<String, dynamic> _parseMangaViewer(_ProtoReader r) {
    final pages = <Map<String, dynamic>>[];
    while (r.hasMore) {
      final tag = r.readTag();
      if (tag.field == 1 && tag.wireType == 2) {
        final page = _parseMangaViewerPage(_ProtoReader(r.readBytes()));
        if (page != null) pages.add(page);
      } else {
        r.skipField(tag.wireType);
      }
    }
    return {'pages': pages};
  }

  Map<String, dynamic>? _parseMangaViewerPage(_ProtoReader r) {
    while (r.hasMore) {
      final tag = r.readTag();
      if (tag.field == 1 && tag.wireType == 2) {
        return _parseMangaPageMedia(_ProtoReader(r.readBytes()));
      } else {
        r.skipField(tag.wireType);
      }
    }
    return null;
  }

  Map<String, dynamic> _parseMangaPageMedia(_ProtoReader r) {
    final result = <String, dynamic>{};
    while (r.hasMore) {
      final tag = r.readTag();
      if (tag.field == 1 && tag.wireType == 2) {
        result.addAll(_parseImage(_ProtoReader(r.readBytes())));
      } else {
        r.skipField(tag.wireType);
      }
    }
    return result;
  }

  Map<String, dynamic> _parseImage(_ProtoReader r) {
    final result = <String, dynamic>{};
    while (r.hasMore) {
      final tag = r.readTag();
      switch (tag.field) {
        case 1:
          result['imageUrl'] = r.readString();
          break;
        case 4:
          // EncryptionKey — field 1 = typeA hex string
          result['encryptionKey'] = _parseEncryptionKey(_ProtoReader(r.readBytes()));
          break;
        default:
          r.skipField(tag.wireType);
      }
    }
    return result;
  }

  String? _parseEncryptionKey(_ProtoReader r) {
    while (r.hasMore) {
      final tag = r.readTag();
      if (tag.field == 1 && tag.wireType == 2) return r.readString();
      r.skipField(tag.wireType);
    }
    return null;
  }
}

// ── Minimal protobuf binary reader ───────────────────────────────────────────

class _ProtoReader {
  final ByteData _data;
  int _pos = 0;

  _ProtoReader(Uint8List bytes)
      : _data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);

  bool get hasMore => _pos < _data.lengthInBytes;

  ({int field, int wireType}) readTag() {
    final tag = readVarint();
    return (field: tag >> 3, wireType: tag & 0x7);
  }

  int readVarint() {
    int result = 0;
    int shift = 0;
    while (_pos < _data.lengthInBytes) {
      final b = _data.getUint8(_pos++);
      result |= (b & 0x7F) << shift;
      if ((b & 0x80) == 0) break;
      shift += 7;
    }
    return result;
  }

  Uint8List readBytes() {
    final len = readVarint();
    final start = _pos;
    _pos += len;
    return Uint8List.view(_data.buffer, _data.offsetInBytes + start, len);
  }

  String readString() => utf8.decode(readBytes());

  void skipField(int wireType) {
    switch (wireType) {
      case 0:
        readVarint();
        break;
      case 1:
        _pos += 8;
        break;
      case 2:
        final len = readVarint();
        _pos += len;
        break;
      case 5:
        _pos += 4;
        break;
      default:
        throw StateError('Unknown protobuf wire type: $wireType');
    }
  }
}
