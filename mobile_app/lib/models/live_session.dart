class LiveSession {
  final String sessionId;
  final String studentId;
  final String studentName;
  final String? studentAvatar;
  final String? studentPhone;
  final String workoutName;
  final DateTime startTime;
  final int? currentHeartRate;

  LiveSession({
    required this.sessionId,
    required this.studentId,
    required this.studentName,
    this.studentAvatar,
    this.studentPhone,
    required this.workoutName,
    required this.startTime,
    this.currentHeartRate,
  });

  factory LiveSession.fromJson(Map<String, dynamic> json) {
    return LiveSession(
      sessionId: json['session_id'],
      studentId: json['student_id'],
      studentName: json['student_name'],
      studentAvatar: json['student_avatar'],
      studentPhone: json['student_phone'],
      workoutName: json['workout_name'],
      startTime: DateTime.parse(json['start_time']),
      currentHeartRate: json['current_heart_rate'],
    );
  }
}
