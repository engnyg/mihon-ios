import '../entities/manga.dart';

abstract interface class MangaRepository {
  Stream<List<Manga>> watchLibrary();
  Future<List<Manga>> getLibrary();
  Future<Manga?> getMangaById(int id);
  Future<Manga?> getMangaByUrl(String sourceId, String url);
  Future<int> insertManga(Manga manga);
  Future<void> updateManga(Manga manga);
  Future<void> deleteManga(int id);
  Future<void> addToLibrary(int mangaId);
  Future<void> removeFromLibrary(int mangaId);
}
