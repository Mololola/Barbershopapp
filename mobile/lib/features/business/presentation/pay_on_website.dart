import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shops pay on the business website only: Apple and Google require their
/// own in-app payments for a subscription bought in a phone app. The apps
/// show the plan and can cancel it, but nothing in them starts a payment.
/// Settable only so tests can cover the website's payment flows.
bool canPayInThisApp = kIsWeb;

/// In place of a payment button in the phone apps.
class PayOnWebsiteNote extends StatelessWidget {
  const PayOnWebsiteNote({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        'Payments are handled on the Fadra Cut business website.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      );
}
