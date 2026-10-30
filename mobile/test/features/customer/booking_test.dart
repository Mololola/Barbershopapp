import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/customer/domain/booking.dart';

void main() {
  const row = {
    'id': 'b1',
    'business_id': 'shop-1',
    'worker_id': 'w1',
    'service_id': 's1',
    'customer_id': 'c1',
    'start_time': '2026-11-02T10:00:00Z',
    'end_time': '2026-11-02T10:30:00Z',
    'status': 'confirmed',
    'price_cents': 1500,
  };

  test('a booking row reads the embedded service, barber and customer names', () {
    final booking = Booking.fromSupabaseRow({
      ...row,
      'services': {'name': 'Skin fade'},
      'workers': {'name': 'Sam'},
      'profiles': {'username': 'jordan'},
    });

    expect((booking.serviceName, booking.workerName, booking.customerName, booking.priceCents),
        ('Skin fade', 'Sam', 'jordan', 1500));
  });

  test('a row saved offline before the names were embedded still reads', () {
    final booking = Booking.fromSupabaseRow(row);

    expect((booking.serviceName, booking.workerName, booking.customerName), (null, null, null));
  });
}
