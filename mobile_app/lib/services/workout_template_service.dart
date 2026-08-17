import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import '../models/workout_template.dart';
import '../models/workout.dart';

class WorkoutTemplateService {
  final Dio _dio;

  WorkoutTemplateService(this._dio);

  /// Get all templates created by the current trainer
  Future<List<WorkoutTemplate>> getMyTemplates() async {
    try {
      final response = await _dio.get(
        '${AppConstants.baseUrl}/workout-templates/my',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data.map((json) => WorkoutTemplate.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching templates: $e');
      rethrow;
    }
  }

  /// Create a new workout template
  Future<WorkoutTemplate?> createTemplate(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        '${AppConstants.baseUrl}/workout-templates/',
        data: data,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return WorkoutTemplate.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('Error creating template: $e');
      rethrow;
    }
  }

  /// Get a specific template by ID
  Future<WorkoutTemplate?> getTemplate(String templateId) async {
    try {
      final response = await _dio.get(
        '${AppConstants.baseUrl}/workout-templates/$templateId',
      );

      if (response.statusCode == 200) {
        return WorkoutTemplate.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching template: $e');
      rethrow;
    }
  }

  /// Update an existing template
  Future<WorkoutTemplate?> updateTemplate(
    String templateId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.put(
        '${AppConstants.baseUrl}/workout-templates/$templateId',
        data: data,
      );

      if (response.statusCode == 200) {
        return WorkoutTemplate.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('Error updating template: $e');
      rethrow;
    }
  }

  /// Delete a template
  Future<bool> deleteTemplate(String templateId) async {
    try {
      final response = await _dio.delete(
        '${AppConstants.baseUrl}/workout-templates/$templateId',
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting template: $e');
      rethrow;
    }
  }

  /// Apply a template to a student (creates a real Workout)
  Future<Workout?> applyTemplate(
    String templateId,
    String studentId, {
    DateTime? scheduledFor,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConstants.baseUrl}/workout-templates/$templateId/apply',
        data: {
          'student_id': studentId,
          if (scheduledFor != null) 'scheduled_for': scheduledFor.toIso8601String(),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Workout.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('Error applying template: $e');
      rethrow;
    }
  }
}
