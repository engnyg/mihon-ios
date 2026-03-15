import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../data/sources/source_registry.dart';
import '../../domain/entities/manga.dart';
import '../../domain/entities/page.dart';
import '../../domain/repositories/chapter_repository.dart';
import '../../domain/repositories/manga_repository.dart';

typedef ReaderParams = ({int chapterId, int mangaId});

final readerPagesProvider =
    FutureProvider.family<List<MangaPage>, ReaderParams>((ref, p) async {
  final chapterRepo = GetIt.I<ChapterRepository>();
  final mangaRepo = GetIt.I<MangaRepository>();

  final chapter = await chapterRepo.getChapterById(p.chapterId);
  if (chapter == null) throw Exception('Chapter not found: ${p.chapterId}');

  final manga = await mangaRepo.getMangaById(p.mangaId);
  if (manga == null) throw Exception('Manga not found: ${p.mangaId}');

  final source = SourceRegistry.instance.getSource(manga.sourceId);
  if (source == null) throw Exception('Source not found: ${manga.sourceId}');

  return source.getPageList(chapter);
});

final readerMangaProvider =
    FutureProvider.family<Manga?, int>((ref, mangaId) async {
  return GetIt.I<MangaRepository>().getMangaById(mangaId);
});
