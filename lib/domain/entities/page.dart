import 'package:freezed_annotation/freezed_annotation.dart';

part 'page.freezed.dart';

enum PageStatus { queue, load, ready, error }

@freezed
class MangaPage with _$MangaPage {
  const factory MangaPage({
    required int index,
    String? url,
    String? imageUrl,    // resolved from url (lazy)
    String? localPath,  // set when downloaded
    @Default(PageStatus.queue) PageStatus status,
    String? errorMessage,
  }) = _MangaPage;
}
