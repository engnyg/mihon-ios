import 'package:freezed_annotation/freezed_annotation.dart';

part 'chapter.freezed.dart';

@freezed
class Chapter with _$Chapter {
  const factory Chapter({
    required int? id,
    required int mangaId,
    required String url,
    required String name,
    double? chapterNumber,
    double? volume,
    String? scanlator,
    @Default(false) bool read,
    @Default(false) bool bookmarked,
    @Default(0) int lastReadPage,
    @Default(0) int totalPages,
    DateTime? dateUpload,
    DateTime? dateFetch,
    @Default(false) bool downloaded,
  }) = _Chapter;
}
