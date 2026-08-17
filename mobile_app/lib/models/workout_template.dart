// Workout Template model
import 'package:intl/intl.dart';

class WorkoutTemplate {
  final String id;
  final String trainerId;
  final String name;
  final String? description;
  final String? goal;
  final String? level;
  final DateTime createdAt;
  final List<WorkoutTemplateItem> items;

  WorkoutTemplate({
    required this.id,
    required this.trainerId,
    required this.name,
    this.description,
    this.goal,
    this.level,
    required this.createdAt,
    this.items = const [],
  });

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) {
    return WorkoutTemplate(
      id: json['id'].toString(),
      trainerId: json['trainer_id'].toString(),
      name: json['name'],
      description: json['description'],
      goal: json['goal'],
      level: json['level'],
      createdAt: DateTime.parse(json['created_at']),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => WorkoutTemplateItem.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trainer_id': trainerId,
      'name': name,
      'description': description,
      'goal': goal,
      'level': level,
      'created_at': createdAt.toIso8601String(),
      'items': items.map((e) => e.toJson()).toList(),
    };
  }

  String get exerciseCount => items.length.toString();

  String get formattedDate => DateFormat('dd/MM/yyyy').format(createdAt);
}

/// Exercise prescription within a workout template
class WorkoutTemplateItem {
  final String id;
  final String templateId;
  final String exerciseId;
  final String exerciseName;
  final int sets;
  final int? repsMin;
  final int? repsMax;
  final int? durationSeconds;
  final int restSeconds;
  final String? notes;
  final String methodologyType;
  final Map<String, dynamic>? methodologyParams;
  final String? supersetId;
  final int orderIndex;

  WorkoutTemplateItem({
    required this.id,
    required this.templateId,
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    this.repsMin,
    this.repsMax,
    this.durationSeconds,
    required this.restSeconds,
    this.notes,
    this.methodologyType = 'NORMAL',
    this.methodologyParams,
    this.supersetId,
    this.orderIndex = 0,
  });

  factory WorkoutTemplateItem.fromJson(Map<String, dynamic> json) {
    return WorkoutTemplateItem(
      id: json['id'].toString(),
      templateId: json['template_id'].toString(),
      exerciseId: json['exercise_id'].toString(),
      exerciseName: json['exercise_name'] ?? 'Unknown',
      sets: json['sets'] ?? 0,
      repsMin: json['reps_min'],
      repsMax: json['reps_max'],
      durationSeconds: json['duration_seconds'],
      restSeconds: json['rest_seconds'] ?? 60,
      notes: json['notes'],
      methodologyType: json['methodology_type'] ?? 'NORMAL',
      methodologyParams: json['methodology_params'],
      supersetId: json['superset_id']?.toString(),
      orderIndex: json['order_index'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'template_id': templateId,
      'exercise_id': exerciseId,
      'exercise_name': exerciseName,
      'sets': sets,
      'reps_min': repsMin,
      'reps_max': repsMax,
      'duration_seconds': durationSeconds,
      'rest_seconds': restSeconds,
      'notes': notes,
      'methodology_type': methodologyType,
      'methodology_params': methodologyParams,
      'superset_id': supersetId,
      'order_index': orderIndex,
    };
  }

  bool get isTimeBased => durationSeconds != null && durationSeconds! > 0;

  String get formattedDuration {
    if (durationSeconds == null) return '';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
