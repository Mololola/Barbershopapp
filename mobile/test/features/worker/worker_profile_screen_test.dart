import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/worker/application/worker_controller.dart';
import 'package:mobile/features/worker/domain/worker_invitation.dart';
import 'package:mobile/features/worker/presentation/worker_profile_screen.dart';

void main() {
  Widget buildTestable() {
    return ProviderScope(
      overrides: [
        currentWorkerProfileProvider.overrideWith((ref) async => null),
        receivedInvitationsProvider.overrideWith((ref) async => <WorkerInvitation>[]),
      ],
      child: const MaterialApp(home: WorkerProfileScreen()),
    );
  }

  testWidgets('bio/city fields are hidden until "available as worker" is switched on', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('Experience / bio'), findsNothing);

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    expect(find.text('Experience / bio'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
  });

  testWidgets('requires bio/city once switched on', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Save'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Required'), findsWidgets);
  });

  testWidgets('"Looking for work" is locked off until legal name is filled in', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    final lookingForWorkSwitch = tester.widget<SwitchListTile>(find.byType(SwitchListTile).last);
    expect(lookingForWorkSwitch.value, isFalse);
    expect(lookingForWorkSwitch.onChanged, isNull);

    await tester.enterText(find.widgetWithText(TextFormField, 'Legal first name'), 'Luis');
    await tester.enterText(find.widgetWithText(TextFormField, 'Legal last name'), 'Guillot');
    await tester.pump();

    final enabledSwitch = tester.widget<SwitchListTile>(find.byType(SwitchListTile).last);
    expect(enabledSwitch.onChanged, isNotNull);
  });
}
