import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/rankings_controller.dart';
import '../domain/ranking_entry.dart';
import '../domain/ranking_window.dart';

enum _RankingType { distinctShops, totalHaircuts, referrals, haircutTypes }

extension on _RankingType {
  String get label {
    switch (this) {
      case _RankingType.distinctShops:
        return 'Most shops visited';
      case _RankingType.totalHaircuts:
        return 'Most haircuts';
      case _RankingType.referrals:
        return 'Top referrers';
      case _RankingType.haircutTypes:
        return 'Popular haircuts';
    }
  }
}

class RankingsScreen extends ConsumerStatefulWidget {
  const RankingsScreen({super.key});

  @override
  ConsumerState<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends ConsumerState<RankingsScreen> {
  _RankingType _type = _RankingType.distinctShops;
  RankingWindow _window = RankingWindow.week;

  /// Riverpod only refetches a ranking when something invalidates it —
  /// nothing elsewhere in the app knows to do that when e.g. a new business
  /// signs up with your referral code, so without this the screen can keep
  /// showing whatever it last fetched.
  Future<void> _refresh() async {
    switch (_type) {
      case _RankingType.distinctShops:
        ref.invalidate(distinctShopsRankingProvider(_window));
        await ref.read(distinctShopsRankingProvider(_window).future);
      case _RankingType.totalHaircuts:
        ref.invalidate(totalHaircutsRankingProvider(_window));
        await ref.read(totalHaircutsRankingProvider(_window).future);
      case _RankingType.referrals:
        ref.invalidate(referralsRankingProvider);
        await ref.read(referralsRankingProvider.future);
      case _RankingType.haircutTypes:
        ref.invalidate(haircutTypesRankingProvider(_window));
        await ref.read(haircutTypesRankingProvider(_window).future);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rankings'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<_RankingType>(
              value: _type,
              isExpanded: true,
              items: [
                for (final type in _RankingType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: (value) => setState(() => _type = value!),
            ),
            if (_type != _RankingType.referrals) ...[
              const SizedBox(height: 8),
              DropdownButton<RankingWindow>(
                value: _window,
                isExpanded: true,
                items: [
                  for (final window in RankingWindow.values)
                    DropdownMenuItem(value: window, child: Text(window.label)),
                ],
                onChanged: (value) => setState(() => _window = value!),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(child: _buildRanking(context, ref)),
          ],
        ),
      ),
    );
  }

  Widget _buildRanking(BuildContext context, WidgetRef ref) {
    switch (_type) {
      case _RankingType.distinctShops:
        return _CustomerRankingList(
          ranking: ref.watch(distinctShopsRankingProvider(_window)),
          valueLabel: 'shops',
        );
      case _RankingType.totalHaircuts:
        return _CustomerRankingList(
          ranking: ref.watch(totalHaircutsRankingProvider(_window)),
          valueLabel: 'haircuts',
        );
      case _RankingType.referrals:
        return _CustomerRankingList(
          ranking: ref.watch(referralsRankingProvider),
          valueLabel: 'businesses referred',
        );
      case _RankingType.haircutTypes:
        return _HaircutTypeRankingList(window: _window);
    }
  }
}

class _CustomerRankingList extends StatelessWidget {
  const _CustomerRankingList({required this.ranking, required this.valueLabel});

  final AsyncValue<List<CustomerRankingEntry>> ranking;
  final String valueLabel;

  @override
  Widget build(BuildContext context) {
    return ranking.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(child: Text('No data yet.'));
        }
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: entry.avatarUrl != null ? NetworkImage(entry.avatarUrl!) : null,
                child: entry.avatarUrl == null ? Text('${index + 1}') : null,
              ),
              title: Text(entry.username),
              trailing: Text('${entry.value} $valueLabel'),
            );
          },
        );
      },
    );
  }
}

class _HaircutTypeRankingList extends ConsumerWidget {
  const _HaircutTypeRankingList({required this.window});

  final RankingWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranking = ref.watch(haircutTypesRankingProvider(window));
    return ranking.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(child: Text('No data yet.'));
        }
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return ListTile(
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(entry.haircutType),
              trailing: Text('${entry.value}'),
            );
          },
        );
      },
    );
  }
}
