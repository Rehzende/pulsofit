import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/review.dart';
import '../services/review_service.dart';

class ReviewProvider with ChangeNotifier {
  final ReviewService _reviewService;
  ReviewStats? _stats;
  Review? _myReview;
  bool _isLoading = false;

  ReviewProvider(Dio dio) : _reviewService = ReviewService(dio);

  ReviewStats? get stats => _stats;
  Review? get myReview => _myReview;
  bool get isLoading => _isLoading;

  Future<void> fetchTrainerReviews(String trainerId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _stats = await _reviewService.getTrainerReviews(trainerId);
    } catch (e) {
      debugPrint('Error fetching trainer reviews: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMyReview(String trainerId) async {
    try {
      _myReview = await _reviewService.getMyReview(trainerId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching my review: $e');
    }
  }

  Future<bool> submitReview({
    required String trainerId,
    required int rating,
    String? text,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final review = await _reviewService.createReview(
        trainerId: trainerId,
        rating: rating,
        text: text,
      );
      _myReview = review;
      // Refresh stats if we have them
      if (_stats != null) {
        await fetchTrainerReviews(trainerId);
      }
      return true;
    } catch (e) {
      debugPrint('Error submitting review: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
