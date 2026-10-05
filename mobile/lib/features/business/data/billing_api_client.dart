import '../../../core/api_client.dart';
import '../domain/finance_overview.dart';

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

  Future<void> cancelSubscription(String businessId) async {
    await _api.post('/businesses/$businessId/subscription/cancel');
  }

  Future<void> resumeSubscription(String businessId) async {
    await _api.post('/businesses/$businessId/subscription/resume');
  }

  Future<void> cancelFinancePremium(String businessId) async {
    await _api.post('/businesses/$businessId/finance-access/cancel');
  }

  Future<void> resumeFinancePremium(String businessId) async {
    await _api.post('/businesses/$businessId/finance-access/resume');
  }

  Future<void> startFinanceTrial(String businessId) async {
    await _api.post('/businesses/$businessId/finance-access/trial');
  }

  Future<FinanceOverview> fetchFinanceOverview(String businessId, DateTime month) async {
    final monthParam = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final result = await _api.get('/businesses/$businessId/finance', query: {'month': monthParam});
    return FinanceOverview.fromJson(result as Map<String, dynamic>);
  }

  Future<String> createFinanceAccessCheckout(String businessId) async {
    final result = await _api.post('/businesses/$businessId/finance-access/checkout');
    return (result as Map<String, dynamic>)['url'] as String;
  }
}
