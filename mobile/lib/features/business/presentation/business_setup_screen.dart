import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/loading.dart';
import '../application/business_controller.dart';
import '../domain/business.dart';
import 'location_form_section.dart';
import 'opening_hours_editor.dart';
import 'services_screen.dart';
import 'staff_screen.dart';

final _phonePattern = RegExp(r'^\+?[0-9 ()-]{7,20}$');

/// The onboarding wizard the router holds a business owner in until
/// [Business.isSetupComplete]: details (creates the business) -> at least
/// one service -> at least one staff member. Customers only find the
/// business once it has both (businesses_public.is_bookable), so the last
/// two steps are what make it bookable at all.
class BusinessSetupScreen extends ConsumerStatefulWidget {
  const BusinessSetupScreen({super.key});

  @override
  ConsumerState<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

enum _Step { services, staff }

class _BusinessSetupScreenState extends ConsumerState<BusinessSetupScreen> {
  _Step? _step;

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(currentBusinessProvider);
    if (!business.hasValue) return const Scaffold(body: LoadingView());
    if (business.value == null) return const _DetailsStep();

    final services = ref.watch(servicesProvider);
    final workers = ref.watch(workersProvider);
    if (!services.hasValue || !workers.hasValue) return const Scaffold(body: LoadingView());

    // Resuming a half-finished setup (app closed mid-wizard) starts on
    // whichever step still has nothing in it.
    final step = _step ?? (services.value!.isEmpty ? _Step.services : _Step.staff);
    final setupState = ref.watch(businessSetupControllerProvider);

    if (step == _Step.services) {
      return ServicesScreen(
        setupFooter: _SetupFooter(
          stepLabel: 'Step 2 of 3',
          hint:
              'Add at least one service with its price and duration. Your monthly subscription is '
              '10× your average service price.',
          continueLabel: 'Continue',
          onContinue: services.value!.isEmpty ? null : () => setState(() => _step = _Step.staff),
        ),
      );
    }

    return StaffScreen(
      setupFooter: _SetupFooter(
        stepLabel: 'Step 3 of 3',
        hint:
            'Add everyone customers can book with — including yourself if you cut hair. Tap + for '
            'staff without an app account.',
        error: setupState.hasError ? setupState.error.toString() : null,
        onBack: () => setState(() => _step = _Step.services),
        continueLabel: 'Finish',
        onContinue: setupState.isLoading || !workers.value!.any((worker) => worker.isActive)
            ? null
            : () => ref.read(businessSetupControllerProvider.notifier).completeSetup(),
      ),
    );
  }
}

class _SetupFooter extends StatelessWidget {
  const _SetupFooter({
    required this.stepLabel,
    required this.hint,
    required this.continueLabel,
    required this.onContinue,
    this.onBack,
    this.error,
  });

  final String stepLabel;
  final String hint;
  final String continueLabel;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(stepLabel, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(hint, style: Theme.of(context).textTheme.bodySmall),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (onBack != null) TextButton(onPressed: onBack, child: const Text('Back')),
                const Spacer(),
                FilledButton(onPressed: onContinue, child: Text(continueLabel)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsStep extends ConsumerStatefulWidget {
  const _DetailsStep();

  @override
  ConsumerState<_DetailsStep> createState() => _DetailsStepState();
}

class _DetailsStepState extends ConsumerState<_DetailsStep> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: ref.read(signUpBusinessNameProvider));
  final _phoneController = TextEditingController();
  final _referralCodeController = TextEditingController();
  final _locations = [LocationFields()];
  final List<OpeningHours> _hours = OpeningHours.defaultWeek();
  late String _currency = currencyForCountry(_locations.first.country);

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _referralCodeController.dispose();
    for (final location in _locations) {
      location.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final invalidDay = _hours.where((hours) => !hours.hasValidRange).firstOrNull;
    if (invalidDay != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Check ${OpeningHours.dayNames[invalidDay.dayOfWeek]}\'s opening hours.'),
        ),
      );
      return;
    }

    await ref
        .read(businessSetupControllerProvider.notifier)
        .createBusiness(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          currency: _currency,
          locations: [for (final location in _locations) location.toLocation()],
          openingHours: _hours,
          referredByCode: _referralCodeController.text.trim().isEmpty ? null : _referralCodeController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final setupState = ref.watch(businessSetupControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Set up your business')),
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
                Text('Step 1 of 3', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  'Your business details. Next you\'ll add your services and staff — customers can find and '
                  'book you once both are in.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Business name'),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Business phone',
                    helperText: 'For our records only — never shown to customers',
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Required';
                    if (!_phonePattern.hasMatch(value.trim())) return 'Enter a valid phone number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _referralCodeController,
                  decoration: const InputDecoration(labelText: 'Referral code (optional)'),
                ),
                const SizedBox(height: 24),
                LocationFormSection(
                  locations: _locations,
                  onChanged: () => setState(() => _currency = currencyForCountry(_locations.first.country)),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _currency,
                  decoration: const InputDecoration(labelText: 'Currency'),
                  items: [
                    for (final code in supportedCurrencies)
                      DropdownMenuItem(value: code, child: Text('$code (${currencySymbol(code)})')),
                  ],
                  onChanged: (value) => setState(() => _currency = value!),
                ),
                const SizedBox(height: 24),
                Text('Opening hours', style: Theme.of(context).textTheme.titleMedium),
                OpeningHoursEditor(hours: _hours, onChanged: (i, day) => setState(() => _hours[i] = day)),
                const SizedBox(height: 24),
                if (setupState.hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      setupState.error.toString(),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                FilledButton(
                  onPressed: setupState.isLoading ? null : _submit,
                  child: setupState.isLoading
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save and continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
