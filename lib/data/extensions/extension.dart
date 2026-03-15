/// Extension model — plain Dart, no code generation required.
/// Parsed manually from the keiyoushi index.min.json format.

class ExtensionSource {
  const ExtensionSource({
    required this.name,
    required this.lang,
    required this.id,
    required this.baseUrl,
  });

  final String name;
  final String lang;
  final String id;
  final String baseUrl;

  factory ExtensionSource.fromJson(Map<String, dynamic> json) =>
      ExtensionSource(
        name: json['name'] as String? ?? '',
        lang: json['lang'] as String? ?? 'en',
        id: json['id']?.toString() ?? '',
        baseUrl: json['baseUrl'] as String? ?? '',
      );
}

class Extension {
  const Extension({
    required this.name,
    required this.pkg,
    required this.apk,
    required this.lang,
    required this.code,
    required this.version,
    this.nsfw = 0,
    this.sources = const [],
    this.installed = false,
  });

  final String name;
  final String pkg;
  final String apk;
  final String lang;
  final int code;
  final String version;
  final int nsfw;
  final List<ExtensionSource> sources;
  final bool installed;

  factory Extension.fromJson(Map<String, dynamic> json) => Extension(
        name: json['name'] as String? ?? '',
        pkg: json['pkg'] as String? ?? '',
        apk: json['apk'] as String? ?? '',
        lang: json['lang'] as String? ?? 'en',
        code: json['code'] as int? ?? 0,
        // version may be int or string in some repos
        version: json['version']?.toString() ?? '0',
        nsfw: json['nsfw'] as int? ?? 0,
        sources: (json['sources'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(ExtensionSource.fromJson)
                .toList() ??
            [],
        installed: json['installed'] as bool? ?? false,
      );

  Extension copyWith({
    String? name,
    String? pkg,
    String? apk,
    String? lang,
    int? code,
    String? version,
    int? nsfw,
    List<ExtensionSource>? sources,
    bool? installed,
  }) =>
      Extension(
        name: name ?? this.name,
        pkg: pkg ?? this.pkg,
        apk: apk ?? this.apk,
        lang: lang ?? this.lang,
        code: code ?? this.code,
        version: version ?? this.version,
        nsfw: nsfw ?? this.nsfw,
        sources: sources ?? this.sources,
        installed: installed ?? this.installed,
      );
}
