import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/history_table.dart';
import '../tables/chapter_table.dart';
import '../tables/manga_table.dart';

part 'history_dao.g.dart';

class HistoryWithDetails {
  const HistoryWithDetails({
    required this.history,
    required this.chapter,
    required this.manga,
  });
  final HistoryTableData history;
  final ChapterTableData chapter;
  final MangaTableData manga;
}

@DriftAccessor(tables: [HistoryTable, ChapterTable, MangaTable])
class HistoryDao extends DatabaseAccessor<AppDatabase> with _$HistoryDaoMixin {
  HistoryDao(super.db);

  Stream<List<HistoryWithDetails>> watchHistory() {
    final query = select(historyTable).join([
      innerJoin(chapterTable,
          chapterTable.id.equalsExp(historyTable.chapterId)),
      innerJoin(
          mangaTable, mangaTable.id.equalsExp(chapterTable.mangaId)),
    ])
      ..orderBy([OrderingTerm.desc(historyTable.lastRead)]);

    return query.watch().map((rows) => rows
        .map((row) => HistoryWithDetails(
              history: row.readTable(historyTable),
              chapter: row.readTable(chapterTable),
              manga: row.readTable(mangaTable),
            ))
        .toList());
  }

  Future<void> recordHistory(int chapterId) async {
    await into(historyTable).insertOnConflictUpdate(
      HistoryTableCompanion.insert(
        chapterId: chapterId,
        lastRead: DateTime.now(),
      ),
    );
  }

  Future<void> deleteEntry(int id) =>
      (delete(historyTable)..where((t) => t.id.equals(id))).go();

  Future<void> clearAll() => delete(historyTable).go();
}
