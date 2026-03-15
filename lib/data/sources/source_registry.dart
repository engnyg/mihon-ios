import 'base/manga_source.dart';
import 'built_in/copymanga/copymanga_source.dart';
import 'built_in/jmcomic/jmcomic_source.dart';
import 'built_in/mangadex/mangadex_source.dart';
import 'built_in/mangaplus/mangaplus_source.dart';
import 'built_in/nhentai/nhentai_source.dart';
import 'built_in/webtoons/webtoons_source.dart';
import 'built_in/webtoons/webtoons_zh_source.dart';

/// Central registry of all available manga sources.
/// Add new sources here.
class SourceRegistry {
  SourceRegistry._() {
    _register(MangaDexSource());
    _register(MangaPlusSource());
    _register(WebtoonsSource());
    _register(WebtoonsZhSource());
    _register(NHentaiSource());
    _register(CopyMangaSource());
    _register(JMComicSource());
  }

  static final SourceRegistry instance = SourceRegistry._();

  final _sources = <String, MangaSource>{};

  void _register(MangaSource source) => _sources[source.id] = source;

  /// Dynamically register a source (e.g. an installed extension stub).
  void registerSource(MangaSource source) => _sources[source.id] = source;

  /// Remove a dynamically registered source.
  void unregisterSource(String id) => _sources.remove(id);

  bool hasSource(String id) => _sources.containsKey(id);

  MangaSource? getSource(String id) => _sources[id];

  List<MangaSource> get allSources => _sources.values.toList();

  List<MangaSource> sourcesByLanguage(String lang) =>
      allSources.where((s) => s.lang == lang).toList();
}
