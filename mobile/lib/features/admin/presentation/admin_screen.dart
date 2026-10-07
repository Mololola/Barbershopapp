import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/loading.dart';
import '../../auth/domain/profile.dart';
import '../../business/domain/finance_overview.dart';
import '../../rewards/domain/payout_request.dart';
import '../application/admin_controller.dart';
import '../domain/admin_business_summary.dart';
import '../domain/reviewer.dart';
import 'admin_overview_tab.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [Tab(text: 'Overview'), Tab(text: 'Customers'), Tab(text: 'Businesses'), Tab(text: 'Payouts')],
          ),
        ),
        body: const TabBarView(
          children: [AdminOverviewTab(), _CustomersTab(), _BusinessesTab(), _PayoutsTab()],
        ),
      ),
    );
  }
}

class _CustomersTab extends ConsumerStatefulWidget {
  const _CustomersTab();

  @override
  ConsumerState<_CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends ConsumerState<_CustomersTab> {
  final _queryController = TextEditingController();
  String? _query;
  ({String id, String username})? _selected;
  bool _isQualityReviewer = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  /// An empty search goes back to the suggested/promoted lists.
  void _search() {
    final query = _queryController.text.trim();
    setState(() {
      _query = query.isEmpty ? null : query;
      _selected = null;
    });
  }

  void _select(String id, String username, {required bool isQualityReviewer}) {
    setState(() {
      _selected = (id: id, username: username);
      _isQualityReviewer = isQualityReviewer;
    });
  }

  Future<void> _toggle() async {
    final selected = _selected;
    if (selected == null) return;
    final success = await ref
        .read(adminActionControllerProvider.notifier)
        .setQualityReviewer(selected.id, !_isQualityReviewer);
    if (!mounted) return;
    if (success) setState(() => _isQualityReviewer = !_isQualityReviewer);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final actionState = ref.watch(adminActionControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryController,
                  decoration: const InputDecoration(labelText: 'Search customers by username'),
                  onSubmitted: (_) => _search(),
                ),
              ),
              IconButton(icon: const Icon(Icons.search), onPressed: _search),
            ],
          ),
          const SizedBox(height: 16),
          if (selected == null)
            Expanded(
              child: _query != null
                  ? _SearchResults(
                      query: _query!,
                      onSelect: (profile) =>
                          _select(profile.id, profile.username, isQualityReviewer: profile.isQualityReviewer),
                    )
                  : _ReviewerLists(
                      onSelect: (reviewer, {required isPromoted}) =>
                          _select(reviewer.id, reviewer.username, isQualityReviewer: isPromoted),
                    ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => setState(() => _selected = null),
                      ),
                      Text(selected.username, style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: actionState.isLoading ? null : _toggle,
                    child: Text(
                      _isQualityReviewer ? 'Deactivate \$3 rewards' : 'Activate \$3 rewards',
                    ),
                  ),
                  if (actionState.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        actionState.error.toString(),
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('Review history', style: Theme.of(context).textTheme.titleMedium),
                  Expanded(child: _ReviewHistory(customerId: selected.id)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query, required this.onSelect});

  final String query;
  final ValueChanged<Profile> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(customerSearchProvider(query));
    return results.when(
      loading: () => const LoadingView(),
      error: (error, _) => Text('Error: $error'),
      data: (list) {
        if (list.isEmpty) {
          return const Text('No customers found.');
        }
        return ListView(
          children: [
            for (final profile in list)
              ListTile(
                title: Text(profile.username),
                subtitle: Text(profile.isQualityReviewer ? 'Quality reviewer' : 'Standard'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onSelect(profile),
              ),
          ],
        );
      },
    );
  }
}

/// What the Customers tab shows when you're not searching: who's worth
/// promoting to the quality-reviewer tier, and who already has it (to
/// demote anyone found reviewing dishonestly). Ranking is server-side —
/// see GET /admin/reviewers.
class _ReviewerLists extends ConsumerWidget {
  const _ReviewerLists({required this.onSelect});

  final void Function(Reviewer reviewer, {required bool isPromoted}) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewers = ref.watch(adminReviewersProvider);
    final textTheme = Theme.of(context).textTheme;
    return reviewers.when(
      loading: () => const LoadingView(),
      error: (error, _) => Text('Error: $error'),
      data: (lists) => ListView(
        children: [
          Text('Suggested for promotion', style: textTheme.titleMedium),
          Text(
            'Regulars with 3+ reviews on completed bookings — most reviews first, then most written. '
            'Tap to read their reviews before deciding.',
            style: textTheme.bodySmall,
          ),
          if (lists.suggested.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No one qualifies yet.')),
          for (final reviewer in lists.suggested)
            _ReviewerTile(reviewer: reviewer, onTap: () => onSelect(reviewer, isPromoted: false)),
          const SizedBox(height: 24),
          Text('Promoted (${lists.promoted.length})', style: textTheme.titleMedium),
          Text('On the \$3 tier. Tap to re-read their reviews or demote.', style: textTheme.bodySmall),
          if (lists.promoted.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No one promoted yet.')),
          for (final reviewer in lists.promoted)
            _ReviewerTile(reviewer: reviewer, onTap: () => onSelect(reviewer, isPromoted: true)),
        ],
      ),
    );
  }
}

class _ReviewerTile extends StatelessWidget {
  const _ReviewerTile({required this.reviewer, required this.onTap});

  final Reviewer reviewer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final last = reviewer.lastReviewAt?.toLocal();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('@${reviewer.username}'),
      subtitle: Text(
        '${reviewer.reviews} review${reviewer.reviews == 1 ? '' : 's'} · '
        '~${reviewer.averageCommentLength} characters each'
        '${last == null ? '' : ' · last ${last.day}/${last.month}/${last.year}'}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _ReviewHistory extends ConsumerWidget {
  const _ReviewHistory({required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(customerReviewsProvider(customerId));
    return reviews.when(
      loading: () => const LoadingView(),
      error: (error, _) => Text('Error: $error'),
      data: (list) {
        if (list.isEmpty) {
          return const Text('No reviews yet.');
        }
        return ListView(
          children: [
            for (final review in list)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Shop: ${review.shopRating ?? '—'}  '
                          'Worker: ${review.workerRating ?? '—'}  '
                          'Haircut: ${review.haircutRating ?? '—'}'),
                      if (review.shopComment != null) Text('Shop: ${review.shopComment}'),
                      if (review.workerComment != null) Text('Worker: ${review.workerComment}'),
                      if (review.haircutComment != null) Text('Haircut: ${review.haircutComment}'),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BusinessesTab extends ConsumerWidget {
  const _BusinessesTab();

  Future<void> _grantTrial(BuildContext context, WidgetRef ref, AdminBusinessSummary business) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grant a 1-month trial?'),
        content: Text('${business.name} won\'t be charged for their first month once they subscribe.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Grant trial')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(adminActionControllerProvider.notifier).grantTrial(business.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businesses = ref.watch(adminBusinessesProvider);
    final actionState = ref.watch(adminActionControllerProvider);

    return businesses.when(
      loading: () => const LoadingView(),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No businesses yet.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final business in list)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(business.name, style: Theme.of(context).textTheme.titleMedium),
                      Text('Owner: ${business.ownerUsername}'),
                      Text('Signed up: ${business.createdAt.toLocal().toString().split(' ').first}'),
                      Text('Subscription: ${business.subscriptionStatus ?? 'none yet'}'),
                      const SizedBox(height: 8),
                      if (business.hasActiveTrial)
                        Text(
                          'Trial until ${business.subscriptionTrialEndsAt!.toLocal().toString().split(' ').first}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        )
                      else
                        OutlinedButton(
                          onPressed: actionState.isLoading ? null : () => _grantTrial(context, ref, business),
                          child: const Text('Grant 1-month trial'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PayoutsTab extends ConsumerWidget {
  const _PayoutsTab();

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref,
    PayoutRequest request,
    PayoutRequestStatus status,
  ) async {
    await ref.read(adminActionControllerProvider.notifier).resolvePayoutRequest(
          requestId: request.id,
          status: status,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(adminPayoutRequestsProvider);
    final actionState = ref.watch(adminActionControllerProvider);

    return requests.when(
      loading: () => const LoadingView(),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No payout requests.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final request in list)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${request.requesterUsername ?? request.profileId} — '
                        '${formatMoney(request.amountCents, request.currency)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (request.iban != null)
                        SelectableText('Pay to: ${request.accountHolder}\nIBAN: ${request.iban}'),
                      Text('Requested: ${request.requestedAt.toLocal().toString().split('.').first}'),
                      Text('Status: ${request.status.wireValue}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (request.status == PayoutRequestStatus.pending) ...[
                            OutlinedButton(
                              onPressed: actionState.isLoading
                                  ? null
                                  : () => _resolve(context, ref, request, PayoutRequestStatus.rejected),
                              child: const Text('Reject'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: actionState.isLoading
                                  ? null
                                  : () => _resolve(context, ref, request, PayoutRequestStatus.approved),
                              child: const Text('Approve'),
                            ),
                          ] else if (request.status == PayoutRequestStatus.approved)
                            FilledButton(
                              onPressed: actionState.isLoading
                                  ? null
                                  : () => _resolve(context, ref, request, PayoutRequestStatus.paid),
                              child: const Text('Mark paid — I\'ve sent the money'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
