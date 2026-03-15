import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'extension.dart';

/// Metadata for a single extension repository.
class ExtensionRepo {
  const ExtensionRepo({
    required this.url,
    required this.name,
    this.isDefault = false,
  });

  final String url;
  final String name;

  /// Default keiyoushi repo cannot be removed.
  final bool isDefault;

  Map<String, dynamic> toJson() => {'url': url, 'name': name};

  factory ExtensionRepo.fromJson(Map<String, dynamic> j) =>
      ExtensionRepo(url: j['url'] as String, name: j['name'] as String);

  @override
  bool operator ==(Object other) =>
      other is ExtensionRepo && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

/// Extensions grouped by source repo.
class RepoExtensions {
  const RepoExtensions({required this.repo, required this.extensions});
  final ExtensionRepo repo;
  final List<Extension> extensions;
}

/// Fetches extension catalogues (default + user-added repos) and tracks
/// which extensions are installed locally.
class ExtensionRepository {
  static const _defaultUrl =
      'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json';
  static const _installedKey = 'installed_extensions';
  static const _installedDataKey = 'installed_extensions_data';
  static const _customReposKey = 'custom_extension_repos';

  static final defaultRepo = ExtensionRepo(
    url: _defaultUrl,
    name: 'Keiyoushi',
    isDefault: true,
  );

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  /// Packages with native Dart implementations in SourceRegistry.
  static const nativePackages = {
    'eu.kanade.tachiyomi.extension.all.mangadex',
    'eu.kanade.tachiyomi.extension.en.mangaplus',
    'eu.kanade.tachiyomi.extension.en.webtoons',
    'eu.kanade.tachiyomi.extension.all.nhentai',
  };

  bool isNativelySupported(String pkg) => nativePackages.contains(pkg);

  // ── Repos ────────────────────────────────────────────────────────────────────

  Future<List<ExtensionRepo>> getRepos() async {
    final prefs = await SharedPreferences.getInstance();
    return [defaultRepo, ..._loadCustomRepos(prefs)];
  }

  Future<void> addCustomRepo(String url, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final repos = _loadCustomRepos(prefs);
    if (repos.any((r) => r.url == url)) return;
    repos.add(ExtensionRepo(url: url, name: name));
    await prefs.setString(
        _customReposKey, jsonEncode(repos.map((r) => r.toJson()).toList()));
  }

  Future<void> removeCustomRepo(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final repos = _loadCustomRepos(prefs)..removeWhere((r) => r.url == url);
    await prefs.setString(
        _customReposKey, jsonEncode(repos.map((r) => r.toJson()).toList()));
  }

  List<ExtensionRepo> _loadCustomRepos(SharedPreferences prefs) {
    final raw = prefs.getString(_customReposKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => ExtensionRepo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Index ────────────────────────────────────────────────────────────────────

  /// Fetches all repos and returns extensions grouped by repo.
  /// Each repo's extensions are independent — no de-duplication across repos,
  /// so custom repos always show their full content.
  Future<List<RepoExtensions>> fetchGrouped() async {
    final prefs = await SharedPreferences.getInstance();
    final installed = _loadInstalled(prefs);
    final repos = [defaultRepo, ..._loadCustomRepos(prefs)];

    final results = await Future.wait(
      repos.map((repo) => _fetchRepo(repo, installed)),
    );

    // Only include repos that returned at least one extension.
    return results.where((r) => r.extensions.isNotEmpty).toList();
  }

  Future<RepoExtensions> _fetchRepo(
      ExtensionRepo repo, Set<String> installed) async {
    try {
      final response = await _dio.get<dynamic>(repo.url);
      final raw = response.data;

      // GitHub raw serves text/plain; Dio may return String instead of List.
      List<dynamic> data;
      if (raw is List) {
        data = raw;
      } else if (raw is String) {
        data = jsonDecode(raw) as List<dynamic>;
      } else {
        return RepoExtensions(repo: repo, extensions: []);
      }

      final exts = <Extension>[];
      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;
        try {
          final ext = Extension.fromJson(item);
          exts.add(ext.copyWith(installed: installed.contains(ext.pkg)));
        } catch (_) {
          // Skip malformed entries, continue with the rest
        }
      }
      return RepoExtensions(repo: repo, extensions: exts);
    } catch (_) {
      return RepoExtensions(repo: repo, extensions: []);
    }
  }

  /// Validates a repo URL by fetching it. Returns the number of extensions
  /// found, or throws if the URL is invalid / returns non-array JSON.
  Future<int> validateRepoUrl(String url) async {
    final response = await _dio.get<dynamic>(url);
    final raw = response.data;
    if (raw == null) throw Exception('Empty response');
    final List<dynamic> data =
        raw is List ? raw : jsonDecode(raw as String) as List<dynamic>;
    return data.length;
  }

  // ── Install / Uninstall ───────────────────────────────────────────────────────

  /// Install by pkg only (lightweight, no source info).
  Future<void> install(String pkg) async {
    final prefs = await SharedPreferences.getInstance();
    final installed = _loadInstalled(prefs)..add(pkg);
    await prefs.setString(_installedKey, jsonEncode(installed.toList()));
  }

  /// Install and save the full Extension object so sources can be reconstructed.
  Future<void> installFull(Extension ext) async {
    final prefs = await SharedPreferences.getInstance();
    // Update pkg set
    final installed = _loadInstalled(prefs)..add(ext.pkg);
    await prefs.setString(_installedKey, jsonEncode(installed.toList()));
    // Save full data
    final data = _loadInstalledData(prefs);
    data[ext.pkg] = _extToMap(ext);
    await prefs.setString(_installedDataKey, jsonEncode(data));
  }

  Future<void> uninstall(String pkg) async {
    final prefs = await SharedPreferences.getInstance();
    final installed = _loadInstalled(prefs)..remove(pkg);
    await prefs.setString(_installedKey, jsonEncode(installed.toList()));
    final data = _loadInstalledData(prefs)..remove(pkg);
    await prefs.setString(_installedDataKey, jsonEncode(data));
  }

  Future<Set<String>> getInstalledSet() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadInstalled(prefs);
  }

  /// Returns full Extension objects for all installed extensions.
  Future<List<Extension>> getInstalledExtensions() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _loadInstalledData(prefs);
    return data.values
        .map((e) => Extension.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> _loadInstalledData(SharedPreferences prefs) {
    final raw = prefs.getString(_installedDataKey);
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  static Map<String, dynamic> _extToMap(Extension ext) => {
        'name': ext.name,
        'pkg': ext.pkg,
        'apk': ext.apk,
        'lang': ext.lang,
        'code': ext.code,
        'version': ext.version,
        'nsfw': ext.nsfw,
        'sources': ext.sources
            .map((s) => {
                  'name': s.name,
                  'lang': s.lang,
                  'id': s.id,
                  'baseUrl': s.baseUrl,
                })
            .toList(),
      };

  Set<String> _loadInstalled(SharedPreferences prefs) {
    final raw = prefs.getString(_installedKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as List).cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }
}
