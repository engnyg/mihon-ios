import 'package:drift/drift.dart';

class MangaTable extends Table {
  @override
  String get tableName => 'manga';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get sourceId => text()();
  TextColumn get url => text()();
  TextColumn get title => text()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get author => text().nullable()();
  TextColumn get artist => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get genre => text().nullable()(); // JSON array
  IntColumn get status => integer().withDefault(const Constant(0))();
  BoolColumn get inLibrary =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastUpdated => dateTime().nullable()();
  DateTimeColumn get lastRead => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {sourceId, url},
      ];
}
