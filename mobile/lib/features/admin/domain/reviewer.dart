/// A customer considered for, or holding, the quality-reviewer reward tier
/// — mirrors backend/app/api/admin.py's Reviewer.
class Reviewer {
  const Reviewer({
    required this.id,
    required this.username,
    required this.reviews,
    required this.averageCommentLength,
    required this.lastReviewAt,
    required this.memberSince,
  });

  final String id;
  final String username;

  /// Reviews on completed bookings.
  final int reviews;

  /// Mean characters written across a review's optional comments.
  final int averageCommentLength;
  final DateTime? lastReviewAt;
  final DateTime memberSince;

  factory Reviewer.fromJson(Map<String, dynamic> json) => Reviewer(
        id: json['id'] as String,
        username: json['username'] as String,
        reviews: json['reviews'] as int,
        averageCommentLength: json['average_comment_length'] as int,
        lastReviewAt: json['last_review_at'] == null ? null : DateTime.parse(json['last_review_at'] as String),
        memberSince: DateTime.parse(json['member_since'] as String),
      );
}

class Reviewers {
  const Reviewers({required this.suggested, required this.promoted});

  final List<Reviewer> suggested;
  final List<Reviewer> promoted;

  factory Reviewers.fromJson(Map<String, dynamic> json) => Reviewers(
        suggested: [for (final r in json['suggested'] as List) Reviewer.fromJson(r as Map<String, dynamic>)],
        promoted: [for (final r in json['promoted'] as List) Reviewer.fromJson(r as Map<String, dynamic>)],
      );
}
