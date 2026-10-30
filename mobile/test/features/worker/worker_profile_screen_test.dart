import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/worker/application/worker_controller.dart';
import 'package:mobile/features/worker/domain/worker_invitation.dart';
import 'package:mobile/features/worker/domain/worker_profile.dart';
import 'package:mobile/features/worker/presentation/worker_profile_screen.dart';

void main() {
  Widget buildTestable({WorkerProfile? profile, List<WorkerInvitation> invitations = const []}) {
    return ProviderScope(
      overrides: [
        currentWorkerProfileProvider.overrideWith((ref) async => profile),
        receivedInvitationsProvider.overrideWith((ref) async => invitations),
        currentJobProvider.overrideWith((ref) async => null),
        pendingLeaveRequestProvider.overrideWith((ref) async => null),
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

  testWidgets('once a profile exists, Looking for work is the only on/off switch', (tester) async {
    await tester.pumpWidget(buildTestable(
      profile: const WorkerProfile(
        profileId: 'me',
        legalFirstName: 'Luis',
        legalLastName: 'Guillot',
        bio: 'Fades',
        city: 'Madrid',
        isLookingForWork: true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Available as worker'), findsNothing);
    expect(find.text('Looking for work'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('a pending invitation comes first, and declining asks before it goes', (tester) async {
    await tester.pumpWidget(buildTestable(invitations: [
      WorkerInvitation(
        id: 'inv-1',
        businessId: 'shop-1',
        workerProfileId: 'me',
        status: InvitationStatus.pending,
        businessName: 'Fresh Cuts',
        createdAt: DateTime(2026, 10, 30),
      ),
    ]));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Fresh Cuts')).dy, lessThan(tester.getTopLeft(find.text('Current job')).dy));
    expect(find.widgetWithText(FilledButton, 'Accept'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Decline'));
    await tester.pumpAndSettle();
    expect(find.text("Decline Fresh Cuts's invitation?"), findsOneWidget);

    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(find.text('Fresh Cuts'), findsOneWidget);
  });
}
