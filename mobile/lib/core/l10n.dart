import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';
export 'error_messages.dart';

extension L10n on BuildContext {
  /// The app's text in the phone's language. Falls back to English where no
  /// localizations are set up above this widget (widget tests that pump a
  /// bare MaterialApp), so those keep working unchanged.
  AppLocalizations get l10n => AppLocalizations.of(this) ?? lookupAppLocalizations(const Locale('en'));

  /// The full weekday name for an opening-hours day (0 = Monday), capitalised
  /// (Spanish writes them in lower case).
  String weekdayName(int dayOfWeek) {
    final name = DateFormat.EEEE(l10n.localeName).format(DateTime(2024, 1, 1 + dayOfWeek));
    return name[0].toUpperCase() + name.substring(1);
  }
}
