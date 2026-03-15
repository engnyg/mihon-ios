import '../entities/category.dart';

abstract interface class CategoryRepository {
  Stream<List<Category>> watchCategories();
  Future<List<Category>> getCategories();
  Future<int> insertCategory(Category category);
  Future<void> updateCategory(Category category);
  Future<void> deleteCategory(int id);
  Future<void> setMangaCategories(int mangaId, List<int> categoryIds);
  Future<List<int>> getCategoryIdsForManga(int mangaId);
}
