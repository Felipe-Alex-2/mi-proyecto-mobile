class Usuario {
  final String role;
  final String? tenantId;
  final String? selectedTenantId;
  final String? branchId;
  final String? companyName;
  final String? branchName;
  String get scopeKey =>
      '$id|${selectedTenantId ?? tenantId ?? "00000000-0000-0000-0000-000000000001"}|${branchId ?? ""}';
  final String avatarId;
  final String? profilePhoto;
  final String id;
  final String email;
  final String fullName;
  final bool isActive;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  Usuario({
    this.role = 'CUSTOMER',
    this.tenantId,
    this.selectedTenantId,
    this.branchId,
    this.companyName,
    this.branchName,
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

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      role: json["role"] ?? "CUSTOMER",
      tenantId: json["tenant_id"],
      selectedTenantId: json["selected_tenant_id"],
      branchId: json["branch_id"],
      companyName: json["company_name"],
      branchName: json["branch_name"],
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
      'role': role,
      'tenant_id': tenantId,
      'selected_tenant_id': selectedTenantId,
      'branch_id': branchId,
      'company_name': companyName,
      'branch_name': branchName,
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
