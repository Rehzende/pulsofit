import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../models/review.dart';

class ReviewService {
  final Dio _dio;

  ReviewService(this._dio);

  Future<Review> createReview({
    required String trainerId,
    required int rating,
    String? text,
  }) async {
    final response = await _dio.post(
      '${AppConstants.baseUrl}/reviews/',
      data: {
        'trainer_id': trainerId,
        'rating': rating,
        'text': text,
      },
    );
    return Review.fromJson(response.data);
  }

  Future<ReviewStats> getTrainerReviews(String trainerId) async {
    final response = await _dio.get('${AppConstants.baseUrl}/reviews/trainer/$trainerId');
    return ReviewStats.fromJson(response.data);
  }

  Future<Review?> getMyReview(String trainerId) async {
    final response = await _dio.get('${AppConstants.baseUrl}/reviews/my-review/$trainerId');
    if (response.data == null) return null;
    return Review.fromJson(response.data);
  }
}
