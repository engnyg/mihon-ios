import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/manga_dao.dart';
import 'daos/chapter_dao.dart';
import 'daos/history_dao.dart';
import 'daos/category_dao.dart';
import 'tables/manga_table.dart';
import 'tables/chapter_table.dart';
import 'tables/category_table.dart';
import 'tables/history_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    MangaTable,
    ChapterTable,
    CategoryTable,
    MangaCategoryTable,
    HistoryTable,
  ],
  daos: [
    MangaDao,
    ChapterDao,
    HistoryDao,
    CategoryDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Future migration steps go here
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'mihon.db'));
    return NativeDatabase.createInBackground(file);
  });
}
