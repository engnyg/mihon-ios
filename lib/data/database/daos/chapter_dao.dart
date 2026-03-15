import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/chapter_table.dart';

part 'chapter_dao.g.dart';

@DriftAccessor(tables: [ChapterTable])
class ChapterDao extends DatabaseAccessor<AppDatabase>
    with _$ChapterDaoMixin {
  ChapterDao(super.db);

  Stream<List<ChapterTableData>> watchByMangaId(int mangaId) =>
      (select(chapterTable)
            ..where((t) => t.mangaId.equals(mangaId))
            ..orderBy([(t) => OrderingTerm.desc(t.chapterNumber)]))
          .watch();

  Future<List<ChapterTableData>> getByMangaId(int mangaId) =>
      (select(chapterTable)
            ..where((t) => t.mangaId.equals(mangaId))
            ..orderBy([(t) => OrderingTerm.desc(t.chapterNumber)]))
          .get();

  Future<ChapterTableData?> getById(int id) =>
      (select(chapterTable)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<void> insertChapters(List<ChapterTableCompanion> chapters) =>
      batch((b) => b.insertAllOnConflictUpdate(chapterTable, chapters));

  Future<void> updateChapter(ChapterTableCompanion chapter) =>
      (update(chapterTable)
            ..where((t) => t.id.equals(chapter.id.value)))
          .write(chapter);

  Future<void> markRead(int id, {required bool read}) =>
      (update(chapterTable)..where((t) => t.id.equals(id)))
          .write(ChapterTableCompanion(read: Value(read)));

  Future<void> updateReadingProgress(int id, int lastReadPage) =>
      (update(chapterTable)..where((t) => t.id.equals(id))).write(
        ChapterTableCompanion(lastReadPage: Value(lastReadPage)),
      );

  Future<int> countUnread(int mangaId) async {
    final count = countAll(filter: chapterTable.read.equals(false));
    final query = selectOnly(chapterTable)
      ..addColumns([count])
      ..where(chapterTable.mangaId.equals(mangaId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }
}
