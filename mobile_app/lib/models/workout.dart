// Workout model
import 'workout_session.dart';

class Workout {
  final String id;
  final String name;
  final String? description;
  final int? estimatedDuration; // in minutes
  final String? trainerId; // UUID
  final String studentId; // UUID
  final String? groupId; // UUID - workout group
  final DateTime? scheduledFor;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<Exercise> exercises;
  final List<WorkoutSession> sessions;
  final bool isFavorite;

  Workout({
    required this.id,
    required this.name,
    this.description,
    this.estimatedDuration,
    this.trainerId,
    required this.studentId,
    this.groupId,
    this.scheduledFor,
    this.startDate,
    this.endDate,
    this.exercises = const [],
    this.sessions = const [],
    this.isFavorite = false,
  });

  bool get isActive {
    if (endDate == null) return true;
    return endDate!.isAfter(DateTime.now());
  }

  bool get hasActiveSession =>
      sessions.any((s) => s.isRecentlyActive);

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'].toString(),
      name: json['name'],
      description: json['description'],
      estimatedDuration: json['estimated_duration'],
      trainerId: json['trainer_id']?.toString(),
      studentId: json['user_id']?.toString() ?? json['student_id']?.toString() ?? '',
      groupId: json['group_id']?.toString(),
      scheduledFor: json['scheduled_for'] != null ? DateTime.parse(json['scheduled_for']) : null,
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      exercises: (json['items'] as List<dynamic>?)
              ?.map((e) => Exercise.fromJson(e))
              .toList() ??
          [],
      sessions: (json['sessions'] as List<dynamic>?)
              ?.map((e) => WorkoutSession.fromJson(e))
              .toList() ??
          [],
      isFavorite: json['is_favorite'] as bool? ?? false,
    );
  }

  Workout copyWith({bool? isFavorite}) {
    return Workout(
      id: id,
      name: name,
      description: description,
      estimatedDuration: estimatedDuration,
      trainerId: trainerId,
      studentId: studentId,
      groupId: groupId,
      scheduledFor: scheduledFor,
      startDate: startDate,
      endDate: endDate,
      exercises: exercises,
      sessions: sessions,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'estimated_duration': estimatedDuration,
      'trainer_id': trainerId,
      'student_id': studentId,
      'group_id': groupId,
      'scheduled_for': scheduledFor?.toIso8601String(),
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'items': exercises.map((e) => e.toJson()).toList(),
      'sessions': sessions.map((e) => e.toJson()).toList(),
    };
  }
}

/// Exercise model
class Exercise {
  final String id;  // ID of the WorkoutItem
  final String exerciseId;  // ID of the actual exercise library item
  final String name;
  final int sets;
  final int? reps;  // Made optional for time-based exercises
  final List<int> repsPerSet;  // e.g. [12, 10, 8] — per-series reps; empty = use `reps`
  final int? durationSeconds;  // For cardio/time-based exercises
  final int? restSeconds;
  final String? notes;  // Instructions from trainer
  final int orderIndex;
  final String? supersetId;
  final String methodologyType;  // NORMAL, DROP_SET, REST_PAUSE, etc.
  final Map<String, dynamic>? methodologyParams;
  final List<String>? instructions;
  final String? videoUrl;
  final String? gifUrl;
  final String? equipmentPhotoUrl;
  final String? description;
  final List<String>? equipment;

  Exercise({
    required this.id,
    required this.exerciseId,
    required this.name,
    required this.sets,
    this.reps,
    this.repsPerSet = const [],
    this.durationSeconds,
    this.restSeconds,
    this.notes,
    required this.orderIndex,
    this.supersetId,
    this.methodologyType = 'NORMAL',
    this.methodologyParams,
    this.instructions,
    this.videoUrl,
    this.gifUrl,
    this.equipmentPhotoUrl,
    this.description,
    this.equipment,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'].toString(),
      exerciseId: json['exercise_id']?.toString() ?? json['id'].toString(),
      name: json['exercise_name'] ?? json['name'] ?? 'Unknown Exercise',
      sets: json['sets'] ?? 0,
      reps: json['reps_max'] ?? json['reps_min'] ?? json['reps'],
      repsPerSet: (json['reps_per_set'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      durationSeconds: json['duration_seconds'],
      restSeconds: json['rest_seconds'],
      notes: json['notes'],
      orderIndex: json['order_index'] ?? 0,
      supersetId: json['superset_id']?.toString(),
      methodologyType: json['methodology_type'] ?? 'NORMAL',
      methodologyParams: json['methodology_params'],
      instructions: (json['instructions'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      videoUrl: json['video_url'],
      gifUrl: json['gif_url'],
      equipmentPhotoUrl: json['equipment_photo_url'],
      description: json['description'],
      equipment: (json['equipment'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exercise_id': exerciseId,
      'name': name,
      'sets': sets,
      'reps': reps,
      'reps_per_set': repsPerSet,
      'duration_seconds': durationSeconds,
      'rest_seconds': restSeconds,
      'notes': notes,
      'order_index': orderIndex,
      'superset_id': supersetId,
      'methodology_type': methodologyType,
      'methodology_params': methodologyParams,
      'instructions': instructions,
    };
  }

  // Helper to check if this is a time-based exercise
  bool get isTimeBased => durationSeconds != null && durationSeconds! > 0;
  
  // Helper to get formatted duration
  String get formattedDuration {
    if (durationSeconds == null) return '';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

