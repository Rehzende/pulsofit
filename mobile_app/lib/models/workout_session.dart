class WorkoutSession {
  final String id;
  final String workoutId;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final String status; // 'IN_PROGRESS', 'COMPLETED'
  final int? durationSeconds;
  final int? averageHeartRate;
  final double? caloriesBurned;
  final int? xpEarned;
  final List<Map<String, dynamic>> heartRateData;
  final Map<String, dynamic>? progressData;
  final List<Map<String, dynamic>>? workoutSnapshot;

  WorkoutSession({
    required this.id,
    required this.workoutId,
    required this.userId,
    required this.startTime,
    this.endTime,
    required this.status,
    this.durationSeconds,
    this.averageHeartRate,
    this.caloriesBurned,
    this.xpEarned,
    this.heartRateData = const [],
    this.progressData,
    this.workoutSnapshot,
  });

  /// Check if session is recently active (within 6 hours)
  /// Sessions older than 6 hours with IN_PROGRESS status are likely abandoned
  bool get isRecentlyActive {
    if (status != 'IN_PROGRESS') return false;
    final sixHoursAgo = DateTime.now().subtract(const Duration(hours: 6));
    return startTime.isAfter(sixHoursAgo);
  }

  /// Parse a datetime string from the backend.
  /// Backend stores TIMESTAMP WITHOUT TIME ZONE in UTC, so the serialized
  /// string usually has no 'Z' suffix. We treat it as UTC and convert to local.
  static DateTime _parseUtc(String s) {
    final parsed = DateTime.parse(s);
    if (parsed.isUtc) return parsed.toLocal();
    // No tz info — backend convention is UTC, mark as UTC then convert to local
    return DateTime.utc(
      parsed.year, parsed.month, parsed.day,
      parsed.hour, parsed.minute, parsed.second,
      parsed.millisecond, parsed.microsecond,
    ).toLocal();
  }

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    final caloriesRaw = json['calories_burned'];
    return WorkoutSession(
      id: json['id'].toString(),
      workoutId: json['workout_id'].toString(),
      userId: json['user_id'].toString(),
      startTime: _parseUtc(json['start_time']),
      endTime: json['end_time'] != null ? _parseUtc(json['end_time']) : null,
      status: json['status'],
      durationSeconds: json['duration_seconds'],
      averageHeartRate: json['average_heart_rate'],
      caloriesBurned: (caloriesRaw is num) ? caloriesRaw.toDouble() : null,
      xpEarned: json['xp_earned'],
      heartRateData: (json['heart_rate_data'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      progressData: json['progress_data'] as Map<String, dynamic>?,
      workoutSnapshot: (json['workout_snapshot'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workout_id': workoutId,
      'user_id': userId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'status': status,
      'duration_seconds': durationSeconds,
      'average_heart_rate': averageHeartRate,
      'calories_burned': caloriesBurned,
      'xp_earned': xpEarned,
      'heart_rate_data': heartRateData,
      'progress_data': progressData,
      'workout_snapshot': workoutSnapshot,
    };
  }
}
