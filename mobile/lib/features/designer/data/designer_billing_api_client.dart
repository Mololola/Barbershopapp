import '../../../core/api_client.dart';

class DesignerBillingApiClient {
  DesignerBillingApiClient(this._api);

  final ApiClient _api;

  Future<String> createExtraSlotsCheckout() async {
    final result = await _api.post('/designer/extra-slots/checkout');
    return (result as Map<String, dynamic>)['url'] as String;
  }
}
