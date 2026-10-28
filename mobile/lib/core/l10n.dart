import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';

extension L10n on BuildContext {
  /// The app's text in the phone's language. Falls back to English where no
  /// localizations are set up above this widget (widget tests that pump a
  /// bare MaterialApp), so those keep working unchanged.
  AppLocalizations get l10n => AppLocalizations.of(this) ?? lookupAppLocalizations(const Locale('en'));
}
