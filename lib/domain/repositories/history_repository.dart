import '../entities/reading_history.dart';

abstract interface class HistoryRepository {
  Stream<List<ReadingHistory>> watchHistory();
  Future<void> recordHistory(int chapterId);
  Future<void> deleteHistoryEntry(int historyId);
  Future<void> clearAllHistory();
}
