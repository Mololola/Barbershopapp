import 'dart:io';

import '../../../core/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../application/business_controller.dart';
import '../domain/business.dart';
import 'finance_access_section.dart';

class _LocationFields {
  _LocationFields({String addressLine = '', String city = ''})
      : addressLine = TextEditingController(text: addressLine),
        city = TextEditingController(text: city);

  final TextEditingController addressLine;
  final TextEditingController city;

  void dispose() {
    addressLine.dispose();
    city.dispose();
  }
}

class BusinessEditScreen extends ConsumerStatefulWidget {
  const BusinessEditScreen({super.key});

  @override
  ConsumerState<BusinessEditScreen> createState() => _BusinessEditScreenState();
}

class _BusinessEditScreenState extends ConsumerState<BusinessEditScreen> {
  File? _pickedLogo;
  List<_LocationFields>? _locations;

  @override
  void dispose() {
    for (final location in _locations ?? const <_LocationFields>[]) {
      location.dispose();
    }
    super.dispose();
  }

  void _seedLocationsIfNeeded(List<BusinessLocation> existing) {
    if (_locations != null) return;
    _locations = existing.isEmpty
        ? [_LocationFields()]
        : [for (final l in existing) _LocationFields(addressLine: l.addressLine, city: l.city)];
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _pickedLogo = File(picked.path));
  }

  Future<void> _save() async {
    final locations = _locations;
    if (locations == null) return;
    final success = await ref.read(businessEditControllerProvider.notifier).save(
          logoImage: _pickedLogo,
          locations: [
            for (final l in locations)
              BusinessLocation(addressLine: l.addressLine.text.trim(), city: l.city.text.trim()),
          ],
        );
    if (!mounted) return;
    if (success) setState(() => _pickedLogo = null);
  }

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(currentBusinessProvider).value;
    final locations = ref.watch(locationsProvider);
    final editState = ref.watch(businessEditControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit business')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: locations.when(
          loading: () => const LoadingView(),
          error: (error, _) => Center(child: Text('Error: $error')),
          data: (existingLocations) {
            _seedLocationsIfNeeded(existingLocations);
            final fields = _locations!;

            return ListView(
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage: _pickedLogo != null
                        ? FileImage(_pickedLogo!)
                        : (business?.logoUrl != null ? NetworkImage(business!.logoUrl!) : null)
                            as ImageProvider?,
                    child: (_pickedLogo == null && business?.logoUrl == null)
                        ? const Icon(Icons.storefront, size: 48)
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Change photo'),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Locations', style: Theme.of(context).textTheme.titleMedium),
                for (var i = 0; i < fields.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              TextFormField(
                                controller: fields[i].addressLine,
                                decoration: const InputDecoration(labelText: 'Address'),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: fields[i].city,
                                decoration: const InputDecoration(labelText: 'City'),
                              ),
                            ],
                          ),
                        ),
                        if (fields.length > 1)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => setState(() {
                              fields.removeAt(i).dispose();
                            }),
                          ),
                      ],
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => setState(() => fields.add(_LocationFields())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add another location'),
                ),
                const SizedBox(height: 16),
                if (editState.hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      editState.error.toString(),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                FilledButton(
                  onPressed: editState.isLoading ? null : _save,
                  child: editState.isLoading
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
                const SizedBox(height: 32),
                // Staff has its own bottom-nav tab now — pushing '/business/staff'
                // from here would collide with the shell branch that already owns
                // that route and crash the Navigator, so only Services (not a tab)
                // gets a shortcut here.
                ListTile(
                  title: const Text('Manage services'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/business/services'),
                ),
                const SizedBox(height: 32),
                FinanceAccessSection(business: business),
              ],
            );
          },
        ),
      ),
    );
  }
}
