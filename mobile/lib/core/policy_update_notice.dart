import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/auth/application/auth_controller.dart';
import 'l10n.dart';
import 'legal.dart';

const _seenKey = 'policies_seen_effective';


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
        title: Text(context.l10n.policyUpdateTitle),
        content: Text(context.l10n.policyUpdateBody(policiesEffective)),
        actions: [
          TextButton(
            onPressed: () => launchUrl(Uri.parse(termsOfServiceUrl), mode: LaunchMode.externalApplication),
            child: Text(context.l10n.termsShort),
          ),
          TextButton(
            onPressed: () => launchUrl(Uri.parse(privacyPolicyUrl), mode: LaunchMode.externalApplication),
            child: Text(context.l10n.privacyPolicy),
          ),
          FilledButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.ok)),
        ],
      ),
    );
    await prefs.setString(_seenKey, version);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
