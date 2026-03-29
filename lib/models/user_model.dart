/// ============================================================
/// UserModel — Supabase PostgreSQL serialization
///
/// Table: `users`
/// Primary key: `id` (UUID from Supabase Auth)
/// Uses snake_case column names matching PostgreSQL convention.
/// ============================================================

class UserModel {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final double totalKm;
  final int points;
  final String? currentFortressSector;
  final String? clanId;
  final String? photoUrl;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.totalKm = 0.0,
    this.points = 0,
    this.currentFortressSector,
    this.clanId,
    this.photoUrl,
    required this.createdAt,
  });

  /// Deserialize from Supabase row (Map<String, dynamic>).
  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      id: data['id'] as String,
      name: (data['name'] as String?) ?? '',
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      totalKm: ((data['total_km'] ?? 0) as num).toDouble(),
      points: (data['points'] ?? 0) as int,
      currentFortressSector: data['current_fortress_sector'] as String?,
      clanId: data['clan_id'] as String?,
      photoUrl: data['photo_url'] as String?,
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  /// Serialize for INSERT (includes id, Supabase does NOT auto-generate user UUIDs
  /// because we set it from auth.uid).
  Map<String, dynamic> toInsertMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'total_km': totalKm,
      'points': points,
      'current_fortress_sector': currentFortressSector,
      'clan_id': clanId,
      'photo_url': photoUrl,
    };
  }

  /// Serialize for UPDATE (partial fields, no id/created_at).
  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'total_km': totalKm,
      'points': points,
      'current_fortress_sector': currentFortressSector,
      'clan_id': clanId,
      'photo_url': photoUrl,
    };
  }

  UserModel copyWith({
    String? name,
    String? phone,
    String? email,
    double? totalKm,
    int? points,
    String? currentFortressSector,
    String? clanId,
    String? photoUrl,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      totalKm: totalKm ?? this.totalKm,
      points: points ?? this.points,
      currentFortressSector: currentFortressSector ?? this.currentFortressSector,
      clanId: clanId ?? this.clanId,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
    );
  }
}
