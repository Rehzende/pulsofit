class StudentEngagement {
  final String studentId;
  final String studentName;
  final String? studentEmail;
  final String? photoUrl;
  final int currentStreak;
  final int sessionsLast7Days;
  final int? daysSinceLastSession;
  final DateTime? lastSessionDate;
  final String riskLevel; // AT_RISK | IRREGULAR | ON_TRACK
  final int engagementScore;
  final int upcomingWorkoutsCount;

  StudentEngagement({
    required this.studentId,
    required this.studentName,
    this.studentEmail,
    this.photoUrl,
    required this.currentStreak,
    required this.sessionsLast7Days,
    this.daysSinceLastSession,
    this.lastSessionDate,
    required this.riskLevel,
    required this.engagementScore,
    required this.upcomingWorkoutsCount,
  });

  factory StudentEngagement.fromJson(Map<String, dynamic> json) {
    return StudentEngagement(
      studentId: json['student_id'],
      studentName: json['student_name'],
      studentEmail: json['student_email'],
      photoUrl: json['photo_url'],
      currentStreak: json['current_streak'] ?? 0,
      sessionsLast7Days: json['sessions_last_7_days'] ?? 0,
      daysSinceLastSession: json['days_since_last_session'],
      lastSessionDate: json['last_session_date'] != null 
          ? DateTime.parse(json['last_session_date']) 
          : null,
      riskLevel: json['risk_level'] ?? 'ON_TRACK',
      engagementScore: json['engagement_score'] ?? 0,
      upcomingWorkoutsCount: json['upcoming_workouts_count'] ?? 0,
    );
  }
}
