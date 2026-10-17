/// Where a person's withdrawals are sent. Entered once, validated and
/// stored by the backend; each payout request keeps its own copy.
class PayoutDetails {
  const PayoutDetails({required this.accountHolder, required this.iban});

  final String accountHolder;
  final String iban;

  /// "ES91 •••• 1332" — enough to recognise the account at a glance.
  String get maskedIban => '${iban.substring(0, 4)} •••• ${iban.substring(iban.length - 4)}';

  factory PayoutDetails.fromRow(Map<String, dynamic> row) {
    return PayoutDetails(accountHolder: row['account_holder'] as String, iban: row['iban'] as String);
  }
}
