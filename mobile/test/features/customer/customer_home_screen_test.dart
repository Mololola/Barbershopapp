import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/supabase_providers.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/customer/application/booking_controller.dart';
import 'package:mobile/features/customer/application/review_controller.dart';
import 'package:mobile/features/customer/domain/booking.dart';
import 'package:mobile/features/customer/presentation/customer_home_screen.dart';
import 'package:mobile/features/messaging/application/messaging_controller.dart';
import 'package:mobile/features/rewards/application/rewards_controller.dart';
import 'package:mobile/features/worker/application/worker_controller.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _cut = Booking(
  id: 'b1',
  customerId: 'me',
  businessId: 'shop',
  workerId: 'w1',
  serviceId: 's1',
  startTime: DateTime.utc(2026, 10, 1, 10),
  endTime: DateTime.utc(2026, 10, 1, 10, 30),
  status: BookingStatus.completed,
);

Widget _home(ReviewPrompt? prompt) {
  return ProviderScope(
    overrides: [
      currentAuthUserIdProvider.overrideWithValue('me'),
      currentProfileProvider.overrideWith((ref) async => null),
      availableBalanceProvider.overrideWith((ref) async => {}),
      myBookingsProvider.overrideWith((ref) async => []),
      conversationsProvider.overrideWith((ref) async => []),
      receivedInvitationsProvider.overrideWith((ref) async => []),
      reviewPromptProvider.overrideWith((ref) async => prompt),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CustomerHomeScreen(),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a cut that can still earn the reward gets a pop-up saying so', (tester) async {
    await tester.pumpWidget(_home(ReviewPrompt(booking: _cut, mentionsReward: true)));
    await tester.pumpAndSettle();

    expect(find.text('How was your cut?'), findsOneWidget);
    expect(find.textContaining('earn a reward'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('How was your cut?'), findsNothing);
  });

  testWidgets('otherwise the pop-up is a plain reminder', (tester) async {
    await tester.pumpWidget(_home(ReviewPrompt(booking: _cut, mentionsReward: false)));
    await tester.pumpAndSettle();

    expect(find.text('How was your cut?'), findsOneWidget);
    expect(find.textContaining('reward'), findsNothing);
  });

  testWidgets('no pop-up when nothing needs a review', (tester) async {
    await tester.pumpWidget(_home(null));
    await tester.pumpAndSettle();

    expect(find.text('How was your cut?'), findsNothing);
  });
}
