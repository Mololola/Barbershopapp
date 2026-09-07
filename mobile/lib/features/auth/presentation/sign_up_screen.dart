import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  AccountRole _role = AccountRole.customer;
  String? _confirmationMessage;

  /// True once Google/Apple sign-in has already completed and the router
  /// sent us here because there's no `profiles` row yet — see
  /// AuthController.completeOAuthProfile. In that case there's no email or
  /// password to collect, just the role and username a normal signUp()
  /// would have carried as user metadata.
  bool get _isOAuthCompletion => ref.read(currentAuthUserIdProvider) != null;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _confirmationMessage = null);

    final notifier = ref.read(authControllerProvider.notifier);
    if (_isOAuthCompletion) {
      await notifier.completeOAuthProfile(role: _role, username: _usernameController.text.trim());
      return;
    }

    await notifier.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _role,
      username: _usernameController.text.trim(),
    );

    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state.hasError) return;

    if (Supabase.instance.client.auth.currentSession == null) {
      setState(() => _confirmationMessage = 'Check your email to confirm your account, then sign in.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isOAuthCompletion ? 'Finish setting up your account' : 'Create account')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              SegmentedButton<AccountRole>(
                segments: const [
                  ButtonSegment(value: AccountRole.customer, label: Text('Customer')),
                  ButtonSegment(value: AccountRole.business, label: Text('Business')),
                ],
                selected: {_role},
                onSelectionChanged: (selection) => setState(() => _role = selection.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username', helperText: 'Must be unique — shown on rankings and posts'),
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
              const SizedBox(height: 24),
              if (authState.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    authState.error.toString(),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (_confirmationMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_confirmationMessage!),
                ),
              FilledButton(
                onPressed: authState.isLoading ? null : _submit,
                child: authState.isLoading
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isOAuthCompletion ? 'Finish' : 'Sign up'),
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
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: authState.isLoading
                      ? null
                      : () => ref.read(authControllerProvider.notifier).signInWithOAuth(OAuthProvider.apple),
                  icon: const Icon(Icons.apple),
                  label: const Text('Continue with Apple'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
