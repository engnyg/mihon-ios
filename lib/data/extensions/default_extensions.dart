import '../sources/tachi_ext/tachi_extension_def.dart';

/// Pre-defined JSON extension definitions bundled with the app.
/// These are loaded at startup and registered in SourceRegistry automatically.
/// They provide real CSS selectors for well-known sources so users don't need
/// to manually find and install individual definition files.
const List<TachiExtDef> kDefaultExtensions = [
  _jmcomic,
];

// ── 禁漫天堂 (18comic.vip) ────────────────────────────────────────────────────

const _jmcomic = TachiExtDef(
  id: 'jmcomic',
  name: '禁漫天堂',
  lang: 'zh',
  version: '1.0',
  nsfw: true,
  baseUrl: 'https://18comic.vip',
  popularMangaUrl: '/albums?o=mv&page={page}',
  latestMangaUrl: '/albums?o=mr&page={page}',
  searchMangaUrl: '/search/photos?search_query={query}&page={page}',
  // Album grid: each card is a .col-xs-6 / .col-md-3 with a .well wrapper
  mangaListSelector: 'div.well',
  mangaUrlSelector: 'a@href',
  titleSelector: '.video-title',
  thumbnailSelector: 'img@data-original',
  nextPageSelector: 'a[rel=next]',
  // Detail page
  descriptionSelector: '#intro-block .p-t-5 div',
  authorSelector: '.tag-block:first-of-type a',
  // Chapter list (episode list)
  chapterListSelector: '.episode .btn-toolbar a',
  chapterTitleSelector: '@title',
  chapterUrlSelector: '@href',
  // Page images (note: newer albums use server-side scrambling;
  // images may appear as segments that require client descrambling)
  pageListSelector: '#images-wrapper img@data-original',
  headers: {
    'Cookie': 'isAdult=1; age_gate_pass=1',
    'Referer': 'https://18comic.vip/',
  },
);
