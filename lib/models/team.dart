import 'dart:convert';

class TeamModel {
  final String id;
  final String name;
  final String? description;
  final String? logo;
  final String createdBy; // 創建者 UID
  final String createdAt;
  final List<String> members; // 成員 UID 列表
  final List<String>? competitions; // 參與的賽事 ID 列表
  final String? school; // 學校/機構名稱
  final Map<String, dynamic>? metadata; // 其他元數據

  TeamModel({
    required this.id,
    required this.name,
    this.description,
    this.logo,
    required this.createdBy,
    required this.createdAt,
    required this.members,
    this.competitions,
    this.school,
    this.metadata,
  });

  // 從 Firestore Map 創建團隊模型
  factory TeamModel.fromMap(Map<String, dynamic> map) {
    return TeamModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      logo: map['logo'],
      createdBy: map['createdBy'] ?? '',
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      members: List<String>.from(map['members'] ?? []),
      competitions: map['competitions'] != null
          ? List<String>.from(map['competitions'])
          : null,
      school: map['school'],
      metadata: map['metadata'],
    );
  }

  // 從 Firestore Document 創建團隊模型
  factory TeamModel.fromDoc(dynamic doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    // 確保 ID 被設置，使用文檔 ID 如果數據中沒有提供
    data['id'] = data['id'] ?? doc.id;
    return TeamModel.fromMap(data);
  }

  // 從 JSON 字符串創建團隊模型
  factory TeamModel.fromJson(String json) {
    return TeamModel.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }

  // 轉換為 Map，用於存儲到 Firestore
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = {
      'id': id,
      'name': name,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'members': members,
    };

    if (description != null) data['description'] = description;
    if (logo != null) data['logo'] = logo;
    if (competitions != null) data['competitions'] = competitions;
    if (school != null) data['school'] = school;
    if (metadata != null) data['metadata'] = metadata;

    return data;
  }

  // 轉換為 JSON 字符串
  String toJson() {
    return jsonEncode(toMap());
  }

  // 創建帶有更新字段的新實例
  TeamModel copyWith({
    String? id,
    String? name,
    String? description,
    String? logo,
    String? createdBy,
    String? createdAt,
    List<String>? members,
    List<String>? competitions,
    String? school,
    Map<String, dynamic>? metadata,
  }) {
    return TeamModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      logo: logo ?? this.logo,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      members: members ?? this.members,
      competitions: competitions ?? this.competitions,
      school: school ?? this.school,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'TeamModel{id: $id, name: $name, members: ${members.length}}';
  }
}
