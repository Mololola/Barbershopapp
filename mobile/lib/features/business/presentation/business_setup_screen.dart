import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/business_controller.dart';
import '../domain/business.dart';

class _LocationFields {
  _LocationFields()
      : addressLine = TextEditingController(),
        city = TextEditingController();

  final TextEditingController addressLine;
  final TextEditingController city;

  void dispose() {
    addressLine.dispose();
    city.dispose();
  }
}

class BusinessSetupScreen extends ConsumerStatefulWidget {
  const BusinessSetupScreen({super.key});

  @override
  ConsumerState<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends ConsumerState<BusinessSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _referralCodeController = TextEditingController();
  final _locations = [_LocationFields()];
  final List<OpeningHours> _hours = OpeningHours.defaultWeek();
  String _currency = supportedCurrencies.first;

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

  Future<void> _pickTime(int dayIndex, {required bool isOpenTime}) async {
    final current = isOpenTime ? _hours[dayIndex].openTime : _hours[dayIndex].closeTime;
    final picked = await showTimePicker(context: context, initialTime: current ?? TimeOfDay.now());
    if (picked == null) return;
    setState(() {
      _hours[dayIndex] = isOpenTime
          ? _hours[dayIndex].copyWith(openTime: picked)
          : _hours[dayIndex].copyWith(closeTime: picked);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final locations = [
      for (final location in _locations)
        BusinessLocation(addressLine: location.addressLine.text.trim(), city: location.city.text.trim()),
    ];

    await ref.read(businessSetupControllerProvider.notifier).createBusiness(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          currency: _currency,
          locations: locations,
          openingHours: _hours,
          referredByCode:
              _referralCodeController.text.trim().isEmpty ? null : _referralCodeController.text.trim(),
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
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Business name'),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone (internal only, not shown publicly)',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _referralCodeController,
                decoration: const InputDecoration(labelText: 'Referral code (optional)'),
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
              Text('Locations', style: Theme.of(context).textTheme.titleMedium),
              for (var i = 0; i < _locations.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _locations[i].addressLine,
                              decoration: const InputDecoration(labelText: 'Address'),
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty) ? 'Required' : null,
                            ),
                            TextFormField(
                              controller: _locations[i].city,
                              decoration: const InputDecoration(labelText: 'City'),
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty) ? 'Required' : null,
                            ),
                          ],
                        ),
                      ),
                      if (_locations.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => setState(() {
                            _locations.removeAt(i).dispose();
                          }),
                        ),
                    ],
                  ),
                ),
              TextButton.icon(
                onPressed: () => setState(() => _locations.add(_LocationFields())),
                icon: const Icon(Icons.add),
                label: const Text('Add another location'),
              ),
              const SizedBox(height: 16),
              Text('Opening hours', style: Theme.of(context).textTheme.titleMedium),
              for (var i = 0; i < _hours.length; i++)
                Row(
                  children: [
                    SizedBox(width: 100, child: Text(OpeningHours.dayNames[i])),
                    Switch(
                      value: !_hours[i].isClosed,
                      onChanged: (open) => setState(() => _hours[i] = _hours[i].copyWith(isClosed: !open)),
                    ),
                    if (!_hours[i].isClosed) ...[
                      TextButton(
                        onPressed: () => _pickTime(i, isOpenTime: true),
                        child: Text(_hours[i].openTime?.format(context) ?? 'Start'),
                      ),
                      const Text('–'),
                      TextButton(
                        onPressed: () => _pickTime(i, isOpenTime: false),
                        child: Text(_hours[i].closeTime?.format(context) ?? 'End'),
                      ),
                    ] else
                      const Text('Closed'),
                  ],
                ),
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
    );
  }
}
