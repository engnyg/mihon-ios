import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../data/sources/source_registry.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/manga.dart';
import '../../domain/repositories/chapter_repository.dart';
import '../../domain/repositories/manga_repository.dart';

typedef MangaDetailParams = ({String mangaUrl, String sourceId, int? mangaId});

final mangaDetailProvider =
    FutureProvider.family<Manga, MangaDetailParams>((ref, p) async {
  final source = SourceRegistry.instance.getSource(p.sourceId);
  if (source == null) throw Exception('Source not found: ${p.sourceId}');

  // Build a minimal Manga to pass to the source
  final stub = Manga(
    id: p.mangaId,
    sourceId: p.sourceId,
    url: p.mangaUrl,
    title: '',
  );
  return source.getMangaDetails(stub);
});

final chapterListProvider =
    FutureProvider.family<List<Chapter>, MangaDetailParams>((ref, p) async {
  final source = SourceRegistry.instance.getSource(p.sourceId);
  if (source == null) throw Exception('Source not found: ${p.sourceId}');

  final stub = Manga(
    id: p.mangaId,
    sourceId: p.sourceId,
    url: p.mangaUrl,
    title: '',
  );
  return source.getChapterList(stub);
});

final mangaInLibraryProvider =
    FutureProvider.family<bool, int?>((ref, mangaId) async {
  if (mangaId == null) return false;
  final repo = GetIt.I<MangaRepository>();
  final manga = await repo.getMangaById(mangaId);
  return manga?.inLibrary ?? false;
});

// Notifier to track in-library state with optimistic updates
class LibraryNotifier extends StateNotifier<AsyncValue<bool>> {
  LibraryNotifier(this._mangaId) : super(const AsyncValue.loading()) {
    _init();
  }

  final int? _mangaId;
  final _repo = GetIt.I<MangaRepository>();

  Future<void> _init() async {
    if (_mangaId == null) {
      state = const AsyncValue.data(false);
      return;
    }
    final manga = await _repo.getMangaById(_mangaId!);
    state = AsyncValue.data(manga?.inLibrary ?? false);
  }

  Future<void> toggle(Manga manga) async {
    final current = state.value ?? false;
    state = AsyncValue.data(!current);

    try {
      if (current) {
        if (_mangaId != null) await _repo.removeFromLibrary(_mangaId!);
      } else {
        if (_mangaId != null) {
          await _repo.addToLibrary(_mangaId!);
        } else {
          // Manga not in DB yet — insert it first
          final id = await _repo.insertManga(manga.copyWith(inLibrary: true));
          // Reload
          final updated = await _repo.getMangaById(id);
          state = AsyncValue.data(updated?.inLibrary ?? true);
        }
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final libraryNotifierProvider = StateNotifierProvider.family<LibraryNotifier,
    AsyncValue<bool>, int?>((ref, mangaId) {
  return LibraryNotifier(mangaId);
});

// Provider for chapters stored in DB
final dbChaptersProvider =
    StreamProvider.family<List<Chapter>, int>((ref, mangaId) {
  return GetIt.I<ChapterRepository>().watchChaptersByMangaId(mangaId);
});
