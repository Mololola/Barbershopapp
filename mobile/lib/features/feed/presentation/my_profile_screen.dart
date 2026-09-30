import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/loading.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/profile.dart';
import '../../business/application/business_controller.dart';
import '../../customer/presentation/shop_page.dart';
import 'profile_screen.dart';

/// The bottom-nav "Profile" tab needs a fixed route with no path parameter
/// (a NavigationDestination just calls goBranch(index), it can't supply a
/// :profileId), so this resolves the signed-in user. A customer gets the
/// same ProfileScreen everyone else's profile uses; a business gets its
/// shop page — exactly what customers see — with the owner's controls.
class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myProfile = ref.watch(currentProfileProvider).value;
    if (myProfile == null) {
      return const Scaffold(body: LoadingView());
    }
    if (myProfile.role == AccountRole.business) {
      final business = ref.watch(currentBusinessProvider).value;
      if (business == null) return const Scaffold(body: LoadingView());
      return ShopPage(businessId: business.id, isOwner: true);
    }
    return ProfileScreen(profileId: myProfile.id);
  }
}
