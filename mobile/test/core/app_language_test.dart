import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_language.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('follows the phone until a language is chosen, and remembers the choice', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ProviderContainer();
    addTearDown(first.dispose);
    expect(first.read(appLanguageProvider), isNull);

    await first.read(appLanguageProvider.notifier).choose(const Locale('es'));
    expect(first.read(appLanguageProvider), const Locale('es'));

    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    restarted.read(appLanguageProvider);
    await Future<void>.delayed(Duration.zero);
    expect(restarted.read(appLanguageProvider), const Locale('es'));

    await restarted.read(appLanguageProvider.notifier).choose(null);
    expect((await SharedPreferences.getInstance()).getString('app_language'), isNull);
  });
}
