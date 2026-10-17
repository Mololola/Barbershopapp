import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:mobile/features/feed/application/feed_controller.dart';
import 'package:mobile/features/feed/data/feed_repository.dart';
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
        feedProvider.overrideWith(() => _FixedFeed([otherPost, myPost])),
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

    // Only the signed-in user's own post has the options menu, and deleting
    // asks first.
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this post?'), findsOneWidget);
  });

  testWidgets('an empty feed invites the first post', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => myProfile),
        feedProvider.overrideWith(() => _FixedFeed([])),
      ],
      child: const MaterialApp(home: FeedScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('The wall is empty'), findsOneWidget);
    expect(find.text('Share a post'), findsOneWidget);
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
        feedProvider.overrideWith(() => _FixedFeed([otherPost, myPost])),
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

  test('pages through the feed, older posts after the oldest one shown', () async {
    final posts = [
      for (var i = 0; i < feedPageSize + 3; i++)
        Post(
          id: 'p$i',
          authorId: 'other-1',
          authorUsername: 'other_barber',
          body: 'Post $i',
          mediaUrl: null,
          mediaType: PostMediaType.image,
          likeCount: 0,
          commentCount: 0,
          likedByMe: false,
          createdAt: DateTime.utc(2026, 8, 30).subtract(Duration(hours: i)),
          isPinned: false,
        ),
    ];
    final repository = _PagedRepository(posts);
    final container = ProviderContainer(overrides: [
      currentProfileProvider.overrideWith((ref) async => myProfile),
      feedRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);

    final first = await container.read(feedProvider.future);
    expect(first.posts, hasLength(feedPageSize));
    expect(first.hasMore, isTrue);

    await container.read(feedProvider.notifier).loadMore();
    final all = container.read(feedProvider).value!;
    expect(all.posts.map((p) => p.id), posts.map((p) => p.id));
    expect(all.hasMore, isFalse);
    expect(repository.befores, [null, posts[feedPageSize - 1].createdAt]);
  });

  testWidgets('asks for the next page well before the end', (tester) async {
    final page = [
      for (var i = 0; i < feedPageSize; i++)
        Post(
          id: 'p$i',
          authorId: 'other-1',
          authorUsername: 'other_barber',
          body: 'Post $i',
          mediaUrl: null,
          mediaType: PostMediaType.image,
          likeCount: 0,
          commentCount: 0,
          likedByMe: false,
          createdAt: DateTime.utc(2026, 8, 30).subtract(Duration(hours: i)),
          isPinned: false,
        ),
    ];
    final feed = _FixedFeed(page, hasMore: true);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => myProfile),
        feedProvider.overrideWith(() => feed),
      ],
      child: const MaterialApp(home: FeedScreen()),
    ));
    // The loading footer animates for as long as there's more to load, so
    // the screen never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 100));

    expect(feed.loadMoreCalls, greaterThan(0));
    // The last post hasn't been reached yet.
    expect(find.text('Post ${feedPageSize - 1}'), findsNothing);
  });

  testWidgets('the end of the feed says so', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => myProfile),
        feedProvider.overrideWith(() => _FixedFeed([otherPost, myPost])),
      ],
      child: const MaterialApp(home: FeedScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('You\'re all caught up'), 300);
    expect(find.text('You\'re all caught up'), findsOneWidget);
  });
}

class _FixedFeed extends FeedController {
  _FixedFeed(this.posts, {this.hasMore = false});

  final List<Post> posts;
  final bool hasMore;
  int loadMoreCalls = 0;

  @override
  Future<FeedState> build() async => FeedState(posts: posts, hasMore: hasMore);

  @override
  Future<void> loadMore() async => loadMoreCalls++;
}

class _PagedRepository extends Fake implements FeedRepository {
  _PagedRepository(this.posts);

  final List<Post> posts;
  final befores = <DateTime?>[];

  @override
  Future<List<Post>> fetchFeed({required String? myProfileId, DateTime? before, required int limit}) async {
    befores.add(before);
    return posts.where((p) => before == null || p.createdAt.isBefore(before)).take(limit).toList();
  }
}
