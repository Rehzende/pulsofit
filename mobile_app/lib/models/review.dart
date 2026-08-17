class Review {
  final String id;
  final String trainerId;
  final String? studentId;
  final String? studentName;
  final String? studentPhoto;
  final int rating;
  final String? text;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.trainerId,
    this.studentId,
    this.studentName,
    this.studentPhoto,
    required this.rating,
    this.text,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'],
      trainerId: json['trainer_id'],
      studentId: json['student_id'],
      studentName: json['student_name'],
      studentPhoto: json['student_photo'],
      rating: json['rating'],
      text: json['text'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trainer_id': trainerId,
      'student_id': studentId,
      'student_name': studentName,
      'student_photo': studentPhoto,
      'rating': rating,
      'text': text,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class ReviewStats {
  final double averageRating;
  final int totalReviews;
  final List<Review> reviews;

  ReviewStats({
    required this.averageRating,
    required this.totalReviews,
    required this.reviews,
  });

  factory ReviewStats.fromJson(Map<String, dynamic> json) {
    return ReviewStats(
      averageRating: (json['average_rating'] as num).toDouble(),
      totalReviews: json['total_reviews'],
      reviews: (json['reviews'] as List).map((r) => Review.fromJson(r)).toList(),
    );
  }
}
