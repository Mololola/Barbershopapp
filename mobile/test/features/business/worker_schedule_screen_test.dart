import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/business/application/business_controller.dart';
import 'package:mobile/features/business/domain/business.dart';
import 'package:mobile/features/business/presentation/worker_schedule_screen.dart';

void main() {
  Widget buildTestable() {
    return ProviderScope(
      overrides: [
        workerScheduleProvider.overrideWith((ref, workerId) async => <OpeningHours>[]),
      ],
      child: const MaterialApp(
        home: WorkerScheduleScreen(workerId: 'worker-1', workerName: 'Jane'),
      ),
    );
  }

  testWidgets('renders all 7 days, seeded from an empty schedule', (tester) async {
    // Phone width and tall enough to lay out the whole week — also guards
    // the day rows against overflowing a phone screen.
    tester.view.physicalSize = const Size(1080, 8000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    for (final day in OpeningHours.dayNames) {
      expect(find.text(day), findsOneWidget);
    }
    expect(find.text('Save'), findsOneWidget);
  });
}
