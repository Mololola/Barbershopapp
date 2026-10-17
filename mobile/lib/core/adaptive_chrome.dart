import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/domain/profile.dart';
import '../features/business/application/business_controller.dart';
import '../features/messaging/application/messaging_controller.dart';
import 'responsive.dart';
import 'router.dart';
import 'theme.dart';

const _authPaths = {'/sign-in', '/sign-up', '/forgot-password', '/reset-password', '/two-factor', '/get-the-app'};

/// The desktop frame around every screen on a wide window — the website,
/// or a tablet held sideways: a sidebar for navigation, page content kept
/// to a readable width, and a split-screen frame for signing in. Below
/// [wideLayoutWidth] it steps aside and the phone layout is unchanged.
class AdaptiveChrome extends ConsumerWidget {
  const AdaptiveChrome({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isWideLayout(context)) return child;
    final router = ref.watch(routerProvider);
    final profile = ref.watch(currentProfileProvider).value;
    return Theme(
      data: _desktopTheme(Theme.of(context)),
      child: ListenableBuilder(
        listenable: router.routerDelegate,
        builder: (context, _) {
          final path = router.routerDelegate.currentConfiguration.uri.path;
          if (_authPaths.contains(path) || profile == null) return _AuthFrame(child: child);
          if (path == '/business-setup') return _CenteredPage(maxWidth: 760, child: child);
          return Material(
            color: AppColors.chalk,
            child: Row(
              children: [
                _Sidebar(path: path, router: router, profile: profile),
                Expanded(child: _CenteredPage(maxWidth: _contentWidthFor(path), child: child)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Dashboards use the whole window; reading and forms stay at a
/// comfortable line length, the way most desktop products lay out pages.
double _contentWidthFor(String path) {
  const dashboards = {'/business', '/business/finance', '/admin', '/customer'};
  if (dashboards.contains(path)) return 1320;
  const wide = [
    '/messages',
    '/feed',
    '/business/feed',
    '/business/staff',
    '/business/browse-workers',
    '/profile',
    '/posts',
    '/customer/businesses',
    '/rankings',
  ];
  if (wide.any((prefix) => path == prefix || path.startsWith('$prefix/'))) return 960;
  return 760;
}

/// A light page header in place of the phone's dark app bar: on a desktop
/// the dark band is the sidebar, and pages read as content beside it.
ThemeData _desktopTheme(ThemeData base) {
  return base.copyWith(
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: AppColors.chalk,
      foregroundColor: AppColors.charcoal,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      toolbarHeight: 72,
      titleSpacing: 24,
      titleTextStyle: GoogleFonts.bigShouldersDisplay(
        fontWeight: FontWeight.w800,
        fontSize: 30,
        color: AppColors.charcoal,
        letterSpacing: 0.3,
      ),
    ),
    tabBarTheme: base.tabBarTheme.copyWith(
      labelColor: AppColors.charcoal,
      unselectedLabelColor: AppColors.steel,
      indicatorColor: AppColors.brass,
      dividerColor: AppColors.divider,
    ),
  );
}

class _CenteredPage extends StatelessWidget {
  const _CenteredPage({required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.chalk,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      ),
    );
  }
}

/// Signing in on a desktop: the brand on the left, the form on the right.
class _AuthFrame extends StatelessWidget {
  const _AuthFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Material(
      color: AppColors.chalk,
      child: Row(
        children: [
          if (size.width >= 1100) const Expanded(flex: 5, child: _BrandPanel()),
          Expanded(
            flex: 6,
            child: Padding(
              padding: EdgeInsets.only(top: math.min(96, size.height * 0.08)),
              child: _CenteredPage(maxWidth: 480, child: child),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const points = [
      (Icons.event_outlined, 'Bookings and staff schedules at a glance'),
      (Icons.payments_outlined, 'Costs, break-even and forecasts on a big screen'),
      (Icons.storefront_outlined, 'Your shop page, posts and messages'),
    ];
    return ColoredBox(
      color: AppColors.charcoal,
      child: Padding(
        padding: const EdgeInsets.all(56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Wordmark(subtitle: 'for Business'),
            const Spacer(),
            Container(width: 48, height: 3, color: AppColors.brass),
            const SizedBox(height: 24),
            Text(
              'Run your shop\nfrom any screen.',
              style: textTheme.displayMedium?.copyWith(color: AppColors.chalk, height: 1.05),
            ),
            const SizedBox(height: 20),
            Text(
              'Everything in the app, with room to see it.',
              style: textTheme.titleMedium?.copyWith(color: AppColors.chalk.withValues(alpha: 0.75)),
            ),
            const SizedBox(height: 32),
            for (final (icon, text) in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Icon(icon, color: AppColors.brass, size: 22),
                    const SizedBox(width: 14),
                    Text(text, style: textTheme.bodyLarge?.copyWith(color: AppColors.chalk)),
                  ],
                ),
              ),
            const Spacer(),
            Text(
              'Customers book on the Fadra Cut app.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.chalk.withValues(alpha: 0.55)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final mark = ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Image.asset('assets/branding/icon.png', width: 40, height: 40),
    );
    return Row(
      children: [
        mark,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FADRA CUT',
                style: GoogleFonts.bigShouldersDisplay(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  height: 1,
                  letterSpacing: 1.2,
                  color: AppColors.chalk,
                ),
              ),
              Text(subtitle, style: const TextStyle(color: AppColors.brass, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

typedef _Destination = ({IconData icon, String label, String path, int badge});

/// Which destination a location belongs to: its own path, or a page nested
/// under it (a staff member's schedule belongs to Staff). Home is only home.
bool _isSelected(String destination, String path) {
  if (path == destination) return true;
  if (destination == '/business' || destination == '/customer') return false;
  if (destination == '/business/staff' && path.startsWith('/business/browse-workers')) return true;
  return path.startsWith('$destination/');
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.path, required this.router, required this.profile});

  final String path;
  final GoRouter router;
  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBusiness = profile.role == AccountRole.business;
    // Minors have no messages (see MessagesButton).
    final unread = profile.isMinor
        ? 0
        : (ref.watch(conversationsProvider).value ?? const []).where((c) => c.unreadCount > 0).length;
    final shopName = isBusiness ? ref.watch(currentBusinessProvider).value?.name : null;

    final List<_Destination> main;
    final List<_Destination> footer;
    if (isBusiness) {
      main = [
        (icon: Icons.space_dashboard_outlined, label: 'Home', path: '/business', badge: 0),
        (icon: Icons.event_outlined, label: 'Bookings', path: '/business/bookings', badge: 0),
        (icon: Icons.groups_outlined, label: 'Staff', path: '/business/staff', badge: 0),
        (icon: Icons.content_cut, label: 'Services', path: '/business/services', badge: 0),
        (icon: Icons.payments_outlined, label: 'Finance', path: '/business/finance', badge: 0),
        (icon: Icons.photo_outlined, label: 'Feed', path: '/business/feed', badge: 0),
        (icon: Icons.mode_comment_outlined, label: 'Messages', path: '/messages', badge: unread),
        (icon: Icons.storefront_outlined, label: 'Shop page', path: '/business/shop/edit', badge: 0),
        (icon: Icons.person_outline, label: 'Profile', path: '/business/profile', badge: 0),
      ];
      footer = [(icon: Icons.credit_card, label: 'Subscription', path: '/business/subscription', badge: 0)];
    } else if (kIsWeb) {
      // Only admins reach the website with a customer account.
      main = [(icon: Icons.admin_panel_settings_outlined, label: 'Admin', path: '/admin', badge: 0)];
      footer = [];
    } else {
      main = [
        (icon: Icons.home_outlined, label: 'Home', path: '/customer', badge: 0),
        (icon: Icons.storefront_outlined, label: 'Browse', path: '/customer/businesses', badge: 0),
        (icon: Icons.photo_outlined, label: 'Feed', path: '/feed', badge: 0),
        (icon: Icons.content_cut_outlined, label: 'Designs', path: '/designs', badge: 0),
        if (!profile.isMinor) (icon: Icons.mode_comment_outlined, label: 'Messages', path: '/messages', badge: unread),
        (icon: Icons.paid_outlined, label: 'Rewards', path: '/rewards', badge: 0),
        (icon: Icons.leaderboard_outlined, label: 'Rankings', path: '/rankings', badge: 0),
        (icon: Icons.person_outline, label: 'Profile', path: '/customer/profile', badge: 0),
      ];
      footer = [];
    }

    Widget item(_Destination d) =>
        _SidebarItem(destination: d, selected: _isSelected(d.path, path), onTap: () => router.go(d.path));

    return Container(
      width: 248,
      color: AppColors.charcoal,
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _Wordmark(subtitle: isBusiness ? 'for Business' : (kIsWeb ? 'Admin' : 'Barbershop')),
              ),
              if (shopName != null) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.chalk.withValues(alpha: 0.6), fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(child: ListView(children: [for (final d in main) item(d)])),
              const Divider(color: Color(0x33EDEAE3), height: 24),
              for (final d in footer) item(d),
              item((icon: Icons.settings_outlined, label: 'Settings', path: '/account-settings', badge: 0)),
              if (profile.isAdmin && (isBusiness || !kIsWeb))
                item((icon: Icons.admin_panel_settings_outlined, label: 'Admin', path: '/admin', badge: 0)),
              _SidebarItem(
                destination: (icon: Icons.logout, label: 'Sign out', path: '', badge: 0),
                selected: false,
                onTap: () => ref.read(authControllerProvider.notifier).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.destination, required this.selected, required this.onTap});

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brass : AppColors.chalk.withValues(alpha: 0.72);
    final icon = Badge(
      isLabelVisible: destination.badge > 0,
      backgroundColor: AppColors.rust,
      label: Text(destination.badge > 9 ? '9+' : '${destination.badge}'),
      child: Icon(destination.icon, color: color, size: 22),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(
        selected: selected,
        button: true,
        label: destination.label,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            hoverColor: AppColors.chalk.withValues(alpha: 0.06),
            focusColor: AppColors.chalk.withValues(alpha: 0.1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: selected ? AppColors.brass.withValues(alpha: 0.16) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  icon,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      destination.label,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: selected ? AppColors.chalk : AppColors.chalk.withValues(alpha: 0.82),
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
