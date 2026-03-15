import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities/manga.dart';
import '../../domain/repositories/manga_repository.dart';

final librarySearchQueryProvider = StateProvider<String>((ref) => '');

final libraryProvider = StreamProvider<List<Manga>>((ref) {
  final repo = GetIt.I<MangaRepository>();
  final query = ref.watch(librarySearchQueryProvider).toLowerCase();

  return repo.watchLibrary().map((mangas) {
    if (query.isEmpty) return mangas;
    return mangas
        .where((m) => m.title.toLowerCase().contains(query))
        .toList();
  });
});
