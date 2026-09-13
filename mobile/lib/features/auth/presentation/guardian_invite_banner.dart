import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../application/auth_controller.dart';
import '../domain/guardian_link.dart';

/// Shown on a home screen wherever someone might sign in specifically to
/// confirm a guardian invite — the actual verifiable-consent step (see the
/// 832ca4a41b29 migration). One banner per pending invite; in practice
/// there's almost always just one.
class GuardianInviteBanner extends ConsumerWidget {
  const GuardianInviteBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(pendingGuardianInvitesProvider).value ?? const [];
    if (invites.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          for (final invite in invites) ...[
            _GuardianInviteCard(invite: invite),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _GuardianInviteCard extends ConsumerWidget {
  const _GuardianInviteCard({required this.invite});

  final GuardianLink invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guardianState = ref.watch(guardianControllerProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.rust.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('A minor has invited you as their guardian', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text(
            'By confirming, you state that you are the parent or legal guardian of this account holder '
            'and consent to their use of Barbershop App under your supervision.',
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: guardianState.isLoading
                ? null
                : () => ref.read(guardianControllerProvider.notifier).confirm(invite),
            child: guardianState.isLoading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Confirm — I am their guardian'),
          ),
        ],
      ),
    );
  }
}
