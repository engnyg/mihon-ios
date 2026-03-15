import '../entities/chapter.dart';

abstract interface class ChapterRepository {
  Stream<List<Chapter>> watchChaptersByMangaId(int mangaId);
  Future<List<Chapter>> getChaptersByMangaId(int mangaId);
  Future<Chapter?> getChapterById(int id);
  Future<void> insertChapters(List<Chapter> chapters);
  Future<void> updateChapter(Chapter chapter);
  Future<void> markRead(int chapterId, {required bool read});
  Future<void> updateReadingProgress(int chapterId, int lastReadPage);
}
