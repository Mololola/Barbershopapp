import 'package:flutter/material.dart';

import '../../../core/l10n.dart';

import '../domain/business.dart';

class LocationFields {
  LocationFields([BusinessLocation? initial])
    : addressLine = TextEditingController(text: initial?.addressLine),
      city = TextEditingController(text: initial?.city),
      postcode = TextEditingController(text: initial?.postcode),
      country = initial?.country ?? supportedCountries.keys.first;

  final TextEditingController addressLine;
  final TextEditingController city;
  final TextEditingController postcode;
  String country;

  BusinessLocation toLocation() => BusinessLocation(
    addressLine: addressLine.text.trim(),
    city: city.text.trim(),
    postcode: postcode.text.trim(),
    country: country,
  );

  void dispose() {
    addressLine.dispose();
    city.dispose();
    postcode.dispose();
  }
}

String _countryName(BuildContext context, String code) => switch (code) {
      'GB' => context.l10n.countryUnitedKingdom,
      'ES' => context.l10n.countrySpain,
      _ => supportedCountries[code]!,
    };

/// The editable list of a business's locations. Must sit inside a [Form] —
/// validation runs through the enclosing form. The caller owns [locations]
/// (and disposes them); [onChanged] fires after a location is added,
/// removed, or has its country changed, for the caller to setState.
class LocationFormSection extends StatelessWidget {
  const LocationFormSection({super.key, required this.locations, required this.onChanged});

  final List<LocationFields> locations;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.locations, style: Theme.of(context).textTheme.titleMedium),
        for (var i = 0; i < locations.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LocationForm(fields: locations[i], onCountryChanged: onChanged),
                ),
                if (locations.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      locations.removeAt(i).dispose();
                      onChanged();
                    },
                  ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              locations.add(LocationFields());
              onChanged();
            },
            icon: const Icon(Icons.add),
            label: Text(context.l10n.addAnotherLocation),
          ),
        ),
      ],
    );
  }
}

class _LocationForm extends StatelessWidget {
  const _LocationForm({required this.fields, required this.onCountryChanged});

  final LocationFields fields;
  final VoidCallback onCountryChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: fields.country,
          decoration: InputDecoration(labelText: context.l10n.country),
          items: [
            for (final entry in supportedCountries.entries)
              DropdownMenuItem(value: entry.key, child: Text(_countryName(context, entry.key))),
          ],
          onChanged: (value) {
            fields.country = value!;
            onCountryChanged();
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: fields.addressLine,
          decoration: InputDecoration(labelText: context.l10n.streetAddress),
          textCapitalization: TextCapitalization.words,
          validator: (value) => (value == null || value.trim().isEmpty) ? context.l10n.requiredField : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: fields.city,
          decoration: InputDecoration(labelText: context.l10n.city),
          textCapitalization: TextCapitalization.words,
          validator: (value) => (value == null || value.trim().isEmpty) ? context.l10n.requiredField : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: fields.postcode,
          decoration: InputDecoration(labelText: context.l10n.postcode),
          textCapitalization: TextCapitalization.characters,
          validator: (value) {
            if (value == null || value.trim().isEmpty) return context.l10n.requiredField;
            if (!isValidPostcode(value, fields.country)) return context.l10n.enterValidPostcode;
            return null;
          },
        ),
      ],
    );
  }
}
