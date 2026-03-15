import '../sources/tachi_ext/tachi_extension_def.dart';

/// Pre-defined JSON extension definitions bundled with the app.
/// These are loaded at startup and registered in SourceRegistry automatically.
/// They provide real CSS selectors for well-known sources so users don't need
/// to manually find and install individual definition files.
const List<TachiExtDef> kDefaultExtensions = [
  _jmcomic,
  _baozimh,
  _3hentai,
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

// ── 包子漫畫 (baozimh.com) ────────────────────────────────────────────────────
// Reader pages redirect from baozimh.com to twmanga.com (Dio follows
// redirects automatically). Images are full-size static <img src=...> tags.

const _baozimh = TachiExtDef(
  id: 'baozimh',
  name: '包子漫畫',
  lang: 'zh',
  version: '1.0',
  nsfw: false,
  baseUrl: 'https://www.baozimh.com',
  popularMangaUrl: '/classify?type=all&region=all&state=all&sort=view&page={page}',
  latestMangaUrl: '/classify?type=all&region=all&state=all&sort=update&page={page}',
  searchMangaUrl: '/search?q={query}&page={page}',
  // Manga card: .comics-card is itself an <a> element (display:block)
  mangaListSelector: '.comics-card',
  mangaUrlSelector: '@href',
  titleSelector: '.comics-card__title',
  thumbnailSelector: '.comics-card__poster img@src',
  nextPageSelector: '.pager a:last-child',
  // Detail page
  descriptionSelector: '.comics-detail__desc',
  authorSelector: '.comics-detail__author',
  // Chapter list: each .comics-chapters__item is an <a> with a child <div> title
  // Chapter URLs are /user/page_direct?... which redirect to twmanga.com reader
  chapterListSelector: '.comics-chapters__item',
  chapterTitleSelector: 'div',
  chapterUrlSelector: '@href',
  // Reader (twmanga.com): images are in <div role="list"> as static <img src>
  pageListSelector: '[role=list] img@src',
  headers: {
    'Referer': 'https://www.baozimh.com/',
  },
);

// ── 3Hentai (3hentai.net) ────────────────────────────────────────────────────
// In keiyoushi zh repo. Gallery listing and detail pages use static HTML.
// Note: page images are CDN thumbnails (lower resolution than full-size).
// Sites like NHentai/HentaiFox/IMHentai use JavaScript-rendered images and
// are incompatible with CSS selector scraping.

const _3hentai = TachiExtDef(
  id: '3hentai',
  name: '3Hentai',
  lang: 'zh',
  version: '1.0',
  nsfw: true,
  baseUrl: 'https://3hentai.net',
  // Path-based pagination: /1, /2, /3 ...
  popularMangaUrl: '/{page}',
  latestMangaUrl: '/newest/{page}',
  searchMangaUrl: '/?search={query}&page={page}',
  // Gallery items: <a href="/d/ID"> containing <img> and title text
  mangaListSelector: 'a[href*="/d/"]',
  mangaUrlSelector: '@href',
  // Title is the text content of the <a> element itself (no dedicated class)
  titleSelector: '',
  thumbnailSelector: 'img@src',
  // Pagination: numbered path links (/2, /3, ...)
  nextPageSelector: 'a[href*="3hentai.net/"]',
  // Detail page
  authorSelector: 'a[href*="/artist"]',
  // Single-chapter doujin — no chapter list
  chapterListSelector: null,
  // Page images: static <img src="https://s1.3hentai.net/d.../Nt.jpg">
  // 't' suffix = thumbnail; full-size requires URL rewrite (not supported)
  pageListSelector: 'img[src*="3hentai.net/d"]:not([src*="cover"])@src',
  headers: {
    'Referer': 'https://3hentai.net/',
  },
);
