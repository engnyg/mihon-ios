import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sources/tachi_ext/tachi_extension_def.dart';

// ── Repo metadata ──────────────────────────────────────────────────────────────

class TachiExtRepo {
  const TachiExtRepo({
    required this.url,
    required this.name,
    this.isDefault = false,
  });

  final String url;
  final String name;

  /// Default repo cannot be removed.
  final bool isDefault;

  Map<String, dynamic> toJson() => {'url': url, 'name': name};

  factory TachiExtRepo.fromJson(Map<String, dynamic> j) =>
      TachiExtRepo(url: j['url'] as String, name: j['name'] as String);

  @override
  bool operator ==(Object other) => other is TachiExtRepo && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

/// Extensions fetched from one repo.
class TachiRepoExtensions {
  const TachiRepoExtensions({required this.repo, required this.extensions});
  final TachiExtRepo repo;
  final List<TachiExtDef> extensions;
}

// ── Repository ─────────────────────────────────────────────────────────────────

/// Manages Tachimanga-format JSON extension repos and installed extensions.
///
/// **Repo format**: a URL that returns a JSON array of [TachiExtDef] objects.
/// Example entry:
/// ```json
/// {
///   "id": "hentaifox", "name": "HentaiFox", "lang": "en",
///   "baseUrl": "https://hentaifox.com",
///   "popularMangaUrl": "/latest-updated/page/{page}/",
///   "mangaListSelector": "div.gallery > a",
///   "titleSelector": "img@alt",
///   "thumbnailSelector": "img@src",
///   "pageListSelector": "div.pages img@src"
/// }
/// ```
class TachiExtRepository {
  static const _installedKey = 'tachi_ext_defs';
  static const _reposKey = 'tachi_ext_repos';

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  // ── Repo management ────────────────────────────────────────────────────────

  Future<List<TachiExtRepo>> getRepos() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadRepos(prefs);
  }

  Future<void> addRepo(String url, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final repos = _loadRepos(prefs);
    if (repos.any((r) => r.url == url)) return;
    repos.add(TachiExtRepo(url: url, name: name));
    await prefs.setString(
        _reposKey, jsonEncode(repos.map((r) => r.toJson()).toList()));
  }

  Future<void> removeRepo(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final repos = _loadRepos(prefs)..removeWhere((r) => r.url == url);
    await prefs.setString(
        _reposKey, jsonEncode(repos.map((r) => r.toJson()).toList()));
  }

  List<TachiExtRepo> _loadRepos(SharedPreferences prefs) {
    final raw = prefs.getString(_reposKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(TachiExtRepo.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Browse from repos ──────────────────────────────────────────────────────

  /// Fetches all repos and returns extensions grouped by repo.
  Future<List<TachiRepoExtensions>> fetchGrouped() async {
    final prefs = await SharedPreferences.getInstance();
    final repos = _loadRepos(prefs);
    final installedIds = _loadInstalled(prefs).map((d) => d.id).toSet();

    final results = await Future.wait(
      repos.map((repo) => _fetchRepo(repo, installedIds)),
    );
    return results.where((r) => r.extensions.isNotEmpty).toList();
  }

  Future<TachiRepoExtensions> _fetchRepo(
      TachiExtRepo repo, Set<String> installedIds) async {
    try {
      final defs = await _fetchDefsFromUrl(repo.url);
      // Mark already-installed defs
      return TachiRepoExtensions(repo: repo, extensions: defs);
    } catch (_) {
      return TachiRepoExtensions(repo: repo, extensions: []);
    }
  }

  Future<List<TachiExtDef>> _fetchDefsFromUrl(String url) async {
    final resp = await _dio.get<dynamic>(url);
    final raw = resp.data;
    List<dynamic> list;
    if (raw is List) {
      list = raw;
    } else if (raw is String) {
      final decoded = jsonDecode(raw);
      list = decoded is List ? decoded : [decoded];
    } else {
      return [];
    }
    final defs = <TachiExtDef>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      try {
        final def = TachiExtDef.fromJson(item);
        if (def.id.isNotEmpty && def.baseUrl.isNotEmpty) {
          // Native Tachimanga JSON format
          defs.add(def);
        } else if (item.containsKey('pkg')) {
          // Keiyoushi format: extract from sources[]
          _parseKeiyoushiItem(item, defs);
        }
      } catch (_) {
        if (item.containsKey('pkg')) {
          try {
            _parseKeiyoushiItem(item, defs);
          } catch (_) {}
        }
      }
    }
    return defs;
  }

  void _parseKeiyoushiItem(
      Map<String, dynamic> item, List<TachiExtDef> out) {
    final sources = item['sources'];
    if (sources is! List || sources.isEmpty) return;
    final version = item['version']?.toString() ?? '1.0';
    final nsfw =
        item['nsfw'] is int ? (item['nsfw'] as int) != 0 : false;
    for (final src in sources) {
      if (src is! Map<String, dynamic>) continue;
      final srcId = src['id']?.toString() ?? '';
      final srcName =
          src['name'] as String? ?? item['name'] as String? ?? '';
      final srcLang =
          src['lang'] as String? ?? item['lang'] as String? ?? 'en';
      final srcBase = src['baseUrl'] as String? ?? '';
      if (srcId.isEmpty || srcBase.isEmpty) continue;
      out.add(TachiExtDef(
        id: srcId,
        name: srcName,
        lang: srcLang,
        baseUrl: srcBase,
        version: version,
        nsfw: nsfw,
      ));
    }
  }

  /// Validates a repo URL. Returns the number of extensions found.
  /// Throws on network error or non-array response.
  Future<int> validateRepoUrl(String url) async {
    final defs = await _fetchDefsFromUrl(url);
    return defs.length;
  }

  // ── Install / Uninstall ────────────────────────────────────────────────────

  /// Install from a [TachiExtDef] object (e.g. tapped in Browse tab).
  Future<void> install(TachiExtDef def) async {
    final prefs = await SharedPreferences.getInstance();
    final defs = _loadInstalled(prefs)..removeWhere((d) => d.id == def.id);
    defs.add(def);
    await _persist(prefs, defs);
  }

  /// Download and install a single JSON extension from [url].
  Future<TachiExtDef> installFromUrl(String url) async {
    final def = await _fetchOne(url);
    if (def.id.isEmpty) throw Exception('Extension JSON is missing "id" field');
    if (def.name.isEmpty) {
      throw Exception('Extension JSON is missing "name" field');
    }
    if (def.baseUrl.isEmpty) {
      throw Exception('Extension JSON is missing "baseUrl" field');
    }
    await install(def);
    return def;
  }

  Future<void> uninstall(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final defs = _loadInstalled(prefs)..removeWhere((d) => d.id == id);
    await _persist(prefs, defs);
  }

  Future<List<TachiExtDef>> getInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadInstalled(prefs);
  }

  /// Validates a single extension URL without installing it.
  Future<TachiExtDef> validateUrl(String url) => _fetchOne(url);

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<TachiExtDef> _fetchOne(String url) async {
    final resp = await _dio.get<dynamic>(url);
    final raw = resp.data;
    Map<String, dynamic> map;
    if (raw is Map<String, dynamic>) {
      map = raw;
    } else if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Expected a JSON object');
      }
      map = decoded;
    } else {
      throw Exception('Unexpected response type: ${raw.runtimeType}');
    }
    return TachiExtDef.fromJson(map);
  }

  List<TachiExtDef> _loadInstalled(SharedPreferences prefs) {
    final raw = prefs.getString(_installedKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(TachiExtDef.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist(
      SharedPreferences prefs, List<TachiExtDef> defs) async {
    await prefs.setString(
        _installedKey, jsonEncode(defs.map((d) => d.toJson()).toList()));
  }
}
