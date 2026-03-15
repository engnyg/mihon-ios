import 'package:drift/drift.dart';
import 'manga_table.dart';

class ChapterTable extends Table {
  @override
  String get tableName => 'chapter';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get mangaId =>
      integer().references(MangaTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get url => text()();
  TextColumn get name => text()();
  RealColumn get chapterNumber => real().nullable()();
  RealColumn get volume => real().nullable()();
  TextColumn get scanlator => text().nullable()();
  BoolColumn get read => boolean().withDefault(const Constant(false))();
  BoolColumn get bookmarked =>
      boolean().withDefault(const Constant(false))();
  IntColumn get lastReadPage => integer().withDefault(const Constant(0))();
  IntColumn get totalPages => integer().withDefault(const Constant(0))();
  DateTimeColumn get dateUpload => dateTime().nullable()();
  DateTimeColumn get dateFetch => dateTime().nullable()();
  BoolColumn get downloaded =>
      boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {mangaId, url},
      ];
}
