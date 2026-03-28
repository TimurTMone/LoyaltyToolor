class AppUser {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? avatarUrl;
  final DateTime? birthDate;
  final bool isAdmin;

  AppUser({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.avatarUrl,
    this.birthDate,
    this.isAdmin = false,
  });

  /// Create an AppUser from the FastAPI backend JSON response.
  /// Maps `full_name` to `name`.
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      name: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'] as String)
          : null,
      isAdmin: json['is_admin'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': name,
        'phone': phone,
        'email': email,
        'avatar_url': avatarUrl,
        'birth_date': birthDate?.toIso8601String(),
      };
}
