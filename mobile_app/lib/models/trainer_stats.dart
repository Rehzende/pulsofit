class TrainerStats {
  final int activeStudents;
  final int monthlyWorkouts;
  final double retentionRate;
  final int activeStreaks;
  final int totalWorkouts;
  final int avgAttendance;

  TrainerStats({
    required this.activeStudents,
    required this.monthlyWorkouts,
    required this.retentionRate,
    required this.activeStreaks,
    required this.totalWorkouts,
    required this.avgAttendance,
  });

  factory TrainerStats.fromJson(Map<String, dynamic> json) {
    return TrainerStats(
      activeStudents: json['active_students'] ?? 0,
      monthlyWorkouts: json['monthly_workouts'] ?? 0,
      retentionRate: (json['retention_rate'] ?? 0).toDouble(),
      activeStreaks: json['active_streaks'] ?? 0,
      totalWorkouts: json['total_workouts'] ?? 0,
      avgAttendance: json['avg_attendance'] ?? 0,
    );
  }
}
