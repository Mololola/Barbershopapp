import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/loading.dart';
import '../../auth/domain/profile.dart';
import '../application/admin_controller.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _queryController = TextEditingController();
  String? _query;
  Profile? _selected;
  bool _isQualityReviewer = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _search() {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _query = query;
      _selected = null;
    });
  }

  void _select(Profile profile) {
    setState(() {
      _selected = profile;
      _isQualityReviewer = profile.isQualityReviewer;
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

    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: Padding(
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
            if (selected == null) ...[
              if (_query != null) Expanded(child: _SearchResults(query: _query!, onSelect: _select)),
            ] else
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
                    const SizedBox(height: 16),
                    Text('Review history', style: Theme.of(context).textTheme.titleMedium),
                    Expanded(child: _ReviewHistory(customerId: selected.id)),
                  ],
                ),
              ),
          ],
        ),
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
