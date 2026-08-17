class TrainerMarketplaceItem {
  final String userId;
  final String fullName;
  final String? photoUrl;
  final String? brandName;
  final String? logoUrl;
  final String? bio;
  final String? modality; // 'presencial', 'online', 'hibrido'
  final List<String>? specialties;
  final List<String>? gyms;
  final double? hourlyRate;
  final String? whatsappNumber;
  final bool isAvailableForHire;
  final String requestStatus; // 'NONE', 'PENDING', 'ACCEPTED', 'REJECTED'
  final double? averageRating; // 1–5, one decimal; null when no reviews
  final int totalReviews;
  final bool isVerified;

  TrainerMarketplaceItem({
    required this.userId,
    required this.fullName,
    this.photoUrl,
    this.brandName,
    this.logoUrl,
    this.bio,
    this.modality,
    this.specialties,
    this.gyms,
    this.hourlyRate,
    this.whatsappNumber,
    this.isAvailableForHire = false,
    this.requestStatus = 'NONE',
    this.averageRating,
    this.totalReviews = 0,
    this.isVerified = false,
  });

  factory TrainerMarketplaceItem.fromJson(Map<String, dynamic> json) {
    return TrainerMarketplaceItem(
      userId: json['user_id'] ?? '',
      fullName: json['full_name'] ?? 'Treinador', // Fallback if full_name is missing in some contexts
      photoUrl: json['photo_url'],
      brandName: json['brand_name'],
      logoUrl: json['logo_url'],
      bio: json['bio'],
      modality: json['modality'],
      specialties: json['specialties'] != null
          ? (json['specialties'] is List ? List<String>.from(json['specialties']) : (json['specialties'] as String).split(','))
          : null,
      gyms: json['gyms'] != null
          ? (json['gyms'] is List ? List<String>.from(json['gyms']) : (json['gyms'] as String).split(','))
          : null,
      hourlyRate: json['hourly_rate'] != null
          ? (json['hourly_rate'] as num).toDouble()
          : null,
      whatsappNumber: json['whatsapp_number'],
      isAvailableForHire: json['is_available_for_hire'] ?? false,
      requestStatus: json['request_status'] ?? 'NONE',
      averageRating: (json['average_rating'] as num?)?.toDouble(),
      totalReviews: (json['total_reviews'] as num?)?.toInt() ?? 0,
      isVerified: json['is_verified'] == true,
    );
  }
}
