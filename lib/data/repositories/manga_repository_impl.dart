import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../data/database/app_database.dart';
import '../../data/database/daos/manga_dao.dart';
import '../../domain/entities/manga.dart';
import '../../domain/repositories/manga_repository.dart';

class MangaRepositoryImpl implements MangaRepository {
  const MangaRepositoryImpl(this._dao);
  final MangaDao _dao;

  @override
  Stream<List<Manga>> watchLibrary() =>
      _dao.watchLibrary().map((rows) => rows.map(toManga).toList());

  @override
  Future<List<Manga>> getLibrary() async {
    final rows = await _dao.getLibrary();
    return rows.map(toManga).toList();
  }

  @override
  Future<Manga?> getMangaById(int id) async {
    final row = await _dao.getMangaById(id);
    return row != null ? toManga(row) : null;
  }

  @override
  Future<Manga?> getMangaByUrl(String sourceId, String url) async {
    final row = await _dao.getMangaBySourceUrl(sourceId, url);
    return row != null ? toManga(row) : null;
  }

  @override
  Future<int> insertManga(Manga manga) =>
      _dao.insertManga(_toCompanion(manga));

  @override
  Future<void> updateManga(Manga manga) =>
      _dao.updateManga(_toUpdateCompanion(manga));

  @override
  Future<void> deleteManga(int id) => _dao.deleteManga(id);

  @override
  Future<void> addToLibrary(int mangaId) =>
      _dao.setInLibrary(mangaId, inLibrary: true);

  @override
  Future<void> removeFromLibrary(int mangaId) =>
      _dao.setInLibrary(mangaId, inLibrary: false);

  // ── Public conversion helpers (used by HistoryRepositoryImpl) ────────────

  static Manga toManga(MangaTableData row) {
    List<String> genres = [];
    if (row.genre != null) {
      try {
        genres = (jsonDecode(row.genre!) as List).cast<String>();
      } catch (_) {}
    }

    return Manga(
      id: row.id,
      sourceId: row.sourceId,
      url: row.url,
      title: row.title,
      coverUrl: row.coverUrl,
      author: row.author,
      artist: row.artist,
      description: row.description,
      genres: genres,
      status: _statusFromInt(row.status),
      inLibrary: row.inLibrary,
      lastUpdated: row.lastUpdated,
      lastRead: row.lastRead,
    );
  }

  static MangaTableCompanion _toCompanion(Manga m) {
    return MangaTableCompanion.insert(
      sourceId: m.sourceId,
      url: m.url,
      title: m.title,
      coverUrl: Value(m.coverUrl),
      author: Value(m.author),
      artist: Value(m.artist),
      description: Value(m.description),
      genre: Value(jsonEncode(m.genres)),
      status: Value(m.status.index),
      inLibrary: Value(m.inLibrary),
      lastUpdated: Value(m.lastUpdated),
      lastRead: Value(m.lastRead),
    );
  }

  static MangaTableCompanion _toUpdateCompanion(Manga m) {
    return MangaTableCompanion(
      id: Value(m.id!),
      sourceId: Value(m.sourceId),
      url: Value(m.url),
      title: Value(m.title),
      coverUrl: Value(m.coverUrl),
      author: Value(m.author),
      artist: Value(m.artist),
      description: Value(m.description),
      genre: Value(jsonEncode(m.genres)),
      status: Value(m.status.index),
      inLibrary: Value(m.inLibrary),
      lastUpdated: Value(m.lastUpdated),
      lastRead: Value(m.lastRead),
    );
  }

  static MangaStatus _statusFromInt(int v) =>
      v >= 0 && v < MangaStatus.values.length
          ? MangaStatus.values[v]
          : MangaStatus.unknown;
}
