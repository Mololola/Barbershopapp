/// Curated list, with a required "Other" fallback for cuts not listed —
/// this is also what future ranking-by-haircut-type would bucket on.
const haircutTypes = [
  'Buzz Cut',
  'Crew Cut',
  'Fade',
  'Undercut',
  'Pompadour',
  'Quiff',
  'Slick Back',
  'Textured Crop',
  'Mullet',
  'Afro',
  'Bald/Shaved',
  'Beard Trim',
  'Other',
];

/// Each rating is independently omittable — see `review_screen.dart`'s
/// step-by-step flow — so a row can have some fields filled and others
/// null. One row is always written per booking once the flow finishes
/// (even if everything was omitted), so the customer isn't re-prompted.
class Review {
  const Review({
    this.id,
    required this.bookingId,
    required this.businessId,
    required this.workerId,
    required this.customerId,
    this.shopRating,
    this.shopComment,
    this.workerRating,
    this.workerComment,
    this.haircutRating,
    this.haircutComment,
    this.haircutType,
  });

  final String? id;
  final String bookingId;
  final String businessId;
  final String workerId;
  final String customerId;
  final int? shopRating;
  final String? shopComment;
  final int? workerRating;
  final String? workerComment;
  final int? haircutRating;
  final String? haircutComment;
  final String? haircutType;

  factory Review.fromRow(Map<String, dynamic> row) {
    return Review(
      id: row['id'] as String,
      bookingId: row['booking_id'] as String,
      businessId: row['business_id'] as String,
      workerId: row['worker_id'] as String,
      customerId: row['customer_id'] as String,
      shopRating: row['shop_rating'] as int?,
      shopComment: row['shop_comment'] as String?,
      workerRating: row['worker_rating'] as int?,
      workerComment: row['worker_comment'] as String?,
      haircutRating: row['haircut_rating'] as int?,
      haircutComment: row['haircut_comment'] as String?,
      haircutType: row['haircut_type'] as String?,
    );
  }
}
