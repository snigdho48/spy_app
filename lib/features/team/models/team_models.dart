class TeamMember {
  const TeamMember({
    required this.id,
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String email;
  final String fullName;
  final String role;
  final String? createdAt;

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    return TeamMember(
      id: json['id'].toString(),
      userId: user['id'].toString(),
      email: user['email'] as String? ?? '',
      fullName: user['full_name'] as String? ?? '',
      role: json['role'] as String? ?? 'viewer',
      createdAt: json['created_at'] as String?,
    );
  }
}

class PendingInvite {
  const PendingInvite({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    this.expiresAt,
    this.createdAt,
    this.inviteLink,
    this.token,
  });

  final String id;
  final String email;
  final String role;
  final String status;
  final String? expiresAt;
  final String? createdAt;
  final String? inviteLink;
  final String? token;

  factory PendingInvite.fromJson(Map<String, dynamic> json) {
    return PendingInvite(
      id: json['id'].toString(),
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'viewer',
      status: json['status'] as String? ?? 'pending',
      expiresAt: json['expires_at'] as String?,
      createdAt: json['created_at'] as String?,
      inviteLink: json['invite_link'] as String?,
      token: json['token'] as String?,
    );
  }
}

bool canManageTeam(String? role) =>
    role == 'owner' || role == 'admin';
