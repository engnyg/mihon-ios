import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/manga_table.dart';

part 'manga_dao.g.dart';

@DriftAccessor(tables: [MangaTable])
class MangaDao extends DatabaseAccessor<AppDatabase> with _$MangaDaoMixin {
  MangaDao(super.db);

  // Watch full library (in_library = true)
  Stream<List<MangaTableData>> watchLibrary() =>
      (select(mangaTable)..where((t) => t.inLibrary.equals(true))).watch();

  Future<List<MangaTableData>> getLibrary() =>
      (select(mangaTable)..where((t) => t.inLibrary.equals(true))).get();

  Future<MangaTableData?> getMangaById(int id) =>
      (select(mangaTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<MangaTableData?> getMangaBySourceUrl(
          String sourceId, String url) =>
      (select(mangaTable)
            ..where((t) =>
                t.sourceId.equals(sourceId) & t.url.equals(url)))
          .getSingleOrNull();

  Future<int> insertManga(MangaTableCompanion manga) =>
      into(mangaTable).insertOnConflictUpdate(manga);

  Future<void> updateManga(MangaTableCompanion manga) =>
      (update(mangaTable)..where((t) => t.id.equals(manga.id.value)))
          .write(manga);

  Future<void> deleteManga(int id) =>
      (delete(mangaTable)..where((t) => t.id.equals(id))).go();

  Future<void> setInLibrary(int id, {required bool inLibrary}) =>
      (update(mangaTable)..where((t) => t.id.equals(id)))
          .write(MangaTableCompanion(inLibrary: Value(inLibrary)));

  Future<void> updateLastRead(int id) =>
      (update(mangaTable)..where((t) => t.id.equals(id))).write(
        MangaTableCompanion(lastRead: Value(DateTime.now())),
      );
}
