import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/category_table.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [CategoryTable, MangaCategoryTable])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  Stream<List<CategoryTableData>> watchCategories() =>
      (select(categoryTable)
            ..orderBy([(t) => OrderingTerm.asc(t.order)]))
          .watch();

  Future<List<CategoryTableData>> getCategories() =>
      (select(categoryTable)
            ..orderBy([(t) => OrderingTerm.asc(t.order)]))
          .get();

  Future<int> insertCategory(CategoryTableCompanion category) =>
      into(categoryTable).insert(category);

  Future<void> updateCategory(CategoryTableCompanion category) =>
      (update(categoryTable)
            ..where((t) => t.id.equals(category.id.value)))
          .write(category);

  Future<void> deleteCategory(int id) =>
      (delete(categoryTable)..where((t) => t.id.equals(id))).go();

  Future<List<int>> getCategoryIdsForManga(int mangaId) async {
    final query = select(mangaCategoryTable)
      ..where((t) => t.mangaId.equals(mangaId));
    final rows = await query.get();
    return rows.map((r) => r.categoryId).toList();
  }

  Future<void> setMangaCategories(
      int mangaId, List<int> categoryIds) async {
    await transaction(() async {
      await (delete(mangaCategoryTable)
            ..where((t) => t.mangaId.equals(mangaId)))
          .go();
      for (final catId in categoryIds) {
        await into(mangaCategoryTable).insert(
          MangaCategoryTableCompanion.insert(
              mangaId: mangaId, categoryId: catId),
        );
      }
    });
  }
}
