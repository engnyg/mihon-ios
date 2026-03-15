import '../../data/database/daos/history_dao.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/manga.dart';
import '../../domain/entities/reading_history.dart';
import '../../domain/repositories/history_repository.dart';
import 'manga_repository_impl.dart';
import 'chapter_repository_impl.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  const HistoryRepositoryImpl(this._dao);
  final HistoryDao _dao;

  @override
  Stream<List<ReadingHistory>> watchHistory() =>
      _dao.watchHistory().map((rows) => rows.map(_toReadingHistory).toList());

  @override
  Future<void> recordHistory(int chapterId) => _dao.recordHistory(chapterId);

  @override
  Future<void> deleteHistoryEntry(int historyId) =>
      _dao.deleteEntry(historyId);

  @override
  Future<void> clearAllHistory() => _dao.clearAll();

  static ReadingHistory _toReadingHistory(HistoryWithDetails details) {
    final manga = MangaRepositoryImpl.toManga(details.manga);
    final chapter = ChapterRepositoryImpl.toChapter(details.chapter);
    return ReadingHistory(
      id: details.history.id,
      chapter: chapter,
      manga: manga,
      lastRead: details.history.lastRead,
    );
  }
}
