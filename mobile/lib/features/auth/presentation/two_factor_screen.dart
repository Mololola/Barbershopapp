import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../../../core/theme.dart';
import '../application/auth_controller.dart';

/// The second sign-in step every admin account must pass (the database and
/// the backend refuse admin access without it): set up an authenticator
/// app once, then enter its 6-digit code each time you sign in. Verifying
/// raises the session to 'aal2' and the router moves on by itself.
class TwoFactorScreen extends ConsumerStatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  ConsumerState<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends ConsumerState<TwoFactorScreen> {
  final _code = TextEditingController();
  String? _factorId;
  TOTPEnrollment? _enrollment;
  String? _error;
  bool _busy = false;

  GoTrueClient get _auth => ref.read(supabaseClientProvider).auth;

  @override
  void initState() {
    super.initState();
    final enrolled = _factors.where((f) => f.factorType == FactorType.totp && f.status == FactorStatus.verified);
    if (enrolled.isNotEmpty) {
      _factorId = enrolled.first.id;
    } else {
      // After initState: _enroll updates the state as it goes.
      Future.microtask(_enroll);
    }
  }

  List<Factor> get _factors => _auth.currentUser?.factors ?? const <Factor>[];

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _enroll() async {
    setState(() => _busy = true);
    try {
      // A setup abandoned half-way leaves an unverified factor behind, which
      // would block starting a new one.
      for (final factor in _factors.where((f) => f.status == FactorStatus.unverified)) {
        await _auth.mfa.unenroll(factor.id);
      }
      final enrolled = await _auth.mfa.enroll(issuer: 'Barbershop', friendlyName: 'Authenticator app');
      setState(() {
        _factorId = enrolled.id;
        _enrollment = enrolled.totp;
      });
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Couldn\'t start the set-up. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your authenticator app.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.mfa.challengeAndVerify(factorId: _factorId!, code: code);
    } on AuthException {
      if (mounted) setState(() => _error = 'That code didn\'t work. Codes change every 30 seconds — try the current one.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Couldn\'t check the code. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final enrollment = _enrollment;

    return Scaffold(
      appBar: AppBar(title: const Text('Two-step sign-in'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            enrollment == null
                ? 'Enter the 6-digit code from your authenticator app.'
                : 'Admin accounts need a second step to sign in, so a leaked password alone can\'t reach '
                    'businesses, payouts or bank details.',
            style: textTheme.bodyLarge,
          ),
          if (enrollment != null) ...[
            const SizedBox(height: 20),
            Text('1. Install an authenticator app', style: textTheme.titleMedium),
            const Text('Google Authenticator, Microsoft Authenticator, 1Password or similar.'),
            const SizedBox(height: 16),
            Text('2. Scan this code with it', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Center(
              child: QrImageView(data: enrollment.uri, size: 200, backgroundColor: Colors.white),
            ),
            const SizedBox(height: 8),
            Text('Can\'t scan it? Enter this key instead:', style: textTheme.bodySmall),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    enrollment.secret,
                    style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1.2),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy key',
                  icon: const Icon(Icons.copy),
                  onPressed: () => Clipboard.setData(ClipboardData(text: enrollment.secret)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('3. Enter the code it shows', style: textTheme.titleMedium),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            autofocus: true,
            enabled: _factorId != null,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            style: const TextStyle(fontSize: 22, letterSpacing: 8),
            decoration: const InputDecoration(labelText: '6-digit code'),
            onSubmitted: (_) => _verify(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: AppColors.rust)),
            ),
          const SizedBox(height: 20),
          if (_factorId == null && !_busy)
            OutlinedButton(onPressed: _enroll, child: const Text('Try again'))
          else
            FilledButton(
              onPressed: _busy ? null : _verify,
              child: _busy
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Verify'),
            ),
          TextButton(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
