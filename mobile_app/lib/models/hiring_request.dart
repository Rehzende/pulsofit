class HiringRequest {
  final String id;
  final String studentId;
  final String trainerId;
  final String status;
  final DateTime createdAt;
  final String? studentName;
  final String? studentPhoto;

  HiringRequest({
    required this.id,
    required this.studentId,
    required this.trainerId,
    required this.status,
    required this.createdAt,
    this.studentName,
    this.studentPhoto,
  });

  factory HiringRequest.fromJson(Map<String, dynamic> json) {
    return HiringRequest(
      id: json['id'].toString(),
      studentId: json['student_id'].toString(),
      trainerId: json['trainer_id'].toString(),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      studentName: json['student_name'],
      studentPhoto: json['student_photo'],
    );
  }
}
