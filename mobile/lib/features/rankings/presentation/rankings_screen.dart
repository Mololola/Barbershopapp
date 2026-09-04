import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/loading.dart';
import '../../../core/theme.dart';
import '../application/rankings_controller.dart';
import '../domain/ranking_entry.dart';
import '../domain/ranking_window.dart';

enum _RankingType { distinctShops, totalHaircuts, referrals, haircutTypes, topBarbers }

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
      case _RankingType.topBarbers:
        return 'Top-rated barbers';
    }
  }
}

/// 1st/2nd/3rd get the app's own stand-ins for gold/silver/bronze — brass,
/// steel, rust — rather than introducing literal medal colors that exist
/// nowhere else in the palette.
const _medalColors = [AppColors.brass, AppColors.steel, AppColors.rust];

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
      case _RankingType.topBarbers:
        ref.invalidate(topBarbersRankingProvider);
        await ref.read(topBarbersRankingProvider.future);
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in _RankingType.values)
                  ChoiceChip(
                    label: Text(type.label),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                  ),
              ],
            ),
          ),
          if (_type != _RankingType.referrals && _type != _RankingType.topBarbers)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final window in RankingWindow.values)
                    ChoiceChip(
                      label: Text(window.label),
                      selected: _window == window,
                      onSelected: (_) => setState(() => _window = window),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Expanded(child: _buildRanking(context, ref)),
        ],
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
      case _RankingType.topBarbers:
        return _BarberRankingList(ranking: ref.watch(topBarbersRankingProvider));
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
      loading: () => const LoadingView(),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(child: Text('No data yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          itemCount: entries.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _LeaderboardTile(
              rank: index + 1,
              avatarUrl: entry.avatarUrl,
              title: entry.username,
              value: '${entry.value} $valueLabel',
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
      loading: () => const LoadingView(),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(child: Text('No data yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          itemCount: entries.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _LeaderboardTile(
              rank: index + 1,
              icon: Icons.content_cut,
              title: entry.haircutType,
              value: '${entry.value}',
            );
          },
        );
      },
    );
  }
}

class _BarberRankingList extends StatelessWidget {
  const _BarberRankingList({required this.ranking});

  final AsyncValue<List<BarberRankingEntry>> ranking;

  @override
  Widget build(BuildContext context) {
    return ranking.when(
      loading: () => const LoadingView(),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(child: Text('No rated barbers yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          itemCount: entries.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _LeaderboardTile(
              rank: index + 1,
              avatarUrl: entry.avatarUrl,
              title: entry.username,
              value: '★ ${entry.value.toStringAsFixed(1)}',
            );
          },
        );
      },
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({
    required this.rank,
    required this.title,
    required this.value,
    this.avatarUrl,
    this.icon,
  });

  final int rank;
  final String title;
  final String value;
  final String? avatarUrl;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final medalColor = rank <= 3 ? _medalColors[rank - 1] : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: medalColor ?? AppColors.divider, width: medalColor != null ? 1.5 : 0.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: rank <= 3 ? 16 : 14,
                color: medalColor ?? AppColors.steel,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 20,
            backgroundColor: (medalColor ?? AppColors.brass).withValues(alpha: 0.15),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Icon(icon ?? Icons.person, color: medalColor ?? AppColors.brass, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          ),
          Text(value, style: const TextStyle(color: AppColors.steel, fontSize: 13)),
        ],
      ),
    );
  }
}
