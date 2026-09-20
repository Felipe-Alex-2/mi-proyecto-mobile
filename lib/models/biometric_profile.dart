class BiometricProfile {
  final String? id;
  final String? userId;
  final String gender;
  final double heightCm;
  final double weightKg;
  final double chestCm;
  final double waistCm;
  final double hipCm;
  final String? photoUrl;

  const BiometricProfile({
    this.id,
    this.userId,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.chestCm,
    required this.waistCm,
    required this.hipCm,
    this.photoUrl,
  });

  factory BiometricProfile.fromJson(Map<String, dynamic> json) {
    return BiometricProfile(
      id: json['id'] as String?,
      userId: json['user_id'] as String?,
      gender: (json['gender'] as String?)?.toUpperCase() ?? 'HOMBRE',
      heightCm: (json['height_cm'] as num?)?.toDouble() ?? 170.0,
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 70.0,
      chestCm: (json['chest_cm'] as num?)?.toDouble() ?? 95.0,
      waistCm: (json['waist_cm'] as num?)?.toDouble() ?? 82.0,
      hipCm: (json['hip_cm'] as num?)?.toDouble() ?? 98.0,
      photoUrl: json['photo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gender': gender,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'chest_cm': chestCm,
      'waist_cm': waistCm,
      'hip_cm': hipCm,
      if (photoUrl != null) 'photo_url': photoUrl,
    };
  }

  BiometricProfile copyWith({
    String? id,
    String? userId,
    String? gender,
    double? heightCm,
    double? weightKg,
    double? chestCm,
    double? waistCm,
    double? hipCm,
    String? photoUrl,
  }) {
    return BiometricProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      chestCm: chestCm ?? this.chestCm,
      waistCm: waistCm ?? this.waistCm,
      hipCm: hipCm ?? this.hipCm,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
