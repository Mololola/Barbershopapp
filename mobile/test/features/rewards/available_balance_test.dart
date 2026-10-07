import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/rewards/application/rewards_controller.dart';
import 'package:mobile/features/rewards/domain/payout_request.dart';

PayoutRequest _request(int amountCents, PayoutRequestStatus status, {String currency = 'GBP'}) {
  return PayoutRequest(
    id: 'r1',
    profileId: 'p1',
    amountCents: amountCents,
    currency: currency,
    status: status,
    requestedAt: DateTime(2026),
  );
}

void main() {
  test('no requests: the whole ledger balance is available', () {
    expect(availableBalances({'GBP': 1000}, const []), {'GBP': 1000});
  });

  test('a pending request reduces available balance', () {
    expect(availableBalances({'GBP': 1000}, [_request(400, PayoutRequestStatus.pending)]), {'GBP': 600});
  });

  test('approved and paid requests both still count against the balance', () {
    final requests = [
      _request(300, PayoutRequestStatus.approved),
      _request(200, PayoutRequestStatus.paid),
    ];
    expect(availableBalances({'GBP': 1000}, requests), {'GBP': 500});
  });

  test('a rejected request does not reduce available balance', () {
    expect(availableBalances({'GBP': 1000}, [_request(400, PayoutRequestStatus.rejected)]), {'GBP': 1000});
  });

  test('never goes negative even if requests somehow exceed the ledger', () {
    expect(availableBalances({'GBP': 100}, [_request(400, PayoutRequestStatus.pending)]), {'GBP': 0});
  });

  test('a withdrawal only reduces the balance in its own currency', () {
    final requests = [_request(400, PayoutRequestStatus.pending, currency: 'EUR')];
    expect(availableBalances({'GBP': 1000, 'EUR': 1000}, requests), {'GBP': 1000, 'EUR': 600});
  });

  test('balances show each currency with its own symbol', () {
    expect(formatBalances({'GBP': 400, 'EUR': 1050}), '£4 · €10.50');
    expect(formatBalances({}), '0');
  });
}
