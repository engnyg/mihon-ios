class ServerException implements Exception {
  const ServerException([this.message]);
  final String? message;
  @override
  String toString() => 'ServerException: ${message ?? 'Unknown server error'}';
}

class NetworkException implements Exception {
  const NetworkException([this.message]);
  final String? message;
  @override
  String toString() => 'NetworkException: ${message ?? 'No network connection'}';
}

class CacheException implements Exception {
  const CacheException([this.message]);
  final String? message;
  @override
  String toString() => 'CacheException: ${message ?? 'Cache error'}';
}

class SourceException implements Exception {
  const SourceException([this.message]);
  final String? message;
  @override
  String toString() => 'SourceException: ${message ?? 'Source error'}';
}

class ParseException implements Exception {
  const ParseException([this.message]);
  final String? message;
  @override
  String toString() => 'ParseException: ${message ?? 'Parse error'}';
}

class RateLimitException implements Exception {
  const RateLimitException({this.retryAfterSeconds});
  final int? retryAfterSeconds;
  @override
  String toString() =>
      'RateLimitException: Rate limited. Retry after ${retryAfterSeconds ?? '?'}s';
}
