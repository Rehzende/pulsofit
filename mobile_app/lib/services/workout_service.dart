import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../models/workout_group.dart';

/// Service for workout-related API calls
class WorkoutService {
  final Dio _dio;

  WorkoutService(this._dio);

  /// Get all workouts for the current user or a specific student
  Future<List<Workout>> getWorkouts({String? studentId}) async {
    if (await _isOnline()) {
      try {
        final Map<String, dynamic> queryParams = {};
        if (studentId != null) {
          queryParams['student_id'] = studentId;
        }

        final response = await _dio.get(
          '${AppConstants.workoutsEndpoint}/',
          queryParameters: queryParams,
        );
        
        if (response.statusCode == 200) {
          final List<dynamic> data = response.data;
          // Only cache if fetching own workouts (no studentId)
          if (studentId == null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('cached_workouts', jsonEncode(data));
          }
          
          return data.map((json) => Workout.fromJson(json)).toList();
        }
      } catch (e) {
        debugPrint('Error fetching workouts online: $e');
        // Fallback to cache if API fails AND we are fetching own workouts
        if (studentId != null) return [];
      }
    }
    
    // Load from cache (only for own workouts)
    if (studentId == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final String? cachedData = prefs.getString('cached_workouts');
        
        if (cachedData != null) {
          final List<dynamic> data = jsonDecode(cachedData);
          return data.map((json) => Workout.fromJson(json)).toList();
        }
      } catch (e) {
        debugPrint('Error loading cached workouts: $e');
      }
    }
    
    return [];
  }

  /// Get today's workout (first workout in the list for now)
  Future<Workout?> getTodayWorkout() async {
    try {
      final workouts = await getWorkouts();
      
      if (workouts.isNotEmpty) {
        // For now, return the first workout
        // In a real app, you'd filter by date or have a specific endpoint
        return workouts.first;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error fetching today\'s workout: $e');
      return null;
    }
  }

  /// Get a specific workout by ID
  Future<Workout?> getWorkout(String id) async {
    try {
      final response = await _dio.get('${AppConstants.workoutsEndpoint}/$id');
      
      if (response.statusCode == 200) {
        return Workout.fromJson(response.data);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error fetching workout $id: $e');
      return null;
    }
  }


  /// Start a workout session
  Future<WorkoutSession?> startWorkout(String workoutId) async {
    if (await _isOnline()) {
      try {
        final response = await _dio.post(
          '${AppConstants.baseUrl}/workout-sessions/start',
          data: {'workout_id': workoutId},
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return WorkoutSession.fromJson(response.data);
        }
      } catch (e) {
        debugPrint('Error starting workout online: $e');
      }
    }
    return null;
  }

  /// Finish a workout and save XP
  Future<Map<String, dynamic>?> finishWorkout(
    String workoutId,
    int durationSeconds,
    int averageHeartRate, {
    String? sessionId, // Added sessionId
    double? caloriesBurned,
    List<Map<String, dynamic>>? heartRateData,
    List<Map<String, dynamic>>? exercisesData,
  }) async {
    // Common payload data
    final Map<String, dynamic> payload = {
      'duration_seconds': durationSeconds,
      'average_heart_rate': averageHeartRate,
      if (caloriesBurned != null) 'calories_burned': caloriesBurned,
      if (heartRateData != null) 'heart_rate_data': heartRateData,
      if (exercisesData != null) 'exercises_data': exercisesData,
    };

    if (await _isOnline()) {
      try {
        Response response;
        
        if (sessionId != null) {
          // Finish existing session
          response = await _dio.post(
            '${AppConstants.baseUrl}/workout-sessions/$sessionId/finish',
            data: {
              ...payload,
              'end_time': DateTime.now().toUtc().toIso8601String(),
              // Add other fields if needed by WorkoutSessionUpdate
            },
          );
        } else {
          // Simple finish (create & finish)
          response = await _dio.post(
            '${AppConstants.baseUrl}/workout-sessions/finish',
            data: {
              'workout_id': workoutId,
              ...payload,
            },
          );
        }
        
        if (response.statusCode == 200) {
          return response.data as Map<String, dynamic>;
        }
        return null;
      } catch (e) {
        debugPrint('Error finishing workout online: $e');
        // Fallback to offline save
      }
    } 
    
    // Offline fallback: Always save as "pending simple finish" because we might not have a valid session ID if we started offline
    // Or if we started online but are now offline, we technically have a session ID, but the backend might expect a specific flow.
    // For simplicity, let's treat offline finishes as "simple finishes" that will create a new record when synced.
    // Ideally, we should try to sync the session ID if we have it, but that complicates the sync logic.
    // Let's stick to the existing offline logic which uses workout_id.

    final offlinePayload = {
      'workout_id': workoutId,
      // Keep the session id (when the workout was started online) so the sync
      // finishes THAT session instead of creating a duplicate record.
      if (sessionId != null) 'session_id': sessionId,
      ...payload,
    };

    await _savePendingWorkout(offlinePayload);

    // Mirror server response shape so WorkoutSummaryScreen renders the same
    // stats (calories, XP, etc.) instead of falling back to "--".
    final estimatedXp = 100 + (durationSeconds ~/ 60);
    return {
      'offline': true,
      'message': 'Workout saved locally',
      'calories_burned': caloriesBurned,
      'average_heart_rate': averageHeartRate,
      'xp_earned': estimatedXp,
      'current_streak': 0,
      'is_new_streak_record': false,
      'share_context': null,
    };
  }

  Future<bool> _isOnline() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _savePendingWorkout(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> pending = prefs.getStringList('pending_workouts') ?? [];

    data['timestamp'] = DateTime.now().toUtc().toIso8601String();
    
    pending.add(jsonEncode(data));
    await prefs.setStringList('pending_workouts', pending);
    debugPrint('Workout saved locally: ${data['workout_id']}');
  }

  bool _isSyncing = false;

  Future<void> syncPendingWorkouts() async {
    // Guard against concurrent syncs (multiple reconnect triggers) which would
    // POST the same pending items twice before the list is cleared.
    if (_isSyncing) return;
    if (!await _isOnline()) return;

    _isSyncing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> pending = prefs.getStringList('pending_workouts') ?? [];

      if (pending.isEmpty) return;

      final List<String> remaining = [];

      for (final jsonStr in pending) {
        try {
          final data = jsonDecode(jsonStr);
          final sessionId = data['session_id'];
          if (sessionId != null) {
            // Session already created online → finish it (update), never create
            // a second record.
            await _dio.post(
              '${AppConstants.baseUrl}/workout-sessions/$sessionId/finish',
              data: {
                'duration_seconds': data['duration_seconds'],
                'average_heart_rate': data['average_heart_rate'],
                if (data.containsKey('calories_burned')) 'calories_burned': data['calories_burned'],
                if (data.containsKey('heart_rate_data')) 'heart_rate_data': data['heart_rate_data'],
                if (data.containsKey('exercises_data')) 'exercises_data': data['exercises_data'],
                'end_time': data['timestamp'] ?? DateTime.now().toUtc().toIso8601String(),
              },
            );
          } else {
            // Started offline (no session yet) → create & finish in one call.
            await _dio.post(
              '${AppConstants.baseUrl}/workout-sessions/finish',
              data: {
                'workout_id': data['workout_id'],
                'duration_seconds': data['duration_seconds'],
                'average_heart_rate': data['average_heart_rate'],
                if (data.containsKey('calories_burned')) 'calories_burned': data['calories_burned'],
                if (data.containsKey('heart_rate_data')) 'heart_rate_data': data['heart_rate_data'],
                if (data.containsKey('exercises_data')) 'exercises_data': data['exercises_data'],
              },
            );
          }
          debugPrint('Synced workout: ${data['workout_id']}');
        } catch (e) {
          debugPrint('Error syncing workout: $e');
          remaining.add(jsonStr); // Keep it if it failed
        }
      }

      await prefs.setStringList('pending_workouts', remaining);
    } finally {
      _isSyncing = false;
    }
  }

  // ========== Workout Groups ==========

  /// Get all workout groups, optionally filtered by student_id
  Future<List<WorkoutGroup>> getWorkoutGroups({String? studentId}) async {
    if (await _isOnline()) {
      try {
        final Map<String, dynamic> queryParams = {};
        if (studentId != null) {
          queryParams['student_id'] = studentId;
        }

        final response = await _dio.get(
          '${AppConstants.baseUrl}/workout-groups/',
          queryParameters: queryParams,
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = response.data;
          // Cache the data only if fetching all groups (no student filter)
          if (studentId == null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('cached_workout_groups', jsonEncode(data));
          }

          return data.map((json) => WorkoutGroup.fromJson(json)).toList();
        }
      } catch (e) {
        debugPrint('Error fetching workout groups online: $e');
      }
    }

    // Load from cache only if fetching all groups
    if (studentId == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final String? cachedData = prefs.getString('cached_workout_groups');

        if (cachedData != null) {
          final List<dynamic> data = jsonDecode(cachedData);
          return data.map((json) => WorkoutGroup.fromJson(json)).toList();
        }
      } catch (e) {
        debugPrint('Error loading cached workout groups: $e');
      }
    }

    return [];
  }

  /// Create a new workout group
  Future<WorkoutGroup?> createWorkoutGroup(
    String name, {
    String? studentId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConstants.baseUrl}/workout-groups/',
        data: {
          'name': name,
          if (studentId != null) 'student_id': studentId,
          'start_date': startDate?.toIso8601String(),
          'end_date': endDate?.toIso8601String(),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return WorkoutGroup.fromJson(response.data);
      }

      return null;
    } catch (e) {
      debugPrint('Error creating workout group: $e');
      rethrow;
    }
  }

  /// Update a workout group
  Future<WorkoutGroup?> updateWorkoutGroup(
    String id,
    String name, {
    String? studentId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _dio.put(
        '${AppConstants.baseUrl}/workout-groups/$id',
        data: {
          'name': name,
          if (studentId != null) 'student_id': studentId,
          'start_date': startDate?.toIso8601String(),
          'end_date': endDate?.toIso8601String(),
        },
      );

      if (response.statusCode == 200) {
        return WorkoutGroup.fromJson(response.data);
      }

      return null;
    } catch (e) {
      debugPrint('Error updating workout group: $e');
      rethrow;
    }
  }

  /// Archive a workout group
  Future<WorkoutGroup?> archiveWorkoutGroup(String id) async {
    try {
      final response = await _dio.patch(
        '${AppConstants.baseUrl}/workout-groups/$id/archive',
      );

      if (response.statusCode == 200) {
        return WorkoutGroup.fromJson(response.data);
      }

      return null;
    } catch (e) {
      debugPrint('Error archiving workout group: $e');
      rethrow;
    }
  }

  /// Unarchive a workout group
  Future<WorkoutGroup?> unarchiveWorkoutGroup(String id) async {
    try {
      final response = await _dio.patch(
        '${AppConstants.baseUrl}/workout-groups/$id/unarchive',
      );

      if (response.statusCode == 200) {
        return WorkoutGroup.fromJson(response.data);
      }

      return null;
    } catch (e) {
      debugPrint('Error unarchiving workout group: $e');
      rethrow;
    }
  }

  /// Move a workout to a different group
  Future<Workout?> moveWorkoutToGroup(String workoutId, String groupId) async {
    try {
      final response = await _dio.put(
        '${AppConstants.workoutsEndpoint}/$workoutId',
        data: {'group_id': groupId},
      );
      if (response.statusCode == 200) {
        return Workout.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('Error moving workout to group: $e');
      rethrow;
    }
  }

  /// Update a workout (name + items)
  Future<Workout?> updateWorkout(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(
        '${AppConstants.workoutsEndpoint}/$id',
        data: data,
      );
      if (response.statusCode == 200) {
        return Workout.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('Error updating workout: $e');
      rethrow;
    }
  }

  /// Delete a workout
  Future<bool> deleteWorkout(String id) async {
    try {
      final response = await _dio.delete('${AppConstants.baseUrl}/workouts/$id');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error deleting workout: $e');
      rethrow;
    }
  }

  /// Delete a workout group
  Future<bool> deleteWorkoutGroup(String id) async {
    try {
      final response = await _dio.delete('${AppConstants.baseUrl}/workout-groups/$id');
      
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error deleting workout group: $e');
      rethrow;
    }
  }

  /// Get weekly status
  Future<Map<String, dynamic>?> getWeeklyStatus() async {
    if (await _isOnline()) {
      try {
        final response = await _dio.get('${AppConstants.workoutsEndpoint}/weekly-status');
        
        if (response.statusCode == 200) {
          return response.data as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('Error fetching weekly status: $e');
      }
    }
    return null;
  }

  /// Get pending (offline) sessions converted to WorkoutSession objects
  Future<List<WorkoutSession>> getPendingSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> pending = prefs.getStringList('pending_workouts') ?? [];
    
    return pending.map((jsonStr) {
      final data = jsonDecode(jsonStr);
      // Create a temporary session object from pending data
      return WorkoutSession(
        id: 'pending_${data['timestamp']}', // Temporary ID
        workoutId: data['workout_id'].toString(),
        userId: '', // Not needed for display
        startTime: DateTime.parse(data['timestamp']),
        endTime: DateTime.parse(data['timestamp']),
        status: 'pending',
        durationSeconds: data['duration_seconds'],
        averageHeartRate: data['average_heart_rate'],
        caloriesBurned: data['calories_burned'],
        xpEarned: 0, // Not calculated yet
        heartRateData: (data['heart_rate_data'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ?? [],
      );
    }).toList();
  }

  /// Delete a workout session (pending or synced)
  Future<bool> deleteSession(String sessionId) async {
    // Check if this is a pending (offline) session
    if (sessionId.startsWith('pending_')) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final List<String> pending = prefs.getStringList('pending_workouts') ?? [];

        // Find and remove the pending workout by timestamp
        final timestamp = sessionId.replaceFirst('pending_', '');
        final updatedPending = pending.where((jsonStr) {
          final data = jsonDecode(jsonStr);
          return data['timestamp'] != timestamp;
        }).toList();

        await prefs.setStringList('pending_workouts', updatedPending);
        debugPrint('Pending workout deleted: $sessionId');
        return true;
      } catch (e) {
        debugPrint('Error deleting pending session: $e');
        return false;
      }
    }

    // Delete synced session from backend
    if (await _isOnline()) {
      try {
        final response = await _dio.delete('${AppConstants.baseUrl}/workout-sessions/history/$sessionId');
        if (response.statusCode == 200) {
           // Invalidate cache
           final prefs = await SharedPreferences.getInstance();
           await prefs.remove('cached_workouts');
           return true;
        }
        return false;
      } catch (e) {
        debugPrint('Error deleting session: $e');
        return false;
      }
    }

    // If offline and not a pending session, cannot delete
    debugPrint('Cannot delete synced session while offline');
    return false;
  }

  /// Create a new workout
  Future<Workout?> createWorkout(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        '${AppConstants.workoutsEndpoint}/',
        data: data,
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Workout.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('Error creating workout: $e');
      rethrow;
    }
  }

  /// Get all exercises
  Future<List<dynamic>> getExercises() async {
    try {
      final response = await _dio.get('${AppConstants.baseUrl}/exercises/');
      if (response.statusCode == 200) {
        return response.data;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching exercises: $e');
      return [];
    }
  }

  /// Create a new exercise (trainer only)
  Future<Map<String, dynamic>?> createExercise({
    required String name,
    required String category,
    String? muscleGroup,
    String? videoUrl,
    String? description,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConstants.baseUrl}/exercises/',
        data: {
          'name': name,
          'category': category,
          if (muscleGroup != null) 'muscle_group': muscleGroup,
          if (videoUrl != null && videoUrl.isNotEmpty) 'video_url': videoUrl,
          if (description != null && description.isNotEmpty) 'description': description,
          'is_iot_compatible': false,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } catch (e) {
      debugPrint('Error creating exercise: $e');
      rethrow;
    }
  }

  /// Suggest similar exercises based on a query
  Future<List<dynamic>> suggestSimilarExercises(String query) async {
    try {
      final response = await _dio.get(
        '${AppConstants.baseUrl}/exercises/suggest-similar',
        queryParameters: {'q': query},
      );
      if (response.statusCode == 200) {
        return response.data;
      }
      return [];
    } catch (e) {
      debugPrint('Error suggesting exercises: $e');
      return [];
    }
  }

  /// Add an alias to an existing exercise
  Future<bool> addExerciseAlias(String exerciseId, String alias) async {
    try {
      final response = await _dio.patch(
        '${AppConstants.baseUrl}/exercises/$exerciseId/alias',
        data: {'alias': alias},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error adding exercise alias: $e');
      return false;
    }
  }

  /// Get list of favorited exercise IDs for current trainer
  Future<List<String>> getFavoriteExerciseIds() async {
    try {
      final response = await _dio.get('${AppConstants.baseUrl}/exercises/favorites/ids');
      if (response.statusCode == 200) {
        return List<String>.from(response.data);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching favorite IDs: $e');
      return [];
    }
  }

  /// Toggle favorite status of an exercise
  Future<bool?> toggleFavoriteExercise(String exerciseId) async {
    try {
      final response = await _dio.post('${AppConstants.baseUrl}/exercises/$exerciseId/favorite');
      if (response.statusCode == 200) {
        return response.data['is_favorite'] as bool;
      }
      return null;
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      return null;
    }
  }

  /// Get exercise groups for current trainer
  Future<List<dynamic>> getExerciseGroups() async {
    try {
      final response = await _dio.get('${AppConstants.baseUrl}/exercise-groups/');
      if (response.statusCode == 200) {
        return response.data;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching exercise groups: $e');
      return [];
    }
  }

  /// Create a new exercise group
  Future<Map<String, dynamic>?> createExerciseGroup({
    required String name,
    String? description,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConstants.baseUrl}/exercise-groups/',
        data: {
          'name': name,
          if (description != null && description.isNotEmpty) 'description': description,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } catch (e) {
      debugPrint('Error creating exercise group: $e');
      rethrow;
    }
  }
  /// Toggle favorite status of a workout
  Future<Workout?> toggleFavoriteWorkout(String workoutId) async {
    try {
      final response = await _dio.post('${AppConstants.workoutsEndpoint}/$workoutId/favorite');
      if (response.statusCode == 200) {
        return Workout.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('Error toggling workout favorite: $e');
      return null;
    }
  }

  /// Get workout history (completed sessions)
  Future<List<WorkoutSession>> getHistory() async {
    if (await _isOnline()) {
      try {
        final response = await _dio.get('${AppConstants.baseUrl}/workout-sessions/history');

        if (response.statusCode == 200) {
          final List<dynamic> data = response.data;
          return data.map((json) => WorkoutSession.fromJson(json)).toList();
        }
      } catch (e) {
        debugPrint('Error fetching history: $e');
      }
    }
    return [];
  }

  /// Get exercise progression history: all sessions with a specific exercise's per-set data
  Future<List<Map<String, dynamic>>> getExerciseHistory(String exerciseId) async {
    if (await _isOnline()) {
      try {
        final response = await _dio.get(
          '${AppConstants.baseUrl}/workout-sessions/exercise-history/$exerciseId'
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = response.data;
          return data.cast<Map<String, dynamic>>();
        }
      } catch (e) {
        debugPrint('Error fetching exercise history for $exerciseId: $e');
      }
    }
    return [];
  }
}
