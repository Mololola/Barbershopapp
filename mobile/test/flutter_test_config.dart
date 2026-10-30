import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';

/// Runs before every test file. Most widget tests pump a bare MaterialApp,
/// which doesn't load the date data the app's localizations do, so dates in
/// translated text would throw there.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeDateFormatting();
  await testMain();
}
