import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/rewards/application/rewards_controller.dart';
import 'package:mobile/features/rewards/domain/payout_request.dart';

PayoutRequest _request(int amountCents, PayoutRequestStatus status) {
  return PayoutRequest(
    id: 'r1',
    profileId: 'p1',
    amountCents: amountCents,
    status: status,
    requestedAt: DateTime(2026),
  );
}

void main() {
  test('no requests: the whole ledger balance is available', () {
    expect(availableBalanceCents(1000, const []), 1000);
  });

  test('a pending request reduces available balance', () {
    expect(availableBalanceCents(1000, [_request(400, PayoutRequestStatus.pending)]), 600);
  });

  test('approved and paid requests both still count against the balance', () {
    final requests = [
      _request(300, PayoutRequestStatus.approved),
      _request(200, PayoutRequestStatus.paid),
    ];
    expect(availableBalanceCents(1000, requests), 500);
  });

  test('a rejected request does not reduce available balance', () {
    expect(availableBalanceCents(1000, [_request(400, PayoutRequestStatus.rejected)]), 1000);
  });

  test('never goes negative even if requests somehow exceed the ledger', () {
    expect(availableBalanceCents(100, [_request(400, PayoutRequestStatus.pending)]), 0);
  });
}
