class User {
  final String id;
  final String email;
  final String? fullName;
  final String? photoUrl;
  final String? role;
  final String? whatsappNumber;
  final int? xpPoints;
  final int? level;
  final int? currentStreak;

  final String? trainerBrandName;
  final String? trainerLogoUrl;
  final String? trainerPrimaryColor;
  final String? trainerWhatsappNumber;

  User({
    required this.id,
    required this.email,
    this.fullName,
    this.photoUrl,
    this.role,
    this.whatsappNumber,
    this.xpPoints,
    this.level,
    this.currentStreak,
    this.trainerBrandName,
    this.trainerLogoUrl,
    this.trainerPrimaryColor,
    this.trainerWhatsappNumber,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      email: json['email'],
      fullName: json['full_name'],
      photoUrl: json['photo_url'],
      role: json['role'],
      whatsappNumber: json['whatsapp_number'],
      xpPoints: json['xp_points'],
      level: json['level'],
      currentStreak: json['current_streak'],
      trainerBrandName: json['trainer_brand_name'],
      trainerLogoUrl: json['trainer_logo_url'],
      trainerPrimaryColor: json['trainer_primary_color'],
      trainerWhatsappNumber: json['trainer_whatsapp_number'],
    );
  }
}
