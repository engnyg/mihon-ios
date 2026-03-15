import 'package:freezed_annotation/freezed_annotation.dart';

part 'extension.freezed.dart';
part 'extension.g.dart';

@freezed
class ExtensionSource with _$ExtensionSource {
  const factory ExtensionSource({
    required String name,
    required String lang,
    required String id,
    required String baseUrl,
  }) = _ExtensionSource;

  factory ExtensionSource.fromJson(Map<String, dynamic> json) =>
      _$ExtensionSourceFromJson(json);
}

@freezed
class Extension with _$Extension {
  const factory Extension({
    required String name,
    required String pkg,
    required String apk,
    required String lang,
    required int code,
    required String version,
    @Default(0) int nsfw,
    @Default([]) List<ExtensionSource> sources,
    @Default(false) bool installed,
  }) = _Extension;

  factory Extension.fromJson(Map<String, dynamic> json) =>
      _$ExtensionFromJson(json);
}
