import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/loading.dart';
import '../../../core/status_message.dart';
import '../../auth/application/auth_controller.dart';
import '../../business/domain/brand.dart';
import '../../customer/domain/review.dart';
import '../application/rankings_controller.dart';
import '../domain/ranking_window.dart';

enum _RankingType { distinctShops, totalHaircuts, referrals, haircutTypes, topBarbers }

extension on _RankingType {
  String label(AppLocalizations l10n) => switch (this) {
        _RankingType.distinctShops => l10n.rankShopsVisited,
        _RankingType.totalHaircuts => l10n.rankMostHaircuts,
        _RankingType.referrals => l10n.rankTopReferrers,
        _RankingType.haircutTypes => l10n.rankPopularHaircuts,
        _RankingType.topBarbers => l10n.rankTopBarbers,
      };

  IconData get icon {
    switch (this) {
      case _RankingType.distinctShops:
        return Icons.storefront_outlined;
      case _RankingType.totalHaircuts:
        return Icons.content_cut;
      case _RankingType.referrals:
        return Icons.group_add_outlined;
      case _RankingType.haircutTypes:
        return Icons.style_outlined;
      case _RankingType.topBarbers:
        return Icons.star_outline;
    }
  }

  /// Referrals and barber ratings are all-time only.
  bool get hasWindow => this != _RankingType.referrals && this != _RankingType.topBarbers;
}

/// One leaderboard line, whatever is being ranked.
class _Row {
  const _Row({
    required this.id,
    required this.title,
    required this.value,
    required this.unit,
    this.avatarUrl,
    this.isPerson = true,
  });

  final String id;
  final String title;
  final String value;
  final String unit;
  final String? avatarUrl;

  /// False for haircut styles, which get the category icon instead of initials.
  final bool isPerson;
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
      case _RankingType.topBarbers:
        ref.invalidate(topBarbersRankingProvider);
        await ref.read(topBarbersRankingProvider.future);
    }
  }

  AsyncValue<List<_Row>> _rows() {
    switch (_type) {
      case _RankingType.distinctShops:
        return ref.watch(distinctShopsRankingProvider(_window)).whenData(
              (entries) => [
                for (final e in entries)
                  _Row(
                    id: e.customerId,
                    title: e.username,
                    avatarUrl: e.avatarUrl,
                    value: '${e.value}',
                    unit: context.l10n.unitShops(e.value),
                  ),
              ],
            );
      case _RankingType.totalHaircuts:
        return ref.watch(totalHaircutsRankingProvider(_window)).whenData(
              (entries) => [
                for (final e in entries)
                  _Row(
                    id: e.customerId,
                    title: e.username,
                    avatarUrl: e.avatarUrl,
                    value: '${e.value}',
                    unit: context.l10n.unitHaircuts(e.value),
                  ),
              ],
            );
      case _RankingType.referrals:
        return ref.watch(referralsRankingProvider).whenData(
              (entries) => [
                for (final e in entries)
                  _Row(
                    id: e.customerId,
                    title: e.username,
                    avatarUrl: e.avatarUrl,
                    value: '${e.value}',
                    unit: context.l10n.unitBusinessesReferred(e.value),
                  ),
              ],
            );
      case _RankingType.haircutTypes:
        return ref.watch(haircutTypesRankingProvider(_window)).whenData(
              (entries) => [
                for (final e in entries)
                  _Row(
                    id: e.haircutType,
                    title: haircutTypeLabel(context.l10n, e.haircutType),
                    value: '${e.value}',
                    unit: context.l10n.unitCuts(e.value),
                    isPerson: false,
                  ),
              ],
            );
      case _RankingType.topBarbers:
        return ref.watch(topBarbersRankingProvider).whenData(
              (entries) => [
                for (final e in entries)
                  _Row(
                    id: e.workerProfileId,
                    title: e.username,
                    avatarUrl: e.avatarUrl,
                    value: e.value.toStringAsFixed(1),
                    unit: '★',
                  ),
              ],
            );
    }
  }

  StatusMessage get _empty {
    switch (_type) {
      case _RankingType.referrals:
        return StatusMessage(
          icon: Icons.group_add_outlined,
          title: context.l10n.noReferralsYet,
          message: context.l10n.noReferralsHint,
        );
      case _RankingType.topBarbers:
        return StatusMessage(
          icon: Icons.star_outline,
          title: context.l10n.noRatedBarbers,
          message: context.l10n.noRatedBarbersHint,
        );
      case _RankingType.haircutTypes:
        return StatusMessage(
          icon: Icons.style_outlined,
          title: context.l10n.noHaircutsInWindow(_window.name),
          message: context.l10n.popularStylesHint,
        );
      case _RankingType.distinctShops:
      case _RankingType.totalHaircuts:
        return StatusMessage(
          icon: Icons.emoji_events_outlined,
          title: context.l10n.boardEmpty,
          message: context.l10n.boardEmptyHint(_window.name),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(currentProfileProvider).value?.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.navRankings),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: context.l10n.refresh, onPressed: _refresh),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _RankingType.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final type = _RankingType.values[i];
                return _TypePill(type: type, selected: type == _type, onTap: () => setState(() => _type = type));
              },
            ),
          ),
          if (_type.hasWindow)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _WindowSwitch(selected: _window, onChanged: (window) => setState(() => _window = window)),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _rows().when(
              loading: () => LoadingView(caption: context.l10n.tallyingBoard),
              error: (_, _) => Center(
                child: StatusMessage(
                  icon: Icons.wifi_off_rounded,
                  title: context.l10n.couldntLoadRankings,
                  message: context.l10n.checkConnection,
                  actionLabel: context.l10n.tryAgain,
                  onAction: _refresh,
                  isError: true,
                ),
              ),
              data: (rows) => RefreshIndicator(
                onRefresh: _refresh,
                child: rows.isEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(height: constraints.maxHeight, child: Center(child: _empty)),
                        ),
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          _Podium(rows: rows.take(3).toList(), myId: myId, icon: _type.icon),
                          if (rows.length > 3) ...[
                            const SizedBox(height: 16),
                            _RestOfBoard(rows: rows.skip(3).toList(), myId: myId, icon: _type.icon),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.type, required this.selected, required this.onTap});

  final _RankingType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected ? scheme.onPrimary : scheme.onSurface;
    return Material(
      color: selected ? scheme.primary : scheme.surface,
      shape: StadiumBorder(side: BorderSide(color: selected ? scheme.primary : scheme.outline)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(type.icon, size: 18, color: selected ? foreground : scheme.primary),
              const SizedBox(width: 8),
              Text(
                type.label(context.l10n),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Week / month / year / all time as one compact switch rather than four
/// loose chips.
class _WindowSwitch extends StatelessWidget {
  const _WindowSwitch({required this.selected, required this.onChanged});

  final RankingWindow selected;
  final ValueChanged<RankingWindow> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(color: scheme.surface, shape: StadiumBorder(side: BorderSide(color: scheme.outline))),
      child: Row(
        children: [
          for (final window in RankingWindow.values)
            Expanded(
              child: Material(
                color: window == selected ? scheme.onSurface : Colors.transparent,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onChanged(window),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      window.label(context.l10n),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: window == selected ? scheme.surface : scheme.onSurface.withValues(alpha: 0.65),
                        fontWeight: window == selected ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 1st/2nd/3rd in the theme's own brass, a muted ink and rust — no literal
/// medal colours that exist nowhere else in the palette.
List<Color> _medalColors(ColorScheme scheme) =>
    [scheme.primary, scheme.onSurface.withValues(alpha: 0.55), scheme.secondary];

class _Avatar extends StatelessWidget {
  const _Avatar({required this.row, required this.radius, required this.color, required this.icon});

  final _Row row;
  final double radius;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final url = row.avatarUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      foregroundColor: color,
      backgroundImage: url != null ? NetworkImage(url) : null,
      child: url != null ? null : (row.isPerson ? Text(initialsOf(row.title)) : Icon(icon, size: radius)),
    );
  }
}

/// The top three on steps, winner in the middle.
class _Podium extends StatelessWidget {
  const _Podium({required this.rows, required this.myId, required this.icon});

  final List<_Row> rows;
  final String? myId;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    // Left to right: 2nd, 1st, 3rd.
    const order = [1, 0, 2];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final place in order)
          Expanded(
            child: place < rows.length
                ? _PodiumPlace(row: rows[place], place: place, isMe: rows[place].id == myId, icon: icon)
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  const _PodiumPlace({required this.row, required this.place, required this.isMe, required this.icon});

  static const _stepHeights = [88.0, 64.0, 48.0];

  final _Row row;
  final int place;
  final bool isMe;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _medalColors(scheme)[place];
    final cardShape = theme.cardTheme.shape;
    final radius = cardShape is RoundedRectangleBorder ? cardShape.borderRadius : BorderRadius.zero;
    final winner = place == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          if (winner) Icon(Icons.emoji_events, color: color, size: 24),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
            child: _Avatar(row: row, radius: winner ? 36 : 28, color: color, icon: icon),
          ),
          const SizedBox(height: 8),
          Text(
            isMe ? context.l10n.you : row.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: row.value, style: theme.textTheme.titleLarge?.copyWith(color: color)),
                TextSpan(
                  text: ' ${row.unit}',
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurface.withValues(alpha: 0.65)),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Container(
            height: _stepHeights[place],
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.only(topLeft: radius.resolve(null).topLeft, topRight: radius.resolve(null).topRight),
              border: Border(top: BorderSide(color: color, width: 2)),
            ),
            child: Text('${place + 1}', style: theme.textTheme.headlineMedium?.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

/// Fourth place down: one card of rows, not a stack of identical cards.
class _RestOfBoard extends StatelessWidget {
  const _RestOfBoard({required this.rows, required this.myId, required this.icon});

  final List<_Row> rows;
  final String? myId;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final secondary = scheme.onSurface.withValues(alpha: 0.65);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 16, endIndent: 16, color: scheme.outline),
            Container(
              color: row.id == myId ? scheme.primary.withValues(alpha: 0.08) : null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${i + 4}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: secondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  _Avatar(row: row, radius: 20, color: scheme.primary, icon: icon),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      row.id == myId ? context.l10n.nameYou(row.title) : row.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: row.value, style: theme.textTheme.titleLarge),
                        TextSpan(text: ' ${row.unit}', style: theme.textTheme.labelSmall?.copyWith(color: secondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
