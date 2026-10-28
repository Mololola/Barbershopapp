import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../application/auth_controller.dart';

/// Reached only via the password-reset email's deep link, which signs the
/// user into a temporary recovery session — see router.dart's
/// [passwordRecoveryProvider] handling.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).updatePassword(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.setNewPasswordTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: context.l10n.newPasswordLabel),
                obscureText: true,
                autofocus: true,
                validator: (value) {
                  if (value == null || value.isEmpty) return context.l10n.requiredField;
                  if (value.length < 6) return context.l10n.atLeast6Characters;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                decoration: InputDecoration(labelText: context.l10n.confirmNewPasswordLabel),
                obscureText: true,
                validator: (value) {
                  if (value != _passwordController.text) return context.l10n.passwordsDontMatch;
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
              FilledButton(
                onPressed: authState.isLoading ? null : _submit,
                child: authState.isLoading
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(context.l10n.updatePassword),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
