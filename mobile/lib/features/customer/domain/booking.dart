import '../../../l10n/app_localizations.dart';

enum BookingStatus { confirmed, cancelled, completed }

extension BookingStatusX on BookingStatus {
  String get wireValue => name;

  static BookingStatus fromWireValue(String value) {
    return BookingStatus.values.firstWhere((status) => status.wireValue == value);
  }
}

class Booking {
  const Booking({
    required this.id,
    required this.businessId,
    required this.workerId,
    required this.serviceId,
    required this.customerId,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.businessName,
    this.serviceName,
    this.workerName,
    this.customerName,
    this.priceCents,
  });

  final String id;
  final String businessId;
  final String workerId;
  final String serviceId;
  final String customerId;
  final DateTime startTime;
  final DateTime endTime;
  final BookingStatus status;

  /// The backend response only has ids; the booking lists embed the service,
  /// barber and customer names in the same Supabase query.
  final String? businessName;
  final String? serviceName;
  final String? workerName;
  final String? customerName;

  /// What the customer was quoted when booking, in the shop's currency.
  final int? priceCents;

  Booking copyWith({String? businessName, String? serviceName, String? workerName}) {
    return Booking(
      id: id,
      businessId: businessId,
      workerId: workerId,
      serviceId: serviceId,
      customerId: customerId,
      startTime: startTime,
      endTime: endTime,
      status: status,
      businessName: businessName ?? this.businessName,
      serviceName: serviceName ?? this.serviceName,
      workerName: workerName ?? this.workerName,
    );
  }

  factory Booking.fromApiJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      workerId: json['worker_id'] as String,
      serviceId: json['service_id'] as String,
      customerId: json['customer_id'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      status: BookingStatusX.fromWireValue(json['status'] as String),
    );
  }

  factory Booking.fromSupabaseRow(Map<String, dynamic> row) {
    return Booking(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      workerId: row['worker_id'] as String,
      serviceId: row['service_id'] as String,
      customerId: row['customer_id'] as String,
      startTime: DateTime.parse(row['start_time'] as String),
      endTime: DateTime.parse(row['end_time'] as String),
      status: BookingStatusX.fromWireValue(row['status'] as String),
      serviceName: (row['services'] as Map<String, dynamic>?)?['name'] as String?,
      workerName: (row['workers'] as Map<String, dynamic>?)?['name'] as String?,
      customerName: (row['profiles'] as Map<String, dynamic>?)?['username'] as String?,
      priceCents: row['price_cents'] as int?,
    );
  }
}

/// One bookable (time, worker) pair — the availability endpoint returns
/// these merged across every worker on shift, not grouped by worker, so two
/// workers free at the same time show up as two separate slots.
class AvailableSlot {
  const AvailableSlot({required this.workerId, required this.workerName, required this.startTime});

  final String workerId;
  final String workerName;
  final DateTime startTime;

  factory AvailableSlot.fromApiJson(Map<String, dynamic> json) {
    return AvailableSlot(
      workerId: json['worker_id'] as String,
      workerName: json['worker_name'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AvailableSlot && other.workerId == workerId && other.startTime == startTime;

  @override
  int get hashCode => Object.hash(workerId, startTime);
}

/// What a customer is told about a booking that will be cancelled if its
/// shop doesn't renew: shown from 30 days before, and reworded for the
/// last day.
String shopClosureNotice(AppLocalizations l10n, DateTime cancelledAt, DateTime now) {
  if (cancelledAt.difference(now) <= const Duration(days: 1)) return l10n.closureWithinADay;
  return l10n.closureBy(cancelledAt.toLocal());
}
