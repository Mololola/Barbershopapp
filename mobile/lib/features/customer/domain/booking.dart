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
  });

  final String id;
  final String businessId;
  final String workerId;
  final String serviceId;
  final String customerId;
  final DateTime startTime;
  final DateTime endTime;
  final BookingStatus status;

  /// Populated client-side by joining against already-fetched business/
  /// service/worker lists — the backend response itself only has ids.
  final String? businessName;
  final String? serviceName;
  final String? workerName;

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
    );
  }
}
