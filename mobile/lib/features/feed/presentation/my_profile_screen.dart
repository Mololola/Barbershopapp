import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import 'profile_screen.dart';

/// The bottom-nav "Profile" tab needs a fixed route with no path parameter
/// (a NavigationDestination just calls goBranch(index), it can't supply a
/// :profileId), so this resolves the signed-in user's own id and renders
/// the same ProfileScreen everyone else's profile uses.
class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myProfile = ref.watch(currentProfileProvider).value;
    if (myProfile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ProfileScreen(profileId: myProfile.id);
  }
}
