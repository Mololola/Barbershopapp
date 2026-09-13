import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_controller.dart';
import '../domain/guardian_link.dart';

/// Where a minor's account is confined until a guardian has confirmed —
/// see router.dart's resolveRedirect and the 832ca4a41b29 migration.
class GuardianConsentScreen extends ConsumerStatefulWidget {
  const GuardianConsentScreen({super.key});

  @override
  ConsumerState<GuardianConsentScreen> createState() => _GuardianConsentScreenState();
}

class _GuardianConsentScreenState extends ConsumerState<GuardianConsentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(guardianControllerProvider.notifier).inviteGuardian(_emailController.text.trim());
    ref.invalidate(guardianLinkForMinorProvider);
  }

  @override
  Widget build(BuildContext context) {
    final linkAsync = ref.watch(guardianLinkForMinorProvider);
    final guardianState = ref.watch(guardianControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent or guardian'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: linkAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
          data: (link) => link == null ? _inviteForm(guardianState) : _pendingState(link),
        ),
      ),
    );
  }

  Widget _inviteForm(AsyncValue<void> guardianState) {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          const Text(
            'Your account needs a parent or guardian to confirm before you can start booking.',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text('Enter their email — we\'ll show them a confirmation to accept from their own account.'),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Parent or guardian\'s email'),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Required';
              if (!value.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 24),
          if (guardianState.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                guardianState.error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton(
            onPressed: guardianState.isLoading ? null : _submit,
            child: guardianState.isLoading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Send invite'),
          ),
        ],
      ),
    );
  }

  Widget _pendingState(GuardianLink link) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.hourglass_top, size: 40),
        const SizedBox(height: 16),
        Text(
          'Waiting for ${link.guardianEmail} to confirm',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ask them to sign in to Barbershop App — they\'ll see a confirmation to accept from their home screen.',
        ),
      ],
    );
  }
}
