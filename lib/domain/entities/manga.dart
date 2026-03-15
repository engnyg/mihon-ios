import 'package:freezed_annotation/freezed_annotation.dart';

part 'manga.freezed.dart';

enum MangaStatus { unknown, ongoing, completed, licensed, publishingFinished, cancelled, onHiatus }

@freezed
class Manga with _$Manga {
  const factory Manga({
    required int? id,           // null before persisted to DB
    required String sourceId,
    required String url,
    required String title,
    String? coverUrl,
    String? author,
    String? artist,
    String? description,
    @Default([]) List<String> genres,
    @Default(MangaStatus.unknown) MangaStatus status,
    @Default(false) bool inLibrary,
    DateTime? lastUpdated,
    DateTime? lastRead,
    @Default(0) int unreadCount,
    @Default(0) int downloadCount,
  }) = _Manga;
}
