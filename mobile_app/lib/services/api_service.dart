import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';

class ApiService {
  final Dio _dio;

  ApiService(this._dio);

  Future<Map<String, String>> getRecoveryStatus() async {
    try {
      debugPrint('Fetching recovery status from: ${AppConstants.studentEndpoint}/recovery');
      final response = await _dio.get('${AppConstants.studentEndpoint}/recovery');
      
      debugPrint('Recovery status response code: ${response.statusCode}');
      debugPrint('Recovery status response data: ${response.data}');
      
      if (response.statusCode == 200) {
        return Map<String, String>.from(response.data);
      }
      
      return {};
    } on DioException catch (e) {
      debugPrint('DioException fetching recovery status:');
      debugPrint('  Status code: ${e.response?.statusCode}');
      debugPrint('  Response data: ${e.response?.data}');
      debugPrint('  Message: ${e.message}');
      debugPrint('  Type: ${e.type}');
      rethrow; // Re-throw to let the widget handle it
    } catch (e) {
      debugPrint('Error fetching recovery status: $e');
      rethrow;
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      await _dio.put('${AppConstants.usersEndpoint}/me', data: data);
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }
}
