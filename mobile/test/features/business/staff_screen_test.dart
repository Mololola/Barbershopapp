import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/business/application/business_controller.dart';
import 'package:mobile/features/business/domain/business.dart';
import 'package:mobile/features/business/presentation/staff_screen.dart';
import 'package:mobile/features/business/presentation/worker_candidate_detail_screen.dart';
import 'package:mobile/features/feed/application/feed_controller.dart';
import 'package:mobile/features/worker/domain/worker_invitation.dart';
import 'package:mobile/features/worker/domain/worker_profile.dart';

class _FakeMarketplaceController extends MarketplaceController {
  @override
  Future<List<WorkerSearchResult>> build() async => [_candidate];

  // The real hasMore is only ever updated inside _fetchPage, which this
  // fake bypasses entirely — without this, the base class's private field
  // stays defaulted to true forever, which renders the load-more spinner
  // (an endlessly-repeating animation) and hangs any pumpAndSettle call.
  @override
  bool get hasMore => false;
}

const _candidate = WorkerSearchResult(
  profileId: 'cand-1',
  username: 'mikey',
  legalFirstName: 'Mike',
  legalLastName: 'Smith',
  city: 'Sevilla',
);

void main() {
  const worker = Worker(id: 'w1', businessId: 'biz-1', name: 'Jane Doe');

  Widget buildTestable({List<Worker> staff = const [worker]}) {
    final router = GoRouter(
      initialLocation: '/business/staff',
      routes: [
        GoRoute(path: '/business/staff', builder: (context, state) => const StaffScreen()),
        GoRoute(
          path: '/business/staff/:workerId/schedule',
          builder: (context, state) => const Scaffold(body: Text('Schedule placeholder')),
        ),
        GoRoute(
          path: '/business/browse-workers/:profileId',
          builder: (context, state) =>
              WorkerCandidateDetailScreen(candidate: state.extra as WorkerSearchResult),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        workersProvider.overrideWith((ref) async => staff),
        sentInvitationsProvider.overrideWith((ref) async => <WorkerInvitation>[]),
        pendingLeaveRequestsProvider.overrideWith((ref) async => []),
        marketplaceControllerProvider.overrideWith(_FakeMarketplaceController.new),
        pinnedPostsProvider(_candidate.profileId).overrideWith((ref) async => []),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('"My Workforce" tab shows the current roster', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('Jane Doe'), findsOneWidget);
  });

  testWidgets('"Available Workers" tab shows candidates and navigates to the detail screen', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Available Workers'));
    await tester.pumpAndSettle();

    expect(find.text('Mike Smith'), findsOneWidget);

    await tester.tap(find.text('Mike Smith'));
    await tester.pumpAndSettle();

    expect(find.text('Send invite'), findsOneWidget);
  });

  testWidgets('removing a staff member asks for confirmation first', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remove from staff'));
    await tester.pumpAndSettle();

    expect(find.text('Remove Jane Doe from your staff?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Remove Jane Doe from your staff?'), findsNothing);
    expect(find.text('Jane Doe'), findsOneWidget);
  });

  testWidgets('a candidate already on the staff cannot be invited again', (tester) async {
    await tester.pumpWidget(buildTestable(staff: [
      worker,
      Worker(id: 'w2', businessId: 'biz-1', name: 'Mike Smith', profileId: _candidate.profileId),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Available Workers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mike Smith').last);
    await tester.pumpAndSettle();

    expect(find.text('Already on your staff'), findsOneWidget);
    expect(find.text('Send invite'), findsNothing);
  });
}
