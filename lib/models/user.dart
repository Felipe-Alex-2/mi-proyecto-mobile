class User {
  final String avatarId;
  final String? profilePhoto;
  final String id;
  final String email;
  final String fullName;
  final bool isActive;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    this.avatarId = 'terracotta',
    this.profilePhoto,
    required this.id,
    required this.email,
    required this.fullName,
    required this.isActive,
    required this.isVerified,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      avatarId: json['avatar_id'] as String? ?? 'terracotta',
      profilePhoto: json['profile_photo'] as String?,
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      isActive: json['is_active'] as bool? ?? true,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'avatar_id': avatarId,
      'profile_photo': profilePhoto,
      'email': email,
      'full_name': fullName,
      'is_active': isActive,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
