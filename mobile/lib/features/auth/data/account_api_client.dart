import '../../../core/api_client.dart';

class AccountApiClient {
  AccountApiClient(this._api);

  final ApiClient _api;

  /// Throws [ApiException] with a 409 if the backend blocks deletion (an
  /// active subscription or upcoming bookings for a business account) — see
  /// backend/app/api/account.py.
  Future<void> deleteAccount() async {
    await _api.delete('/account');
  }
}
