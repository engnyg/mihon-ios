import 'package:flutter/material.dart';

/// Provides localized strings for the app.
/// Usage: `context.l10n.library`
abstract class AppStrings {
  // Navigation
  String get library;
  String get browse;
  String get updates;
  String get history;
  String get settings;

  // Library
  String get searchLibrary;
  String get emptyLibrary;
  String get emptyLibrarySubtitle;
  String get filterSort;
  String get filtersComingSoon;

  // Browse
  String get sources;
  String get extensions;
  String get popular;
  String get latest;
  String get search;

  // Extensions
  String get installed;
  String get install;
  String get uninstall;
  String get builtIn;
  String get extensionsNsfw;
  String get loadingExtensions;
  String get failedToLoadExtensions;

  // Custom repos
  String get manageRepos;
  String get addRepository;
  String get removeRepository;
  String get repositoryName;
  String get repositoryUrl;
  String get add;
  String get invalidRepositoryUrl;
  String get defaultRepo;
  String get customRepo;

  // Updates
  String get noUpdatesYet;

  // History
  String get noReadingHistory;
  String get clearHistory;
  String get clearHistoryTitle;
  String get clearHistoryMessage;

  // Manga detail
  String get chapters;
  String get showMore;
  String get showLess;
  String get addToLibrary;
  String get removeFromLibrary;

  // Reader
  String get failedToLoadPages;

  // Status
  String get statusOngoing;
  String get statusCompleted;
  String get statusCancelled;
  String get statusHiatus;
  String get statusLicensed;
  String get statusFinished;
  String get statusUnknown;

  // Settings
  String get appearance;
  String get darkMode;
  String get readerSection;
  String get readingDirection;
  String get leftToRight;
  String get rightToLeft;
  String get verticalScroll;
  String get keepScreenOn;
  String get about;
  String get version;
  String get basedOnMihon;
  String get language;

  // Common
  String get retry;
  String get cancel;
  String get clear;

  // Language names (always shown in native script)
  String get langEnglish;
  String get langTraditionalChinese;

  // ── Factory ────────────────────────────────────────────────────────────────

  static AppStrings of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return _fromLocale(locale);
  }

  static AppStrings fromLocale(Locale locale) => _fromLocale(locale);

  static AppStrings _fromLocale(Locale locale) {
    if (locale.languageCode == 'zh') return _ZhTwStrings();
    return _EnStrings();
  }
}

// ── English ──────────────────────────────────────────────────────────────────

class _EnStrings extends AppStrings {
  @override String get library => 'Library';
  @override String get browse => 'Browse';
  @override String get updates => 'Updates';
  @override String get history => 'History';
  @override String get settings => 'Settings';

  @override String get searchLibrary => 'Search library...';
  @override String get emptyLibrary => 'Your library is empty';
  @override String get emptyLibrarySubtitle =>
      'Go to Browse to find manga and add them to your library';
  @override String get filterSort => 'Filter & Sort';
  @override String get filtersComingSoon => 'Filters coming soon';

  @override String get sources => 'Sources';
  @override String get extensions => 'Extensions';
  @override String get popular => 'Popular';
  @override String get latest => 'Latest';
  @override String get search => 'Search...';

  @override String get installed => 'Installed';
  @override String get install => 'Install';
  @override String get uninstall => 'Uninstall';
  @override String get builtIn => 'Built-in';
  @override String get extensionsNsfw => 'NSFW';
  @override String get loadingExtensions => 'Loading extensions...';
  @override String get failedToLoadExtensions => 'Failed to load extensions';

  @override String get manageRepos => 'Manage repositories';
  @override String get addRepository => 'Add repository';
  @override String get removeRepository => 'Remove';
  @override String get repositoryName => 'Repository name';
  @override String get repositoryUrl => 'Repository URL (index.min.json)';
  @override String get add => 'Add';
  @override String get invalidRepositoryUrl => 'Invalid URL';
  @override String get defaultRepo => 'Default';
  @override String get customRepo => 'Custom';

  @override String get noUpdatesYet => 'No updates yet';

  @override String get noReadingHistory => 'No reading history';
  @override String get clearHistory => 'Clear history';
  @override String get clearHistoryTitle => 'Clear history?';
  @override String get clearHistoryMessage =>
      'This will remove all reading history.';

  @override String get chapters => 'Chapters';
  @override String get showMore => 'Show more';
  @override String get showLess => 'Show less';
  @override String get addToLibrary => 'Add to library';
  @override String get removeFromLibrary => 'Remove from library';

  @override String get failedToLoadPages => 'Failed to load pages';

  @override String get statusOngoing => 'Ongoing';
  @override String get statusCompleted => 'Completed';
  @override String get statusCancelled => 'Cancelled';
  @override String get statusHiatus => 'Hiatus';
  @override String get statusLicensed => 'Licensed';
  @override String get statusFinished => 'Finished';
  @override String get statusUnknown => 'Unknown';

  @override String get appearance => 'Appearance';
  @override String get darkMode => 'Dark mode';
  @override String get readerSection => 'Reader';
  @override String get readingDirection => 'Reading direction';
  @override String get leftToRight => 'Left to right';
  @override String get rightToLeft => 'Right to left';
  @override String get verticalScroll => 'Vertical scroll';
  @override String get keepScreenOn => 'Keep screen on';
  @override String get about => 'About';
  @override String get version => 'Version';
  @override String get basedOnMihon => 'Based on Mihon';
  @override String get language => 'Language';

  @override String get retry => 'Retry';
  @override String get cancel => 'Cancel';
  @override String get clear => 'Clear';

  @override String get langEnglish => 'English';
  @override String get langTraditionalChinese => '繁體中文';
}

// ── 繁體中文 ──────────────────────────────────────────────────────────────────

class _ZhTwStrings extends AppStrings {
  @override String get library => '書庫';
  @override String get browse => '瀏覽';
  @override String get updates => '更新';
  @override String get history => '歷史';
  @override String get settings => '設定';

  @override String get searchLibrary => '搜尋書庫…';
  @override String get emptyLibrary => '書庫是空的';
  @override String get emptyLibrarySubtitle => '前往瀏覽頁面搜尋漫畫並加入書庫';
  @override String get filterSort => '篩選與排序';
  @override String get filtersComingSoon => '篩選功能即將推出';

  @override String get sources => '來源';
  @override String get extensions => '擴充功能';
  @override String get popular => '熱門';
  @override String get latest => '最新';
  @override String get search => '搜尋…';

  @override String get installed => '已安裝';
  @override String get install => '安裝';
  @override String get uninstall => '解除安裝';
  @override String get builtIn => '內建';
  @override String get extensionsNsfw => '成人內容';
  @override String get loadingExtensions => '載入擴充功能中…';
  @override String get failedToLoadExtensions => '無法載入擴充功能';

  @override String get manageRepos => '管理來源庫';
  @override String get addRepository => '新增來源庫';
  @override String get removeRepository => '移除';
  @override String get repositoryName => '來源庫名稱';
  @override String get repositoryUrl => '來源庫網址 (index.min.json)';
  @override String get add => '新增';
  @override String get invalidRepositoryUrl => '無效的網址';
  @override String get defaultRepo => '預設';
  @override String get customRepo => '自訂';

  @override String get noUpdatesYet => '暫無更新';

  @override String get noReadingHistory => '沒有閱讀記錄';
  @override String get clearHistory => '清除歷史';
  @override String get clearHistoryTitle => '清除閱讀記錄？';
  @override String get clearHistoryMessage => '這將刪除所有閱讀記錄。';

  @override String get chapters => '章節';
  @override String get showMore => '顯示更多';
  @override String get showLess => '收起';
  @override String get addToLibrary => '加入書庫';
  @override String get removeFromLibrary => '從書庫移除';

  @override String get failedToLoadPages => '無法載入頁面';

  @override String get statusOngoing => '連載中';
  @override String get statusCompleted => '已完結';
  @override String get statusCancelled => '已中止';
  @override String get statusHiatus => '暫停中';
  @override String get statusLicensed => '已授權';
  @override String get statusFinished => '已完結';
  @override String get statusUnknown => '未知';

  @override String get appearance => '外觀';
  @override String get darkMode => '深色模式';
  @override String get readerSection => '閱讀器';
  @override String get readingDirection => '閱讀方向';
  @override String get leftToRight => '從左到右';
  @override String get rightToLeft => '從右到左';
  @override String get verticalScroll => '垂直捲動';
  @override String get keepScreenOn => '保持螢幕常亮';
  @override String get about => '關於';
  @override String get version => '版本';
  @override String get basedOnMihon => '基於 Mihon';
  @override String get language => '語言';

  @override String get retry => '重試';
  @override String get cancel => '取消';
  @override String get clear => '清除';

  @override String get langEnglish => 'English';
  @override String get langTraditionalChinese => '繁體中文';
}

// ── BuildContext extension ────────────────────────────────────────────────────

extension AppStringsExt on BuildContext {
  AppStrings get l10n => AppStrings.of(this);
}
