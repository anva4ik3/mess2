class User {
  final String id;
  final String email;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String? statusText;
  final bool isVerified;
  final bool isOnline;
  final DateTime? lastSeenAt;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.statusText,
    this.isVerified = false,
    this.isOnline = false,
    this.lastSeenAt,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'],
        email: j['email'] ?? '',
        username: j['username'],
        displayName: j['display_name'] ?? j['username'],
        avatarUrl: j['avatar_url'],
        bio: j['bio'],
        statusText: j['status_text'],
        isVerified: j['is_verified'] ?? false,
        isOnline: j['is_online'] ?? false,
        lastSeenAt: j['last_seen_at'] != null ? DateTime.parse(j['last_seen_at']) : null,
      );

  User copyWith({bool? isOnline, DateTime? lastSeenAt}) => User(
        id: id,
        email: email,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        bio: bio,
        statusText: statusText,
        isVerified: isVerified,
        isOnline: isOnline ?? this.isOnline,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      );
}
