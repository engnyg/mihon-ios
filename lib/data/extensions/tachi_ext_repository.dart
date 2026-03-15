import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sources/tachi_ext/tachi_extension_def.dart';

/// Manages installation/storage of Tachimanga-format JSON extensions.
///
/// Each extension is stored as its serialised [TachiExtDef] JSON in
/// SharedPreferences under [_storeKey].
class TachiExtRepository {
  static const _storeKey = 'tachi_ext_defs';

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  // ── Read ───────────────────────────────────────────────────────────────────

  Future<List<TachiExtDef>> getInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    return _load(prefs);
  }

  // ── Install ────────────────────────────────────────────────────────────────

  /// Downloads a JSON extension definition from [url], validates it,
  /// saves it, and returns the parsed [TachiExtDef].
  ///
  /// Throws if the URL cannot be fetched or the JSON is invalid.
  Future<TachiExtDef> installFromUrl(String url) async {
    final def = await _fetch(url);
    if (def.id.isEmpty) throw Exception('Extension JSON is missing "id" field');
    if (def.name.isEmpty) {
      throw Exception('Extension JSON is missing "name" field');
    }
    if (def.baseUrl.isEmpty) {
      throw Exception('Extension JSON is missing "baseUrl" field');
    }
    await _save(def);
    return def;
  }

  /// Saves a [TachiExtDef] that was constructed directly (e.g. from a repo).
  Future<void> install(TachiExtDef def) => _save(def);

  // ── Uninstall ──────────────────────────────────────────────────────────────

  Future<void> uninstall(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final defs = _load(prefs)..removeWhere((d) => d.id == id);
    await _persist(prefs, defs);
  }

  // ── Validate (fetch without saving) ───────────────────────────────────────

  /// Fetches [url] and returns the parsed def without installing it.
  /// Throws on network error or invalid JSON.
  Future<TachiExtDef> validateUrl(String url) => _fetch(url);

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<TachiExtDef> _fetch(String url) async {
    final resp = await _dio.get<dynamic>(url);
    final raw = resp.data;
    Map<String, dynamic> map;
    if (raw is Map<String, dynamic>) {
      map = raw;
    } else if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Expected a JSON object, got ${decoded.runtimeType}');
      }
      map = decoded;
    } else {
      throw Exception('Unexpected response type: ${raw.runtimeType}');
    }
    return TachiExtDef.fromJson(map);
  }

  Future<void> _save(TachiExtDef def) async {
    final prefs = await SharedPreferences.getInstance();
    final defs = _load(prefs)..removeWhere((d) => d.id == def.id);
    defs.add(def);
    await _persist(prefs, defs);
  }

  List<TachiExtDef> _load(SharedPreferences prefs) {
    final raw = prefs.getString(_storeKey);
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
        _storeKey, jsonEncode(defs.map((d) => d.toJson()).toList()));
  }
}
