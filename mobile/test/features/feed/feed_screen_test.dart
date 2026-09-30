import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:mobile/features/feed/application/feed_controller.dart';
import 'package:mobile/features/feed/domain/post.dart';
import 'package:mobile/features/feed/presentation/feed_screen.dart';

void main() {
  const myProfile =
      Profile(id: 'me-1', role: AccountRole.customer, username: 'me', referralCode: 'MYCODE01');

  final myPost = Post(
    id: 'post-1',
    authorId: 'me-1',
    authorUsername: 'me',
    body: 'Fresh fade today',
    mediaUrl: null,
    mediaType: PostMediaType.image,
    likeCount: 2,
    commentCount: 1,
    likedByMe: true,
    createdAt: DateTime.utc(2026, 8, 1),
    isPinned: false,
  );
  final otherPost = Post(
    id: 'post-2',
    authorId: 'other-1',
    authorUsername: 'other_barber',
    body: 'New shop opening',
    mediaUrl: null,
    mediaType: PostMediaType.image,
    likeCount: 0,
    commentCount: 0,
    likedByMe: false,
    createdAt: DateTime.utc(2026, 8, 2),
    isPinned: false,
  );

  Widget buildTestable() {
    return ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => myProfile),
        feedProvider.overrideWith((ref) async => [otherPost, myPost]),
      ],
      child: const MaterialApp(home: FeedScreen()),
    );
  }

  testWidgets('renders posts with correct like state, counts, and own-post delete option', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('me'), findsOneWidget);
    expect(find.text('other_barber'), findsOneWidget);
    expect(find.text('Fresh fade today'), findsOneWidget);
    expect(find.text('New shop opening'), findsOneWidget);

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);

    // Only the signed-in user's own post shows a delete option.
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  // Posts are shared by both roles, so they must open on the top-level
  // /posts routes — not a path nested under one role's tab shell, which
  // is what switched a business into the customer's tabs.
  testWidgets('new post, a post, and the leaderboards open on shared routes', (tester) async {
    final router = GoRouter(
      initialLocation: '/feed',
      routes: [
        GoRoute(path: '/feed', builder: (context, state) => const FeedScreen()),
        GoRoute(path: '/posts/new', builder: (context, state) => const Scaffold(body: Text('new post'))),
        GoRoute(
          path: '/posts/:postId',
          builder: (context, state) => Scaffold(body: Text('post ${state.pathParameters['postId']}')),
        ),
        GoRoute(path: '/rankings', builder: (context, state) => const Scaffold(body: Text('rankings'))),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => myProfile),
        feedProvider.overrideWith((ref) async => [otherPost, myPost]),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('new post'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.mode_comment_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('post post-2'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Leaderboards'));
    await tester.pumpAndSettle();
    expect(find.text('rankings'), findsOneWidget);
  });
}
