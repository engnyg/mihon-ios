import 'package:drift/drift.dart' show Value;

import '../../data/database/app_database.dart';
import '../../data/database/daos/chapter_dao.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/repositories/chapter_repository.dart';

class ChapterRepositoryImpl implements ChapterRepository {
  const ChapterRepositoryImpl(this._dao);
  final ChapterDao _dao;

  @override
  Stream<List<Chapter>> watchChaptersByMangaId(int mangaId) =>
      _dao.watchByMangaId(mangaId).map((rows) => rows.map(toChapter).toList());

  @override
  Future<List<Chapter>> getChaptersByMangaId(int mangaId) async {
    final rows = await _dao.getByMangaId(mangaId);
    return rows.map(toChapter).toList();
  }

  @override
  Future<Chapter?> getChapterById(int id) async {
    final row = await _dao.getById(id);
    return row != null ? toChapter(row) : null;
  }

  @override
  Future<void> insertChapters(List<Chapter> chapters) =>
      _dao.insertChapters(chapters.map(_toCompanion).toList());

  @override
  Future<void> updateChapter(Chapter chapter) =>
      _dao.updateChapter(_toUpdateCompanion(chapter));

  @override
  Future<void> markRead(int chapterId, {required bool read}) =>
      _dao.markRead(chapterId, read: read);

  @override
  Future<void> updateReadingProgress(int chapterId, int lastReadPage) =>
      _dao.updateReadingProgress(chapterId, lastReadPage);

  // ── Conversion helpers ────────────────────────────────────────────────────

  static Chapter toChapter(ChapterTableData row) => Chapter(
        id: row.id,
        mangaId: row.mangaId,
        url: row.url,
        name: row.name,
        chapterNumber: row.chapterNumber,
        volume: row.volume,
        scanlator: row.scanlator,
        read: row.read,
        bookmarked: row.bookmarked,
        lastReadPage: row.lastReadPage,
        totalPages: row.totalPages,
        dateUpload: row.dateUpload,
        dateFetch: row.dateFetch,
        downloaded: row.downloaded,
      );

  static ChapterTableCompanion _toCompanion(Chapter c) =>
      ChapterTableCompanion.insert(
        mangaId: c.mangaId,
        url: c.url,
        name: c.name,
        chapterNumber: Value(c.chapterNumber),
        volume: Value(c.volume),
        scanlator: Value(c.scanlator),
        read: Value(c.read),
        bookmarked: Value(c.bookmarked),
        lastReadPage: Value(c.lastReadPage),
        totalPages: Value(c.totalPages),
        dateUpload: Value(c.dateUpload),
        dateFetch: Value(c.dateFetch),
        downloaded: Value(c.downloaded),
      );

  static ChapterTableCompanion _toUpdateCompanion(Chapter c) =>
      ChapterTableCompanion(
        id: Value(c.id!),
        mangaId: Value(c.mangaId),
        url: Value(c.url),
        name: Value(c.name),
        chapterNumber: Value(c.chapterNumber),
        volume: Value(c.volume),
        scanlator: Value(c.scanlator),
        read: Value(c.read),
        bookmarked: Value(c.bookmarked),
        lastReadPage: Value(c.lastReadPage),
        totalPages: Value(c.totalPages),
        dateUpload: Value(c.dateUpload),
        dateFetch: Value(c.dateFetch),
        downloaded: Value(c.downloaded),
      );
}
