import '../../../core/api_client.dart';

class BillingApiClient {
  BillingApiClient(this._api);

  final ApiClient _api;

  Future<String> createCheckoutSession(String businessId) async {
    final result = await _api.post('/businesses/$businessId/subscription/checkout');
    return (result as Map<String, dynamic>)['url'] as String;
  }

  Future<String> createPortalSession(String businessId) async {
    final result = await _api.post('/businesses/$businessId/subscription/portal');
    return (result as Map<String, dynamic>)['url'] as String;
  }
}
