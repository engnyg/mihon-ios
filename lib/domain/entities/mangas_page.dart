import 'manga.dart';

class MangasPage {
  const MangasPage({
    required this.mangas,
    required this.hasNextPage,
  });

  final List<Manga> mangas;
  final bool hasNextPage;
}
