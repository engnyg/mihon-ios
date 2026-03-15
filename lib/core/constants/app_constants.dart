class AppConstants {
  AppConstants._();

  static const String appName = 'Mihon';
  static const String version = '0.1.0';

  // Database
  static const String databaseName = 'mihon.db';
  static const int databaseVersion = 1;

  // Network
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const String defaultUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

  // Image cache
  static const int imageCacheMaxObjects = 200;
  static const Duration imageCacheMaxAge = Duration(days: 7);
  static const int readerCacheMaxObjects = 50;

  // Reader
  static const int readerPreloadAhead = 3;
  static const int readerPreloadBehind = 1;
  static const int downloadConcurrency = 3;

  // Library
  static const int libraryGridCrossAxisCount = 3;
  static const double mangaCoverAspectRatio = 2 / 3;

  // Backup
  static const String backupFileExtension = '.mihon';
  static const String backupMimeType = 'application/octet-stream';
}
