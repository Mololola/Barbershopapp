import '../../../core/l10n.dart';
import '../../../core/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/business_controller.dart';
import '../domain/business.dart';
import 'location_form_section.dart';
import 'opening_hours_editor.dart';

/// Business details: locations and opening hours.
/// The shop page's look (logo, cover, colour) is edited separately — see
/// edit_shop_page_screen.dart.
class BusinessEditScreen extends ConsumerStatefulWidget {
  const BusinessEditScreen({super.key});

  @override
  ConsumerState<BusinessEditScreen> createState() => _BusinessEditScreenState();
}

class _BusinessEditScreenState extends ConsumerState<BusinessEditScreen> {
  final _formKey = GlobalKey<FormState>();
  List<LocationFields>? _locations;
  List<OpeningHours>? _hours;

  @override
  void dispose() {
    for (final location in _locations ?? const <LocationFields>[]) {
      location.dispose();
    }
    super.dispose();
  }

  void _seedLocationsIfNeeded(List<BusinessLocation> existing) {
    if (_locations != null) return;
    _locations = existing.isEmpty ? [LocationFields()] : [for (final l in existing) LocationFields(l)];
  }

  Future<void> _save() async {
    final locations = _locations;
    final hours = _hours;
    if (locations == null || hours == null || !_formKey.currentState!.validate()) return;
    if (!hours.every((day) => day.hasValidRange)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.fixHighlightedHours)));
      return;
    }
    final success = await ref.read(businessEditControllerProvider.notifier).save(
          locations: [for (final l in locations) l.toLocation()],
          hours: hours,
        );
    if (!mounted || !success) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.businessDetailsSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(locationsProvider);
    final storedHours = ref.watch(openingHoursProvider);
    final editState = ref.watch(businessEditControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.businessDetails)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: locations.when(
          loading: () => const LoadingView(),
          error: (error, _) => Center(child: Text(context.l10n.errorWithDetail('$error'))),
          data: (existingLocations) {
            if (!storedHours.hasValue) return const LoadingView();
            _seedLocationsIfNeeded(existingLocations);
            _hours ??= OpeningHours.fullWeek(storedHours.value!);
            final fields = _locations!;
            final hours = _hours!;

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                // Not a ListView: that unmounts off-screen fields, and Form.validate()
                // silently skips unmounted ones.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LocationFormSection(locations: fields, onChanged: () => setState(() {})),
                    const SizedBox(height: 24),
                    Text(context.l10n.openingHours, style: Theme.of(context).textTheme.titleMedium),
                    OpeningHoursEditor(hours: hours, onChanged: (i, day) => setState(() => hours[i] = day)),
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
                          : Text(context.l10n.save),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
