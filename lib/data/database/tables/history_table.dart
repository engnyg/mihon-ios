import 'package:drift/drift.dart';
import 'chapter_table.dart';

class HistoryTable extends Table {
  @override
  String get tableName => 'history';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get chapterId => integer()
      .references(ChapterTable, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get lastRead => dateTime()();
}
