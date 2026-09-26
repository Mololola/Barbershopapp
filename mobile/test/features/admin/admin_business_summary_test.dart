import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/domain/admin_business_summary.dart';

void main() {
  // Shapes copied from the live PostgREST response to AdminRepository.fetchBusinesses.
  test('parses a business with a subscription (embedded one-to-one as an object)', () {
    final summary = AdminBusinessSummary.fromRow({
      'id': 'd5f8bde3-95e8-402e-930b-17de7b3596b2',
      'name': 'Molola Enterprises',
      'created_at': '2026-09-25T15:19:18.68921+00:00',
      'subscription_trial_ends_at': null,
      'owner': {'username': 'MLE'},
      'business_subscriptions': {'status': 'incomplete'},
    });

    expect(summary.ownerUsername, 'MLE');
    expect(summary.subscriptionStatus, 'incomplete');
    expect(summary.hasActiveTrial, isFalse);
  });

  test('parses a business that never started checkout, with an active trial', () {
    final summary = AdminBusinessSummary.fromRow({
      'id': 'b2',
      'name': 'Fresh Cuts',
      'created_at': '2026-09-25T15:19:18+00:00',
      'subscription_trial_ends_at': DateTime.now().add(const Duration(days: 20)).toUtc().toIso8601String(),
      'owner': {'username': 'fresh'},
      'business_subscriptions': null,
    });

    expect(summary.subscriptionStatus, isNull);
    expect(summary.hasActiveTrial, isTrue);
  });
}
