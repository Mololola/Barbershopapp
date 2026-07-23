import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    await ref.read(authControllerProvider.notifier).signUp(
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
      appBar: AppBar(title: const Text('Create account')),
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
                    : const Text('Sign up'),
              ),
              TextButton(
                onPressed: () => context.go('/sign-in'),
                child: const Text('Already have an account? Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
