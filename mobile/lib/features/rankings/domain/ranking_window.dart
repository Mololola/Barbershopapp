enum RankingWindow { week, month, year, allTime }

extension RankingWindowX on RankingWindow {
  String get label {
    switch (this) {
      case RankingWindow.week:
        return 'This week';
      case RankingWindow.month:
        return 'This month';
      case RankingWindow.year:
        return 'This year';
      case RankingWindow.allTime:
        return 'All time';
    }
  }

  /// Rolling window, not calendar-aligned — simplest to compute and a
  /// standard leaderboard convention. Null means "no lower bound".
  DateTime? get startDate {
    final now = DateTime.now();
    switch (this) {
      case RankingWindow.week:
        return now.subtract(const Duration(days: 7));
      case RankingWindow.month:
        return now.subtract(const Duration(days: 30));
      case RankingWindow.year:
        return now.subtract(const Duration(days: 365));
      case RankingWindow.allTime:
        return null;
    }
  }
}
