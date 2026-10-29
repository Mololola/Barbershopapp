import '../../../l10n/app_localizations.dart';

enum RankingWindow { week, month, year, allTime }

extension RankingWindowX on RankingWindow {
  String label(AppLocalizations l10n) => switch (this) {
        RankingWindow.week => l10n.windowWeek,
        RankingWindow.month => l10n.windowMonth,
        RankingWindow.year => l10n.windowYear,
        RankingWindow.allTime => l10n.windowAllTime,
      };

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
