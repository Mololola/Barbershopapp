import 'package:flutter/material.dart';

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

String? _required(String? value) => (value == null || value.trim().isEmpty) ? 'Required' : null;

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
        Text('Locations', style: Theme.of(context).textTheme.titleMedium),
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
            label: const Text('Add another location'),
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
          decoration: const InputDecoration(labelText: 'Country'),
          items: [
            for (final entry in supportedCountries.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (value) {
            fields.country = value!;
            onCountryChanged();
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: fields.addressLine,
          decoration: const InputDecoration(labelText: 'Street address'),
          textCapitalization: TextCapitalization.words,
          validator: _required,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: fields.city,
          decoration: const InputDecoration(labelText: 'City'),
          textCapitalization: TextCapitalization.words,
          validator: _required,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: fields.postcode,
          decoration: const InputDecoration(labelText: 'Postcode'),
          textCapitalization: TextCapitalization.characters,
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Required';
            if (!isValidPostcode(value, fields.country)) return 'Enter a valid postcode';
            return null;
          },
        ),
      ],
    );
  }
}
