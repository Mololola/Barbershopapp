import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/legal.dart';
import '../../../core/supabase_providers.dart';
import '../../../core/l10n.dart';
import '../application/auth_controller.dart';
import '../domain/profile.dart';

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
  AccountRole _role = AccountRole.customer;
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
          .showSnackBar(SnackBar(content: Text(context.l10n.mustBe14)));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.dateOfBirthRequired)));
      return;
    }
    if (_isBusiness && !_attestedAdultOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.confirmAdultOwner)));
      return;
    }
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.mustAgreeToTerms)));
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
            ? context.l10n.finishAccountSetupTitle
            : _isBusiness
                ? context.l10n.createBusinessAccountTitle
                : context.l10n.createAccountTitle),
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
                    ButtonSegment(value: AccountRole.customer, label: Text(context.l10n.roleCustomer)),
                    // A minor can only ever be a customer account — see
                    // profiles_minor_role_check.
                    if (!_isMinorSelected)
                      ButtonSegment(value: AccountRole.business, label: Text(context.l10n.roleBusiness)),
                  ],
                  selected: {_role},
                  onSelectionChanged: (selection) => setState(() => _role = selection.first),
                ),
                if (_isBusiness)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      context.l10n.businessSignUpStepHint,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                if (_isBusiness && !_isOAuthCompletion) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _businessNameController,
                    decoration: InputDecoration(labelText: context.l10n.businessNameLabel),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) => (value == null || value.trim().isEmpty) ? context.l10n.requiredField : null,
                  ),
                ],
                if (!_isBusiness) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickDateOfBirth,
                    child: InputDecorator(
                      decoration: InputDecoration(labelText: context.l10n.dateOfBirthLabel),
                      child: Text(
                        _dateOfBirth == null
                            ? context.l10n.selectDate
                            : '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                  if (_isMinorSelected)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        context.l10n.minorAccountNotice,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: _isBusiness
                      ? InputDecoration(labelText: context.l10n.businessHandleLabel, helperText: context.l10n.businessHandleHelper)
                      : InputDecoration(labelText: context.l10n.usernameLabel, helperText: context.l10n.usernameHelper),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return context.l10n.requiredField;
                    if (value.trim().length < 3) return context.l10n.atLeast3Characters;
                    return null;
                  },
                ),
                if (!_isOAuthCompletion) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: context.l10n.emailLabel),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return context.l10n.requiredField;
                      if (!value.contains('@')) return context.l10n.invalidEmail;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(labelText: context.l10n.passwordLabel),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) return context.l10n.requiredField;
                      if (value.length < 6) return context.l10n.atLeast6Characters;
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
                    title: Text(context.l10n.adultOwnerCheckbox),
                  ),
                CheckboxListTile(
                  value: _agreedToTerms,
                  onChanged: (value) => setState(() => _agreedToTerms = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(context.l10n.agreePrefix),
                      _LegalLink(label: context.l10n.termsOfService, url: termsOfServiceUrl),
                      Text(context.l10n.agreeAnd),
                      _LegalLink(label: context.l10n.privacyPolicy, url: privacyPolicyUrl),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (authState.hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      describeError(context.l10n, authState.error),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                FilledButton(
                  onPressed: authState.isLoading ? null : _submit,
                  child: authState.isLoading
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isOAuthCompletion ? context.l10n.finishButton : context.l10n.signUpButton),
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
                    child: Text(context.l10n.useDifferentAccount),
                  ),
                if (!_isOAuthCompletion) ...[
                  TextButton(
                    onPressed: () => context.go('/sign-in'),
                    child: Text(context.l10n.haveAccountSignIn),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(context.l10n.orDivider)), const Expanded(child: Divider())]),
                  ),
                  OutlinedButton.icon(
                    onPressed: authState.isLoading
                        ? null
                        : () => ref.read(authControllerProvider.notifier).signInWithOAuth(OAuthProvider.google),
                    icon: const Icon(Icons.g_mobiledata),
                    label: Text(context.l10n.continueWithGoogle),
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
