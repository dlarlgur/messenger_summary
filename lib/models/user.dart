class User {
  final int? id;
  final String? naverId;  // 네이버 로그인용
  final String? kakaoId;  // 카카오 로그인용 (하위 호환)
  final String nickName;
  final String? profileImageUrl;
  final DateTime? createdAt;

  User({
    this.id,
    this.naverId,
    this.kakaoId,
    required this.nickName,
    this.profileImageUrl,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      naverId: json['naverId'],
      kakaoId: json['kakaoId'],
      nickName: json['nickName'] ?? '',
      profileImageUrl: json['profileImageUrl'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'naverId': naverId,
      'kakaoId': kakaoId,
      'nickName': nickName,
      'profileImageUrl': profileImageUrl,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
