import 'package:freezed_annotation/freezed_annotation.dart';
import 'manga.dart';
import 'chapter.dart';

part 'reading_history.freezed.dart';

@freezed
class ReadingHistory with _$ReadingHistory {
  const factory ReadingHistory({
    required int id,
    required Chapter chapter,
    required Manga manga,
    required DateTime lastRead,
  }) = _ReadingHistory;
}
