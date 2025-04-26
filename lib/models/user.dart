import 'dart:convert';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final String role;
  final String? phone;
  final String? gender;
  final String? birthday;
  final String? school;
  final String? profileImage;
  final String createdAt;
  final List<String>? teams;
  final List<String>? competitions;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.role,
    this.phone,
    this.gender,
    this.birthday,
    this.school,
    this.profileImage,
    required this.createdAt,
    this.teams,
    this.competitions,
  });

  // 從 Firestore Map 創建用戶模型
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      role: map['role'] ?? '公眾',
      phone: map['phone'],
      gender: map['gender'],
      birthday: map['birthday'],
      school: map['school'],
      profileImage: map['profileImage'],
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      teams: map['teams'] != null ? List<String>.from(map['teams']) : null,
      competitions: map['competitions'] != null
          ? List<String>.from(map['competitions'])
          : null,
    );
  }

  // 從 Firestore Document 創建用戶模型
  factory UserModel.fromDoc(dynamic doc) {
    return UserModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  // 從 JSON 字符串創建用戶模型
  factory UserModel.fromJson(String json) {
    return UserModel.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }

  // 轉換為 Map，用於存儲到 Firestore
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = {
      'uid': uid,
      'email': email,
      'username': username,
      'role': role,
      'createdAt': createdAt,
    };

    // 僅當非空時添加可選字段
    if (phone != null) data['phone'] = phone;
    if (gender != null) data['gender'] = gender;
    if (birthday != null) data['birthday'] = birthday;
    if (school != null) data['school'] = school;
    if (profileImage != null) data['profileImage'] = profileImage;
    if (teams != null) data['teams'] = teams;
    if (competitions != null) data['competitions'] = competitions;

    return data;
  }

  // 轉換為 JSON 字符串
  String toJson() {
    return jsonEncode(toMap());
  }

  // 創建帶有更新字段的新實例
  UserModel copyWith({
    String? uid,
    String? email,
    String? username,
    String? role,
    String? phone,
    String? gender,
    String? birthday,
    String? school,
    String? profileImage,
    String? createdAt,
    List<String>? teams,
    List<String>? competitions,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      school: school ?? this.school,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      teams: teams ?? this.teams,
      competitions: competitions ?? this.competitions,
    );
  }

  @override
  String toString() {
    return 'UserModel{uid: $uid, email: $email, username: $username, role: $role}';
  }
}
