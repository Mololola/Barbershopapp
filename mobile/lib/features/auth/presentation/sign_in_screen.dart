import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n.dart';
import '../application/auth_controller.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.initialMessage});

  /// Shown once, e.g. "Check your email to confirm your account" right
  /// after a successful sign-up — see router.dart's '/sign-in' route.
  final String? initialMessage;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _message;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _message = null);
    await ref.read(authControllerProvider.notifier).signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  Future<void> _resendConfirmation() async {
    await ref.read(authControllerProvider.notifier).resendConfirmationEmail(_emailController.text.trim());
    if (!mounted) return;
    final message = ref.read(authControllerProvider).hasError ? context.l10n.resendConfirmationFailed : context.l10n.confirmationEmailSent;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.signInTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
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
                validator: (value) => (value == null || value.isEmpty) ? context.l10n.requiredField : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: Text(context.l10n.forgotPasswordLink),
                ),
              ),
              const SizedBox(height: 8),
              if (_message != null && !authState.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_message!),
                ),
              if (authState.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    authState.error.toString(),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (authState.error is AuthException && (authState.error as AuthException).code == 'email_not_confirmed')
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: OutlinedButton(
                    onPressed: authState.isLoading ? null : _resendConfirmation,
                    child: Text(context.l10n.resendConfirmationEmail),
                  ),
                ),
              FilledButton(
                onPressed: authState.isLoading ? null : _submit,
                child: authState.isLoading
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(context.l10n.signInTitle),
              ),
              TextButton(
                onPressed: () => context.go('/sign-up'),
                child: Text(context.l10n.noAccountSignUp),
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
          ),
        ),
      ),
    );
  }
}
