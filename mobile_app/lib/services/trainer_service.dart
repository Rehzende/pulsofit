import 'package:dio/dio.dart';
import '../models/live_session.dart';
import '../models/trainer_stats.dart';
import '../models/user.dart';
import '../models/workout.dart';
import '../models/trainer_marketplace.dart';
import '../models/hiring_request.dart';
import '../models/student_engagement.dart';
import '../core/constants.dart';

class TrainerService {
  final Dio _dio;

  TrainerService(this._dio);

  Future<List<LiveSession>> getLiveSessions() async {
    try {
      final response = await _dio.get('${AppConstants.baseUrl}/trainer/live-sessions');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => LiveSession.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching live sessions: $e');
      return [];
    }
  }

  Future<TrainerStats?> getStats() async {
    try {
      final response = await _dio.get('${AppConstants.baseUrl}/trainer/stats');
      
      if (response.statusCode == 200) {
        return TrainerStats.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error fetching trainer stats: $e');
      return null;
    }
  }

  Future<List<User>> getStudents() async {
    try {
      final response = await _dio.get('${AppConstants.baseUrl}/trainer/students');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => User.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching students: $e');
      return [];
    }
  }

  Future<List<Workout>> getRecentWorkouts() async {
    try {
      final response = await _dio.get('${AppConstants.baseUrl}/workouts/?limit=5');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Workout.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching recent workouts: $e');
      return [];
    }
  }

  Future<List<TrainerMarketplaceItem>> getMarketplaceTrainers({String? specialty, String? name}) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (specialty != null) queryParams['specialty'] = specialty;
      if (name != null) queryParams['name'] = name;

      final response = await _dio.get(
        '${AppConstants.baseUrl}/marketplace/trainers',
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => TrainerMarketplaceItem.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching marketplace trainers: $e');
      return [];
    }
  }

  Future<TrainerMarketplaceItem?> getProfile() async {
    try {
      final response = await _dio.get('${AppConstants.baseUrl}/trainer/profile');
      
      if (response.statusCode == 200) {
        return TrainerMarketplaceItem.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error fetching profile: $e');
      return null;
    }
  }

  // Get specific trainer profile public
  Future<TrainerMarketplaceItem> getTrainerProfile(String trainerId) async {
    try {
      final response = await _dio.get('${AppConstants.baseUrl}/marketplace/trainers/$trainerId');
      return TrainerMarketplaceItem.fromJson(response.data);
    } catch (e) {
      print('Error fetching trainer profile: $e');
      rethrow;
    }
  }

  Future<void> updateProfile({
    String? bio,
    List<String>? specialties,
    List<String>? gyms,
    String? modality,
    double? hourlyRate,
    String? whatsappNumber,
    bool? isAvailableForHire,
  }) async {
    try {
      final data = {
        if (bio != null) 'bio': bio,
        if (specialties != null) 'specialties': specialties,
        if (gyms != null) 'gyms': gyms,
        if (modality != null) 'modality': modality,
        if (hourlyRate != null) 'hourly_rate': hourlyRate,
        if (whatsappNumber != null) 'whatsapp_number': whatsappNumber,
        if (isAvailableForHire != null) 'is_available_for_hire': isAvailableForHire,
      };

      await _dio.put(
        '${AppConstants.baseUrl}/trainer/profile',
        data: data,
      );
    } catch (e) {
      print('Error updating trainer profile: $e');
      rethrow;
    }
  }

  // Hiring Requests
  Future<void> sendHiringRequest(String trainerId) async {
    try {
      await _dio.post('${AppConstants.baseUrl}/marketplace/request/$trainerId');
    } catch (e) {
      print('Error sending hiring request: $e');
      rethrow;
    }
  }

  Future<List<HiringRequest>> getHiringRequests() async {
    try {
      final response = await _dio.get('${AppConstants.baseUrl}/marketplace/requests');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => HiringRequest.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching hiring requests: $e');
      return [];
    }
  }

  Future<void> acceptHiringRequest(String requestId) async {
    try {
      await _dio.put('${AppConstants.baseUrl}/marketplace/request/$requestId/accept');
    } catch (e) {
      print('Error accepting request: $e');
      rethrow;
    }
  }

  Future<void> rejectHiringRequest(String requestId) async {
    try {
      await _dio.put('${AppConstants.baseUrl}/marketplace/request/$requestId/reject');
    } catch (e) {
      print('Error rejecting request: $e');
      rethrow;
    }
  }

  Future<void> removeStudent(String studentId) async {
    try {
      await _dio.delete('${AppConstants.baseUrl}/trainer/students/$studentId');
    } catch (e) {
      print('Error removing student: $e');
      rethrow;
    }
  }

  Future<String?> createInvite(String email) async {
    try {
      final response = await _dio.post(
        '${AppConstants.baseUrl}/invites/',
        data: {'email': email},
      );
      
      if (response.statusCode == 200) {
        return response.data['invite_link'];
      }
      return null;
    } catch (e) {
      print('Error creating invite: $e');
      rethrow;
    }
  }

  Future<List<StudentEngagement>> getStudentEngagement() async {
    try {
      final response = await _dio.get('${AppConstants.baseUrl}/trainer/engagement');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => StudentEngagement.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching student engagement: $e');
      return [];
    }
  }
}
