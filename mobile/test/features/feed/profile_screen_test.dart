import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:mobile/features/feed/application/feed_controller.dart';
import 'package:mobile/features/feed/domain/post.dart';
import 'package:mobile/features/feed/presentation/profile_screen.dart';
import 'package:mobile/features/worker/application/worker_controller.dart';
import 'package:mobile/features/worker/domain/worker_profile.dart';

void main() {
  const customerProfile = Profile(
    id: 'cust-1',
    role: AccountRole.customer,
    username: 'customer_one',
    referralCode: 'CUSTCODE',
  );
  const businessProfile = Profile(
    id: 'biz-1',
    role: AccountRole.business,
    username: 'biz_one',
    referralCode: 'BIZCODE1',
  );
  const viewer =
      Profile(id: 'viewer-1', role: AccountRole.customer, username: 'viewer', referralCode: 'VIEWCODE');

  const workerProfile = WorkerProfile(
    profileId: 'cust-1',
    legalFirstName: 'Jane',
    legalLastName: 'Doe',
    bio: 'Ten years of barbering',
    city: 'Madrid',
    isLookingForWork: true,
  );

  Widget buildTestable(Profile viewedProfile, {required Profile signedInAs, WorkerProfile? workerData}) {
    return ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => signedInAs),
        profileByIdProvider.overrideWith((ref, id) async => viewedProfile),
        workerProfileByIdProvider.overrideWith((ref, id) async => workerData),
        postsByAuthorProvider.overrideWith((ref, id) async => <Post>[]),
      ],
      child: MaterialApp(home: ProfileScreen(profileId: viewedProfile.id)),
    );
  }

  testWidgets('shows a single worker-status line for a customer with a worker profile', (tester) async {
    await tester.pumpWidget(
      buildTestable(customerProfile, signedInAs: viewer, workerData: workerProfile),
    );
    await tester.pumpAndSettle();

    expect(find.text('Worker status: Barber'), findsOneWidget);
    // The detailed breakdown moved to the business worker-browse screen.
    expect(find.textContaining('Looking for work'), findsNothing);
    expect(find.textContaining('Ten years of barbering'), findsNothing);
  });

  testWidgets('omits the worker-status line for a customer with no worker profile', (tester) async {
    await tester.pumpWidget(
      buildTestable(customerProfile, signedInAs: viewer, workerData: null),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Worker status'), findsNothing);
  });

  testWidgets('omits the worker-status line for a business profile', (tester) async {
    await tester.pumpWidget(
      buildTestable(businessProfile, signedInAs: viewer, workerData: workerProfile),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Worker status'), findsNothing);
  });

  testWidgets('no edit icon when viewing someone else\'s profile', (tester) async {
    await tester.pumpWidget(
      buildTestable(customerProfile, signedInAs: viewer, workerData: null),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('your own profile has the settings gear (no separate edit pencil)', (tester) async {
    await tester.pumpWidget(
      buildTestable(customerProfile, signedInAs: customerProfile, workerData: null),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });
}
