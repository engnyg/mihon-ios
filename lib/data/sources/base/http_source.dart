import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../../../core/constants/app_constants.dart';
import '../../../core/error/exceptions.dart';
import '../../../domain/entities/page.dart';
import 'filter.dart';
import 'manga_source.dart';

/// Base class for HTTP-based manga sources.
/// Provides a pre-configured [Dio] client and helpers.
abstract class HttpSource implements MangaSource {
  late final Dio client = _buildClient();

  /// Override to add source-specific headers (e.g., Referer).
  Map<String, String> get headers => {
        'User-Agent': AppConstants.defaultUserAgent,
        'Referer': baseUrl,
      };

  Dio _buildClient() {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: headers,
      ),
    );
    return dio;
  }

  // ── MangaSource default implementations ──────────────────────────────────
  // When using `implements`, default bodies in the interface are NOT inherited.
  // Provide them here so concrete subclasses don't need to repeat them.

  @override
  bool get supportsLatest => true;

  @override
  Future<String> getImageUrl(MangaPage page) async {
    if (page.imageUrl != null) return page.imageUrl!;
    if (page.url != null) return page.url!;
    throw ArgumentError('Page has neither imageUrl nor url');
  }

  @override
  FilterList getFilterList() => FilterList([]);

  // ── Convenience helpers ────────────────────────────────────────────────────

  Future<Response<String>> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await client.get<String>(
        url,
        queryParameters: queryParameters,
        options: options ?? Options(responseType: ResponseType.plain),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const NetworkException('Connection timed out');
      }
      throw ServerException(e.message);
    }
  }

  /// Fetches a URL and parses it as an HTML document.
  Future<dom.Document> getDocument(
    String url, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await get(url, queryParameters: queryParameters);
    return html_parser.parse(response.data ?? '');
  }

  /// Fetches a URL and decodes it as JSON.
  Future<Map<String, dynamic>> getJson(
    String url, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await client.get<Map<String, dynamic>>(
        url,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.json),
      );
      if (response.data == null) throw const ParseException('Empty JSON response');
      return response.data!;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }

  /// POST with JSON body, returns parsed JSON.
  Future<Map<String, dynamic>> postJson(
    String url,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await client.post<Map<String, dynamic>>(
        url,
        data: body,
        options: Options(responseType: ResponseType.json),
      );
      if (response.data == null) throw const ParseException('Empty JSON response');
      return response.data!;
    } on DioException catch (e) {
      throw ServerException(e.message);
    }
  }
}
