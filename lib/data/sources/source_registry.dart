import 'base/manga_source.dart';
import 'built_in/mangadex/mangadex_source.dart';
import 'built_in/mangaplus/mangaplus_source.dart';
import 'built_in/webtoons/webtoons_source.dart';

/// Central registry of all available manga sources.
/// Add new sources here.
class SourceRegistry {
  SourceRegistry._() {
    _register(MangaDexSource());
    _register(MangaPlusSource());
    _register(WebtoonsSource());
  }

  static final SourceRegistry instance = SourceRegistry._();

  final _sources = <String, MangaSource>{};

  void _register(MangaSource source) => _sources[source.id] = source;

  MangaSource? getSource(String id) => _sources[id];

  List<MangaSource> get allSources => _sources.values.toList();

  List<MangaSource> sourcesByLanguage(String lang) =>
      allSources.where((s) => s.lang == lang).toList();
}
