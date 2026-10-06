class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String language;
  final String? country;
  final String plan;
  final int creditBalance;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    required this.language,
    this.country,
    required this.plan,
    required this.creditBalance,
    required this.createdAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['display_name'] ?? '',
      avatarUrl: map['avatar_url'],
      language: map['language'] ?? 'es',
      country: map['country'],
      plan: map['plan'] ?? 'free',
      creditBalance: map['credit_balance'] ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  UserProfile copyWith({
    String? displayName,
    String? avatarUrl,
    String? language,
    String? plan,
    int? creditBalance,
  }) {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      language: language ?? this.language,
      country: country,
      plan: plan ?? this.plan,
      creditBalance: creditBalance ?? this.creditBalance,
      createdAt: createdAt,
    );
  }
}
