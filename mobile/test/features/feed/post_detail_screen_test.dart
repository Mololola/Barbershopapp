import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:mobile/features/feed/application/feed_controller.dart';
import 'package:mobile/features/feed/domain/post.dart';
import 'package:mobile/features/feed/presentation/post_detail_screen.dart';

void main() {
  const myProfile =
      Profile(id: 'me-1', role: AccountRole.customer, username: 'me', referralCode: 'MYCODE01');

  final topLevel = Comment(
    id: 'c1',
    postId: 'post-1',
    parentCommentId: null,
    authorId: 'other-1',
    authorUsername: 'other_barber',
    body: 'Nice cut',
    likeCount: 0,
    likedByMe: false,
    createdAt: DateTime.utc(2026, 8, 1),
  );
  final reply = Comment(
    id: 'r1',
    postId: 'post-1',
    parentCommentId: 'c1',
    authorId: 'me-1',
    authorUsername: 'me',
    body: 'Thanks!',
    likeCount: 0,
    likedByMe: false,
    createdAt: DateTime.utc(2026, 8, 2),
  );

  Widget buildTestable() {
    return ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => myProfile),
        commentsProvider.overrideWith((ref, postId) async => [topLevel, reply]),
      ],
      child: const MaterialApp(home: PostDetailScreen(postId: 'post-1')),
    );
  }

  testWidgets('a reply renders under its parent and Reply pre-fills the replying-to state', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('other_barber'), findsOneWidget);
    expect(find.text('Nice cut'), findsOneWidget);
    expect(find.text('Thanks!'), findsOneWidget);

    // Only the top-level comment gets a Reply button — replies don't.
    expect(find.text('Reply'), findsOneWidget);

    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();

    expect(find.text('Replying to other_barber'), findsOneWidget);
  });
}
