/// The owner's Overview numbers — mirrors backend/app/api/admin.py's
/// AdminMetrics response.
class WindowedCount {
  const WindowedCount({
    required this.total,
    required this.last7Days,
    required this.last30Days,
    required this.previous30Days,
  });

  final int total;
  final int last7Days;
  final int last30Days;

  /// The 30 days before the last 30 — what [last30Days] is compared against.
  final int previous30Days;

  factory WindowedCount.fromJson(Map<String, dynamic> json) => WindowedCount(
        total: json['total'] as int,
        last7Days: json['last_7_days'] as int,
        last30Days: json['last_30_days'] as int,
        previous30Days: json['previous_30_days'] as int,
      );
}

class CurrencyAmount {
  const CurrencyAmount({required this.currency, required this.amountCents, required this.count});

  final String currency;
  final int amountCents;
  final int count;

  factory CurrencyAmount.fromJson(Map<String, dynamic> json) => CurrencyAmount(
        currency: json['currency'] as String,
        amountCents: json['amount_cents'] as int,
        count: json['count'] as int,
      );
}

class NamedCount {
  const NamedCount({required this.name, required this.count});

  final String name;
  final int count;

  factory NamedCount.fromJson(Map<String, dynamic> json) =>
      NamedCount(name: json['name'] as String, count: json['count'] as int);
}

class MonthTrend {
  const MonthTrend({
    required this.month,
    required this.newCustomers,
    required this.newBusinesses,
    required this.completedBookings,
  });

  /// "YYYY-MM"
  final String month;
  final int newCustomers;
  final int newBusinesses;
  final int completedBookings;

  factory MonthTrend.fromJson(Map<String, dynamic> json) => MonthTrend(
        month: json['month'] as String,
        newCustomers: json['new_customers'] as int,
        newBusinesses: json['new_businesses'] as int,
        completedBookings: json['completed_bookings'] as int,
      );
}

List<T> _list<T>(dynamic json, T Function(Map<String, dynamic>) parse) =>
    [for (final item in json as List) parse(item as Map<String, dynamic>)];

class AdminMetrics {
  const AdminMetrics({
    required this.customers,
    required this.businessAccounts,
    required this.minors,
    required this.workersOptedIn,
    required this.workersLookingForWork,
    required this.signInMethods,
    required this.awaitingEmailConfirmation,
    required this.confirmedWithoutProfile,
    required this.businesses,
    required this.setupComplete,
    required this.bookable,
    required this.suspended,
    required this.subscriptionsByStatus,
    required this.grandfathered,
    required this.trialsActive,
    required this.trialsEndingIn7Days,
    required this.trialsEnded,
    required this.trialsConvertedToPaying,
    required this.monthlyRecurring,
    required this.monthlyRecurringInTrial,
    required this.monthlyRecurringAtRisk,
    required this.financeToolPaid,
    required this.financeToolTrialsActive,
    required this.designSlotBundlesSold,
    required this.designSlotRevenueGbpCents,
    required this.rewardsEarnedCents,
    required this.rewardsEarnedLast30DaysCents,
    required this.rewardsPaidOutCents,
    required this.pendingPayouts,
    required this.pendingPayoutsCents,
    required this.rewardsOwedCents,
    required this.qualityReviewers,
    required this.bookings,
    required this.upcomingBookings,
    required this.completedBookings,
    required this.cancelledBookings,
    required this.reviews,
    required this.averageShopRating,
    required this.averageWorkerRating,
    required this.averageHaircutRating,
    required this.monthlyTrend,
  });

  final WindowedCount customers;
  final WindowedCount businessAccounts;
  final int minors;
  final int workersOptedIn;
  final int workersLookingForWork;
  final List<NamedCount> signInMethods;
  final int awaitingEmailConfirmation;
  final int confirmedWithoutProfile;

  final WindowedCount businesses;
  final int setupComplete;
  final int bookable;
  final int suspended;
  final List<NamedCount> subscriptionsByStatus;
  final int grandfathered;
  final int trialsActive;
  final int trialsEndingIn7Days;
  final int trialsEnded;
  final int trialsConvertedToPaying;

  final List<CurrencyAmount> monthlyRecurring;
  final List<CurrencyAmount> monthlyRecurringInTrial;
  final List<CurrencyAmount> monthlyRecurringAtRisk;
  final List<CurrencyAmount> financeToolPaid;
  final int financeToolTrialsActive;
  final int designSlotBundlesSold;
  final int designSlotRevenueGbpCents;

  final int rewardsEarnedCents;
  final int rewardsEarnedLast30DaysCents;
  final int rewardsPaidOutCents;
  final int pendingPayouts;
  final int pendingPayoutsCents;
  final int rewardsOwedCents;
  final int qualityReviewers;

  final WindowedCount bookings;
  final int upcomingBookings;
  final int completedBookings;
  final int cancelledBookings;
  final WindowedCount reviews;
  final double? averageShopRating;
  final double? averageWorkerRating;
  final double? averageHaircutRating;
  final List<MonthTrend> monthlyTrend;

  factory AdminMetrics.fromJson(Map<String, dynamic> json) {
    final users = json['users'] as Map<String, dynamic>;
    final businesses = json['businesses'] as Map<String, dynamic>;
    final revenue = json['revenue'] as Map<String, dynamic>;
    final rewards = json['rewards'] as Map<String, dynamic>;
    final activity = json['activity'] as Map<String, dynamic>;
    return AdminMetrics(
      customers: WindowedCount.fromJson(users['customers'] as Map<String, dynamic>),
      businessAccounts: WindowedCount.fromJson(users['business_accounts'] as Map<String, dynamic>),
      minors: users['minors'] as int,
      workersOptedIn: users['workers_opted_in'] as int,
      workersLookingForWork: users['workers_looking_for_work'] as int,
      signInMethods: _list(users['sign_in_methods'], NamedCount.fromJson),
      awaitingEmailConfirmation: users['awaiting_email_confirmation'] as int,
      confirmedWithoutProfile: users['confirmed_without_profile'] as int,
      businesses: WindowedCount.fromJson(businesses['businesses'] as Map<String, dynamic>),
      setupComplete: businesses['setup_complete'] as int,
      bookable: businesses['bookable'] as int,
      suspended: businesses['suspended'] as int,
      subscriptionsByStatus: _list(businesses['subscriptions_by_status'], NamedCount.fromJson),
      grandfathered: businesses['grandfathered'] as int,
      trialsActive: businesses['trials_active'] as int,
      trialsEndingIn7Days: businesses['trials_ending_in_7_days'] as int,
      trialsEnded: businesses['trials_ended'] as int,
      trialsConvertedToPaying: businesses['trials_converted_to_paying'] as int,
      monthlyRecurring: _list(revenue['monthly_recurring'], CurrencyAmount.fromJson),
      monthlyRecurringInTrial: _list(revenue['monthly_recurring_in_trial'], CurrencyAmount.fromJson),
      monthlyRecurringAtRisk: _list(revenue['monthly_recurring_at_risk'], CurrencyAmount.fromJson),
      financeToolPaid: _list(revenue['finance_tool_paid'], CurrencyAmount.fromJson),
      financeToolTrialsActive: revenue['finance_tool_trials_active'] as int,
      designSlotBundlesSold: revenue['design_slot_bundles_sold'] as int,
      designSlotRevenueGbpCents: revenue['design_slot_revenue_gbp_cents'] as int,
      rewardsEarnedCents: rewards['earned_cents'] as int,
      rewardsEarnedLast30DaysCents: rewards['earned_last_30_days_cents'] as int,
      rewardsPaidOutCents: rewards['paid_out_cents'] as int,
      pendingPayouts: rewards['pending_payouts'] as int,
      pendingPayoutsCents: rewards['pending_payouts_cents'] as int,
      rewardsOwedCents: rewards['owed_cents'] as int,
      qualityReviewers: rewards['quality_reviewers'] as int,
      bookings: WindowedCount.fromJson(activity['bookings'] as Map<String, dynamic>),
      upcomingBookings: activity['upcoming_bookings'] as int,
      completedBookings: activity['completed_bookings'] as int,
      cancelledBookings: activity['cancelled_bookings'] as int,
      reviews: WindowedCount.fromJson(activity['reviews'] as Map<String, dynamic>),
      averageShopRating: (activity['average_shop_rating'] as num?)?.toDouble(),
      averageWorkerRating: (activity['average_worker_rating'] as num?)?.toDouble(),
      averageHaircutRating: (activity['average_haircut_rating'] as num?)?.toDouble(),
      monthlyTrend: _list(activity['monthly_trend'], MonthTrend.fromJson),
    );
  }
}
