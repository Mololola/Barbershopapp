import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/auth/application/auth_controller.dart';
import 'legal.dart';

const _seenKey = 'policies_seen_effective';

const _monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September',
  'October', 'November', 'December'];

/// Tells a signed-in user, once, that the Terms and Privacy Policy have
/// changed — the documents promise this before material changes take
/// effect. Accounts that signed up under the current version, and users
/// who already dismissed it on this device, never see it.
class PolicyUpdateNotice extends ConsumerStatefulWidget {
  const PolicyUpdateNotice({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PolicyUpdateNotice> createState() => _PolicyUpdateNoticeState();
}

class _PolicyUpdateNoticeState extends ConsumerState<PolicyUpdateNotice> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showIfNeeded());
  }

  Future<void> _showIfNeeded() async {
    final profile = await ref.read(currentProfileProvider.future);
    final acceptedAt = profile?.termsAcceptedAt;
    if (profile == null || (acceptedAt != null && !acceptedAt.isBefore(policiesEffective))) return;
    final prefs = await SharedPreferences.getInstance();
    final version = policiesEffective.toIso8601String();
    if (prefs.getString(_seenKey) == version || !mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('We\'ve updated our Terms and Privacy Policy'),
        content: Text(
          'In effect from ${policiesEffective.day} ${_monthNames[policiesEffective.month - 1]} '
          '${policiesEffective.year}. $policyChangeSummary By continuing to use the app you accept the updated '
          'versions.',
        ),
        actions: [
          TextButton(
            onPressed: () => launchUrl(Uri.parse(termsOfServiceUrl), mode: LaunchMode.externalApplication),
            child: const Text('Terms'),
          ),
          TextButton(
            onPressed: () => launchUrl(Uri.parse(privacyPolicyUrl), mode: LaunchMode.externalApplication),
            child: const Text('Privacy Policy'),
          ),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
    await prefs.setString(_seenKey, version);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
