import 'base/manga_source.dart';

/// Central registry of all available manga sources.
/// Sources are registered dynamically (e.g. installed JSON extensions).
class SourceRegistry {
  SourceRegistry._();

  static final SourceRegistry instance = SourceRegistry._();

  final _sources = <String, MangaSource>{};

  /// Dynamically register a source (e.g. an installed JSON extension).
  void registerSource(MangaSource source) => _sources[source.id] = source;

  /// Remove a dynamically registered source.
  void unregisterSource(String id) => _sources.remove(id);

  bool hasSource(String id) => _sources.containsKey(id);

  MangaSource? getSource(String id) => _sources[id];

  List<MangaSource> get allSources => _sources.values.toList();

  List<MangaSource> sourcesByLanguage(String lang) =>
      allSources.where((s) => s.lang == lang).toList();
}
