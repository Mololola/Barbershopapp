import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/supabase_providers.dart';
import '../application/auth_controller.dart';
import '../domain/profile.dart';

const _privacyPolicyUrl = 'https://claude.ai/code/artifact/f348e6eb-ffe5-4615-8087-6ab8396295ca';
const _termsOfServiceUrl = 'https://claude.ai/code/artifact/7b0fd848-a548-46c4-9ee1-89d93f7e7b26';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // The website is for shops (customers use the app), so it starts there.
  AccountRole _role = kIsWeb ? AccountRole.business : AccountRole.customer;
  DateTime? _dateOfBirth;
  bool _agreedToTerms = false;
  bool _attestedAdultOwner = false;

  bool get _isBusiness => _role == AccountRole.business;

  bool get _isMinorSelected {
    final dob = _dateOfBirth;
    if (dob == null) return false;
    final today = DateTime.now();
    final eighteenthBirthday = DateTime(dob.year + 18, dob.month, dob.day);
    return eighteenthBirthday.isAfter(today);
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked == null) return;
    // 14 clears both the UK's and Spain's GDPR digital-age-of-consent
    // thresholds (13 / 14) — at or above it a minor can consent for
    // themselves, no parent involved, which is why there's no guardian
    // step anywhere in this flow. See profiles_minimum_age_check.
    final fourteenthBirthday = DateTime(picked.year + 14, picked.month, picked.day);
    if (fourteenthBirthday.isAfter(now)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('You must be at least 14 to create an account.')));
      return;
    }
    setState(() {
      _dateOfBirth = picked;
      // A minor can only ever be a customer — see profiles_minor_role_check.
      if (_isMinorSelected) _role = AccountRole.customer;
    });
  }

  /// True once Google sign-in has already completed and the router
  /// sent us here because there's no `profiles` row yet — see
  /// AuthController.completeOAuthProfile. In that case there's no email or
  /// password to collect, just the role and username a normal signUp()
  /// would have carried as user metadata.
  bool get _isOAuthCompletion => ref.read(currentAuthUserIdProvider) != null;

  @override
  void dispose() {
    _usernameController.dispose();
    _businessNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // A business account records no date of birth — only the owner's
    // attestation, the least personal data that still keeps under-18s out
    // of running a business (profiles_minor_role_check covers the rest).
    final dob = _isBusiness ? null : _dateOfBirth;
    if (!_isBusiness && dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Date of birth is required.')));
      return;
    }
    if (_isBusiness && !_attestedAdultOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Confirm you're 18 or over and authorised to register this business.")));
      return;
    }
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('You must agree to the Terms of Service and Privacy Policy.')));
      return;
    }

    final notifier = ref.read(authControllerProvider.notifier);
    if (_isOAuthCompletion) {
      await notifier.completeOAuthProfile(role: _role, username: _usernameController.text.trim(), dateOfBirth: dob);
      return;
    }

    await notifier.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _role,
      username: _usernameController.text.trim(),
      dateOfBirth: dob,
      businessName: _isBusiness ? _businessNameController.text.trim() : null,
    );

    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state.hasError) return;

    if (Supabase.instance.client.auth.currentSession == null) {
      context.go('/sign-in', extra: 'Check your email to confirm your account, then sign in.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isOAuthCompletion
            ? 'Finish setting up your account'
            : _isBusiness
                ? 'Create business account'
                : 'Create account'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            // Not a ListView: that unmounts off-screen fields, and Form.validate()
            // silently skips unmounted ones.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<AccountRole>(
                  segments: [
                    const ButtonSegment(value: AccountRole.customer, label: Text('Customer')),
                    // A minor can only ever be a customer account — see
                    // profiles_minor_role_check.
                    if (!_isMinorSelected)
                      const ButtonSegment(value: AccountRole.business, label: Text('Business')),
                  ],
                  selected: {_role},
                  onSelectionChanged: (selection) => setState(() => _role = selection.first),
                ),
                if (_isBusiness)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      "Step 1 of 2: your login. After confirming your email you'll set up your business — "
                      'locations, opening hours, services and staff.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                if (_isBusiness && !_isOAuthCompletion) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _businessNameController,
                    decoration: const InputDecoration(labelText: 'Business name'),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                  ),
                ],
                if (!_isBusiness) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickDateOfBirth,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date of birth'),
                      child: Text(
                        _dateOfBirth == null
                            ? 'Select date'
                            : '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                  if (_isMinorSelected)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Under 18 — messaging, posting, and business/worker features aren\'t available on your account.',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: _isBusiness
                      ? const InputDecoration(labelText: 'Business handle', helperText: 'Must be unique — your @name on posts')
                      : const InputDecoration(labelText: 'Username', helperText: 'Must be unique — shown on rankings and posts'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Required';
                    if (value.trim().length < 3) return 'At least 3 characters';
                    return null;
                  },
                ),
                if (!_isOAuthCompletion) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Required';
                      if (!value.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      if (value.length < 6) return 'At least 6 characters';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 8),
                if (_isBusiness)
                  CheckboxListTile(
                    value: _attestedAdultOwner,
                    onChanged: (value) => setState(() => _attestedAdultOwner = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text("I'm 18 or over and authorised to register this business"),
                  ),
                CheckboxListTile(
                  value: _agreedToTerms,
                  onChanged: (value) => setState(() => _agreedToTerms = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('I agree to the '),
                      _LegalLink(label: 'Terms of Service', url: _termsOfServiceUrl),
                      const Text(' and '),
                      _LegalLink(label: 'Privacy Policy', url: _privacyPolicyUrl),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (authState.hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      authState.error.toString(),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                FilledButton(
                  onPressed: authState.isLoading ? null : _submit,
                  child: authState.isLoading
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isOAuthCompletion ? 'Finish' : 'Sign up'),
                ),
                // Otherwise someone who picked the wrong Google account has
                // no way off this screen: the router keeps a signed-in user
                // without a profile here.
                if (_isOAuthCompletion)
                  TextButton(
                    onPressed: authState.isLoading
                        ? null
                        : () async {
                            await ref.read(authControllerProvider.notifier).signOut();
                            if (context.mounted) context.go('/sign-in');
                          },
                    child: const Text('Use a different account'),
                  ),
                if (!_isOAuthCompletion) ...[
                  TextButton(
                    onPressed: () => context.go('/sign-in'),
                    child: const Text('Already have an account? Sign in'),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or')), Expanded(child: Divider())]),
                  ),
                  OutlinedButton.icon(
                    onPressed: authState.isLoading
                        ? null
                        : () => ref.read(authControllerProvider.notifier).signInWithOAuth(OAuthProvider.google),
                    icon: const Icon(Icons.g_mobiledata),
                    label: const Text('Continue with Google'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
