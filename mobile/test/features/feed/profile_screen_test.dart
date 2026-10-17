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

  testWidgets('a customer with a worker profile gets a Barber badge, and nothing more about the job', (tester) async {
    await tester.pumpWidget(
      buildTestable(customerProfile, signedInAs: viewer, workerData: workerProfile),
    );
    await tester.pumpAndSettle();

    expect(find.text('Barber'), findsOneWidget);
    // The detailed breakdown stays on the business worker-browse screen.
    expect(find.textContaining('Looking for work'), findsNothing);
    expect(find.textContaining('Ten years of barbering'), findsNothing);
  });

  testWidgets('no Barber badge for a customer with no worker profile', (tester) async {
    await tester.pumpWidget(
      buildTestable(customerProfile, signedInAs: viewer, workerData: null),
    );
    await tester.pumpAndSettle();

    expect(find.text('Barber'), findsNothing);
    expect(find.text('Customer'), findsOneWidget);
  });

  testWidgets('no Barber badge for a business profile', (tester) async {
    await tester.pumpWidget(
      buildTestable(businessProfile, signedInAs: viewer, workerData: workerProfile),
    );
    await tester.pumpAndSettle();

    expect(find.text('Barber'), findsNothing);
  });

  testWidgets('someone else\'s profile offers Message, not Edit profile', (tester) async {
    await tester.pumpWidget(
      buildTestable(customerProfile, signedInAs: viewer, workerData: null),
    );
    await tester.pumpAndSettle();
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Edit profile'), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
  });

  testWidgets('no Message button to or from an under-18 account', (tester) async {
    await tester.pumpWidget(
      buildTestable(
        const Profile(id: 'teen-1', role: AccountRole.customer, username: 'teen', referralCode: 'TEENCODE', isMinor: true),
        signedInAs: viewer,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Message'), findsNothing);
  });

  testWidgets('your own profile has Settings, Edit profile and a way to post when empty', (tester) async {
    await tester.pumpWidget(
      buildTestable(customerProfile, signedInAs: customerProfile, workerData: null),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Message'), findsNothing);
    expect(find.text('No posts yet'), findsOneWidget);
    expect(find.text('Share your first post'), findsOneWidget);
  });

  testWidgets('posts show as a grid with their totals in the header', (tester) async {
    Post post(String id, {required int likes, required int comments}) => Post(
          id: id,
          authorId: 'cust-1',
          authorUsername: 'customer_one',
          body: 'Fresh fade $id',
          // Text-only, so the tile shows the text and the test needs no network image.
          mediaUrl: null,
          mediaType: PostMediaType.image,
          isPinned: false,
          likeCount: likes,
          commentCount: comments,
          likedByMe: false,
          createdAt: DateTime.utc(2026, 10, 1),
        );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => viewer),
        profileByIdProvider.overrideWith((ref, id) async => customerProfile),
        workerProfileByIdProvider.overrideWith((ref, id) async => null),
        postsByAuthorProvider.overrideWith((ref, id) async => [post('a', likes: 3, comments: 1), post('b', likes: 4, comments: 0)]),
      ],
      child: const MaterialApp(home: ProfileScreen(profileId: 'cust-1')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Fresh fade a'), findsOneWidget);
    expect(find.text('Fresh fade b'), findsOneWidget);
    // Posts, likes, comments.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}
