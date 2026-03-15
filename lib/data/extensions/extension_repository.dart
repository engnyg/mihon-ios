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
}

/// Extension bundled with the repo it came from.
class ExtensionEntry {
  const ExtensionEntry({required this.extension, required this.repo});
  final Extension extension;
  final ExtensionRepo repo;
}

/// Fetches extension catalogues (default + user-added repos) and tracks
/// which extensions are "installed" (enabled) locally.
class ExtensionRepository {
  static const _defaultUrl =
      'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json';
  static const _installedKey = 'installed_extensions';
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
    if (repos.any((r) => r.url == url)) return; // already exists
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

  /// Fetches all repos and returns a merged list tagged with their source repo.
  Future<List<ExtensionEntry>> fetchAllExtensions() async {
    final prefs = await SharedPreferences.getInstance();
    final installed = _loadInstalled(prefs);
    final repos = [defaultRepo, ..._loadCustomRepos(prefs)];

    final results = await Future.wait(
      repos.map((repo) => _fetchRepoExtensions(repo, installed)),
    );

    // Merge: de-duplicate by pkg (later repos override earlier ones)
    final seen = <String>{};
    final merged = <ExtensionEntry>[];
    for (final batch in results) {
      for (final entry in batch) {
        if (!seen.contains(entry.extension.pkg)) {
          seen.add(entry.extension.pkg);
          merged.add(entry);
        }
      }
    }
    return merged;
  }

  Future<List<ExtensionEntry>> _fetchRepoExtensions(
    ExtensionRepo repo,
    Set<String> installed,
  ) async {
    try {
      final response = await _dio.get<List<dynamic>>(repo.url);
      final data = response.data ?? [];
      return data.map((e) {
        final ext = Extension.fromJson(e as Map<String, dynamic>)
            .copyWith(installed: installed.contains(
                (e as Map<String, dynamic>)['pkg'] as String? ?? ''));
        return ExtensionEntry(extension: ext, repo: repo);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Legacy: fetches only the default repo. Used internally.
  Future<List<Extension>> fetchIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final installed = _loadInstalled(prefs);
    final response = await _dio.get<List<dynamic>>(_defaultUrl);
    final data = response.data ?? [];
    return data.map((e) {
      final ext = Extension.fromJson(e as Map<String, dynamic>);
      return ext.copyWith(installed: installed.contains(ext.pkg));
    }).toList();
  }

  // ── Install / Uninstall ───────────────────────────────────────────────────────

  Future<void> install(String pkg) async {
    final prefs = await SharedPreferences.getInstance();
    final installed = _loadInstalled(prefs)..add(pkg);
    await prefs.setString(_installedKey, jsonEncode(installed.toList()));
  }

  Future<void> uninstall(String pkg) async {
    final prefs = await SharedPreferences.getInstance();
    final installed = _loadInstalled(prefs)..remove(pkg);
    await prefs.setString(_installedKey, jsonEncode(installed.toList()));
  }

  Future<bool> isInstalled(String pkg) async {
    final prefs = await SharedPreferences.getInstance();
    return _loadInstalled(prefs).contains(pkg);
  }

  Future<Set<String>> getInstalledSet() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadInstalled(prefs);
  }

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
