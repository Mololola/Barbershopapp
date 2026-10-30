import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

const _prefsKey = 'app_language';

/// The language picked in Settings, kept on this device. Null means follow
/// the phone's language.
class AppLanguageNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    // Read after the first frame, which the launch animation covers.
    SharedPreferences.getInstance().then((prefs) {
      final code = prefs.getString(_prefsKey);
      if (code != null) state = Locale(code);
    });
    return null;
  }

  Future<void> choose(Locale? locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, locale.languageCode);
    }
  }
}

final appLanguageProvider = NotifierProvider<AppLanguageNotifier, Locale?>(AppLanguageNotifier.new);

/// The language the app is showing, for requests whose replies the user
/// reads: the one picked in Settings, else the phone's when the app has it,
/// else English — as MaterialApp resolves it.
String appLanguageCode(Locale? chosen) {
  if (chosen != null) return chosen.languageCode;
  final phone = PlatformDispatcher.instance.locale.languageCode;
  return AppLocalizations.supportedLocales.any((l) => l.languageCode == phone) ? phone : 'en';
}
