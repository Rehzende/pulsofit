class WorkoutGroup {
  final String id;
  final String name;
  final String trainerId;
  final String? studentId;
  final String? trainerName;
  final DateTime createdAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;

  WorkoutGroup({
    required this.id,
    required this.name,
    required this.trainerId,
    this.studentId,
    this.trainerName,
    required this.createdAt,
    this.startDate,
    this.endDate,
    this.isActive = true,
  });

  factory WorkoutGroup.fromJson(Map<String, dynamic> json) {
    return WorkoutGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      trainerId: json['trainer_id'] as String,
      studentId: json['student_id'] as String?,
      trainerName: json['trainer_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date'] as String) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'trainer_id': trainerId,
      'student_id': studentId,
      'trainer_name': trainerName,
      'created_at': createdAt.toIso8601String(),
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': isActive,
    };
  }

  /// Check if group has expired (today is after end_date)
  bool get isExpired => endDate != null && DateTime.now().isAfter(endDate!);
}
