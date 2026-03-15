import 'package:drift/drift.dart';

class CategoryTable extends Table {
  @override
  String get tableName => 'category';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get order => integer().withDefault(const Constant(0))();
  BoolColumn get isDefault =>
      boolean().withDefault(const Constant(false))();
}

class MangaCategoryTable extends Table {
  @override
  String get tableName => 'manga_category';

  IntColumn get mangaId => integer()();
  IntColumn get categoryId => integer()();

  @override
  Set<Column> get primaryKey => {mangaId, categoryId};
}
