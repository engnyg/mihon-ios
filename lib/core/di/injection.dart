import 'package:get_it/get_it.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/chapter_repository_impl.dart';
import '../../data/repositories/history_repository_impl.dart';
import '../../data/repositories/manga_repository_impl.dart';
import '../../domain/repositories/chapter_repository.dart';
import '../../domain/repositories/history_repository.dart';
import '../../domain/repositories/manga_repository.dart';

Future<void> configureDependencies() async {
  final getIt = GetIt.instance;

  // Database
  final db = AppDatabase();
  getIt.registerSingleton<AppDatabase>(db);

  // Repositories
  getIt.registerSingleton<MangaRepository>(
    MangaRepositoryImpl(db.mangaDao),
  );
  getIt.registerSingleton<ChapterRepository>(
    ChapterRepositoryImpl(db.chapterDao),
  );
  getIt.registerSingleton<HistoryRepository>(
    HistoryRepositoryImpl(db.historyDao),
  );
}
