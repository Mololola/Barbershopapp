/// A review as shown on a shop page: the shop rating and comment, and who
/// wrote it.
class ShopReview {
  const ShopReview({required this.rating, this.comment, required this.username, required this.createdAt});

  final int rating;
  final String? comment;
  final String username;
  final DateTime createdAt;

  factory ShopReview.fromRow(Map<String, dynamic> row) {
    final comment = (row['shop_comment'] as String?)?.trim();
    return ShopReview(
      rating: row['shop_rating'] as int,
      comment: comment == null || comment.isEmpty ? null : comment,
      username: (row['customer'] as Map<String, dynamic>)['username'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
