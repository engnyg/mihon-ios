import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'extension.dart';

/// Fetches the extension catalogue from keiyoushi and tracks
/// which extensions are "installed" (enabled) locally.
class ExtensionRepository {
  static const _indexUrl =
      'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json';
  static const _installedKey = 'installed_extensions';

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

  // ── Index ────────────────────────────────────────────────────────────────

  Future<List<Extension>> fetchIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final installed = _loadInstalled(prefs);

    final response = await _dio.get<List<dynamic>>(_indexUrl);
    final data = response.data ?? [];

    return data.map((e) {
      final ext = Extension.fromJson(e as Map<String, dynamic>);
      return ext.copyWith(installed: installed.contains(ext.pkg));
    }).toList();
  }

  // ── Install / Uninstall ───────────────────────────────────────────────────

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
