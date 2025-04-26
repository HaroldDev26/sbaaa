import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class CompetitionModel {
  final String id;
  final String name;
  final String description;
  final String? venue; // 比賽場地
  final String startDate;
  final String endDate;
  final String status; // 狀態：計劃中、進行中、已結束等
  final String createdBy;
  final String createdByUid; // 添加創建者UID
  final String createdAt;
  final List<String>? participants; // 參與者/隊伍 ID 列表
  final Map<String, dynamic>? results; // 比賽結果
  final List<String>? categories; // 比賽類別
  final List<Map<String, dynamic>>? events; // 比賽項目
  final Map<String, dynamic>? metadata; // 其他元數據
  final Map<String, dynamic>? permissions;

  CompetitionModel({
    required this.id,
    required this.name,
    required this.description,
    this.venue,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdBy,
    required this.createdByUid, // 添加創建者UID參數
    required this.createdAt,
    this.participants,
    this.results,
    this.categories,
    this.events,
    this.metadata,
    this.permissions,
  });

  // 從 Firestore Map 創建比賽模型
  factory CompetitionModel.fromMap(Map<String, dynamic> map) {
    // 確保permissions中包含所有必要的角色字段
    Map<String, dynamic> permissions =
        map['permissions'] as Map<String, dynamic>? ?? {};

    // 確保存在必要的權限字段
    if (!permissions.containsKey('owner')) {
      permissions['owner'] = map['createdByUid'] ?? '';
    }
    if (!permissions.containsKey('canEdit')) {
      permissions['canEdit'] = [map['createdByUid'] ?? ''];
    }
    if (!permissions.containsKey('canDelete')) {
      permissions['canDelete'] = [map['createdByUid'] ?? ''];
    }
    if (!permissions.containsKey('canManage')) {
      permissions['canManage'] = [map['createdByUid'] ?? ''];
    }

    // 確保角色特定權限存在
    if (!permissions.containsKey('registration')) {
      permissions['registration'] = [];
    }
    if (!permissions.containsKey('score')) {
      permissions['score'] = [];
    }
    if (!permissions.containsKey('violation')) {
      permissions['violation'] = [];
    }
    if (!permissions.containsKey('award')) {
      permissions['award'] = [];
    }

    return CompetitionModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      venue: map['venue'],
      startDate: map['startDate'] ?? '',
      endDate: map['endDate'] ?? '',
      status: map['status'] ?? '計劃中',
      createdBy: map['createdBy'] ?? '未知',
      createdByUid: map['createdByUid'] ?? '', // 從map中獲取創建者UID
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      participants: map['participants'] != null
          ? List<String>.from(map['participants'])
          : null,
      results: map['results'],
      categories: map['categories'] != null
          ? List<String>.from(map['categories'])
          : null,
      events: map['events'] != null
          ? List<Map<String, dynamic>>.from(
              map['events'].map((x) => Map<String, dynamic>.from(x)))
          : null,
      metadata: map['metadata'] as Map<String, dynamic>?,
      permissions: permissions,
    );
  }

  // 從 Firestore Document 創建比賽模型
  factory CompetitionModel.fromDoc(dynamic doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    // 確保 ID 被設置，使用文檔 ID 如果數據中沒有提供
    data['id'] = data['id'] ?? doc.id;
    return CompetitionModel.fromMap(data);
  }

  // 從 JSON 字符串創建比賽模型
  factory CompetitionModel.fromJson(String json) {
    return CompetitionModel.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }

  // 轉換為 Map，用於存儲到 Firestore
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = {
      'id': id,
      'name': name,
      'description': description,
      'venue': venue,
      'startDate': startDate,
      'endDate': endDate,
      'status': status,
      'createdBy': createdBy,
      'createdByUid': createdByUid, // 加入創建者UID
      'createdAt': createdAt,
    };

    if (participants != null) data['participants'] = participants;
    if (results != null) data['results'] = results;
    if (categories != null) data['categories'] = categories;
    if (events != null) data['events'] = events;
    if (metadata != null) data['metadata'] = metadata;
    if (permissions != null) data['permissions'] = permissions;

    return data;
  }

  // 轉換為 JSON 字符串
  String toJson() {
    return jsonEncode(toMap());
  }

  // 創建帶有更新字段的新實例
  CompetitionModel copyWith({
    String? id,
    String? name,
    String? description,
    String? venue,
    String? startDate,
    String? endDate,
    String? status,
    String? createdBy,
    String? createdByUid,
    String? createdAt,
    List<String>? participants,
    Map<String, dynamic>? results,
    List<String>? categories,
    List<Map<String, dynamic>>? events,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? permissions,
  }) {
    return CompetitionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      venue: venue ?? this.venue,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdByUid: createdByUid ?? this.createdByUid,
      createdAt: createdAt ?? this.createdAt,
      participants: participants ?? this.participants,
      results: results ?? this.results,
      categories: categories ?? this.categories,
      events: events ?? this.events,
      metadata: metadata ?? this.metadata,
      permissions: permissions ?? this.permissions,
    );
  }

  // 檢查用戶是否有刪除權限
  bool canUserDelete(String userId) {
    if (userId.isEmpty) return false;

    // 檢查創建者UID
    if (createdByUid == userId) return true;

    // 檢查權限列表
    if (permissions != null && permissions!.containsKey('canDelete')) {
      final canDelete = permissions!['canDelete'] as List<dynamic>?;
      if (canDelete != null && canDelete.contains(userId)) {
        return true;
      }
    }

    return false;
  }

  // 檢查用戶是否有編輯權限
  bool canUserEdit(String userId) {
    if (userId.isEmpty) return false;

    // 檢查創建者UID
    if (createdByUid == userId) return true;

    // 檢查權限列表
    if (permissions != null && permissions!.containsKey('canEdit')) {
      final canEdit = permissions!['canEdit'] as List<dynamic>?;
      if (canEdit != null && canEdit.contains(userId)) {
        return true;
      }
    }

    return false;
  }

  // 檢查用戶是否有特定角色權限
  bool hasRole(String userId, String roleName) {
    if (userId.isEmpty) return false;

    // 創建者/擁有者擁有所有權限
    if (createdByUid == userId) return true;

    // 檢查特定角色權限
    if (permissions != null && permissions!.containsKey(roleName)) {
      final roleMembers = permissions![roleName] as List<dynamic>?;
      if (roleMembers != null && roleMembers.contains(userId)) {
        return true;
      }
    }

    // 檢查通用管理權限
    if (roleName != 'owner' &&
        roleName != 'canDelete' &&
        permissions != null &&
        permissions!.containsKey('canManage')) {
      final managers = permissions!['canManage'] as List<dynamic>?;
      if (managers != null && managers.contains(userId)) {
        return true;
      }
    }

    return false;
  }

  // 檢查用戶是否為比賽擁有者
  bool isOwner(String userId) {
    if (userId.isEmpty) return false;
    return createdByUid == userId;
  }

  // 檢查比賽是否已開放報名
  bool get isRegistrationOpen {
    if (metadata == null) return false;

    // 檢查報名表是否已創建
    final formCreated = metadata!['registration_form_created'] == true;

    // 檢查報名狀態是否為開放
    final registrationStatus = metadata!['registration_status'];
    final isOpen = registrationStatus == 'open';

    return formCreated && isOpen;
  }

  // 獲取報名截止日期
  DateTime? get registrationDeadline {
    if (metadata == null ||
        metadata!['registration_form'] == null ||
        metadata!['registration_form']['deadline'] == null) {
      return null;
    }

    return (metadata!['registration_form']['deadline'] as Timestamp).toDate();
  }

  // 檢查用戶是否符合報名條件
  Future<Map<String, dynamic>> checkRegistrationEligibility(
      Map<String, dynamic> userData) async {
    if (metadata == null || metadata!['registration_form'] == null) {
      return {'eligible': false, 'reason': '比賽尚未開放報名'};
    }

    final form = metadata!['registration_form'] as Map<String, dynamic>;
    final restriction = form['registration_restriction'] as String?;

    // 檢查是否有報名限制
    if (restriction == null || restriction == '所有人可報名') {
      return {'eligible': true};
    }

    // 檢查電子郵箱限制
    if (restriction == '郵箱限制') {
      final requiredDomain = form['email_domain'] as String?;
      final userEmail = userData['email'] as String?;

      if (requiredDomain != null && userEmail != null) {
        if (!userEmail.endsWith(requiredDomain)) {
          return {
            'eligible': false,
            'reason': '您的電子郵箱不符合要求，需要以 @$requiredDomain 結尾的郵箱'
          };
        }
      }
    }

    // 檢查年齡限制
    if (restriction == '年齡限制') {
      final minAge = form['min_age'] as int?;
      final maxAge = form['max_age'] as int?;
      final userBirthday = userData['birthday'] as String?;

      if (minAge != null && maxAge != null && userBirthday != null) {
        try {
          final birthDate = DateTime.parse(userBirthday);
          final today = DateTime.now();
          final age = today.year -
              birthDate.year -
              (today.month < birthDate.month ||
                      (today.month == birthDate.month &&
                          today.day < birthDate.day)
                  ? 1
                  : 0);

          if (age < minAge || age > maxAge) {
            return {
              'eligible': false,
              'reason': '您的年齡不符合要求，需要$minAge到$maxAge歲之間'
            };
          }
        } catch (e) {
          return {'eligible': false, 'reason': '無法檢驗您的年齡，請確保您的出生日期格式正確'};
        }
      }
    }

    return {'eligible': true};
  }

  // 獲取可報名的項目列表
  List<String> get availableEvents {
    if (metadata == null ||
        metadata!['registration_form'] == null ||
        metadata!['registration_form']['events'] == null) {
      return [];
    }

    return List<String>.from(metadata!['registration_form']['events']);
  }

  // 獲取可報名的年齡分組
  List<String> get availableAgeGroups {
    if (metadata == null ||
        metadata!['registration_form'] == null ||
        metadata!['registration_form']['age_groups'] == null) {
      return [];
    }

    return List<String>.from(metadata!['registration_form']['age_groups']);
  }

  // 獲取報名限制類型
  String get registrationRestriction {
    if (metadata == null ||
        metadata!['registration_form'] == null ||
        metadata!['registration_form']['registration_restriction'] == null) {
      return '所有人可報名';
    }

    return metadata!['registration_form']['registration_restriction'] as String;
  }

  @override
  String toString() {
    return 'CompetitionModel{id: $id, name: $name, status: $status}';
  }
}
