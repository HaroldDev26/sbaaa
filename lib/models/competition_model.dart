import 'package:cloud_firestore/cloud_firestore.dart';

class CompetitionModel {
  final String id;
  final String name;
  final String description;
  final String? venue;
  final String startDate;
  final String endDate;
  final String status;
  final String createdBy;
  final String createdByUid;
  final String createdAt;
  final List<String>? participants;
  final Map<String, dynamic>? results;
  final List<String>? categories;
  final List<Map<String, dynamic>>? events;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic>? permissions;

  // 用於UI顯示的狀態
  final bool alreadyRegistered;
  final bool isDeadlinePassed;
  final bool hasRegistrationForm;

  CompetitionModel({
    required this.id,
    required this.name,
    required this.description,
    this.venue,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdBy,
    required this.createdByUid,
    required this.createdAt,
    this.participants,
    this.results,
    this.categories,
    this.events,
    this.metadata,
    this.permissions,
    this.alreadyRegistered = false,
    this.isDeadlinePassed = false,
    this.hasRegistrationForm = false,
  });

  // 從Firebase文檔創建模型
  factory CompetitionModel.fromFirestore(
    DocumentSnapshot doc, {
    bool? isRegistered,
    bool? deadlinePassed,
    bool? hasForm,
  }) {
    final data = doc.data() as Map<String, dynamic>;

    // 處理日期格式
    String startDate = '';
    if (data['startDate'] is Timestamp) {
      startDate =
          (data['startDate'] as Timestamp).toDate().toString().split(' ')[0];
    } else if (data['startDate'] is String) {
      startDate = data['startDate'];
    }

    String endDate = '';
    if (data['endDate'] is Timestamp) {
      endDate =
          (data['endDate'] as Timestamp).toDate().toString().split(' ')[0];
    } else if (data['endDate'] is String) {
      endDate = data['endDate'];
    }

    // 處理創建時間
    Timestamp createdAt;
    if (data['createdAt'] is Timestamp) {
      createdAt = data['createdAt'];
    } else if (data['createdAt'] is String) {
      try {
        createdAt = Timestamp.fromDate(DateTime.parse(data['createdAt']));
      } catch (e) {
        createdAt = Timestamp.now();
      }
    } else {
      createdAt = Timestamp.now();
    }

    // 檢查報名表狀態
    bool hasRegistrationForm = hasForm ?? false;
    if (hasForm == null) {
      if (data['registrationFormId'] != null &&
          data['registrationFormId'].toString().isNotEmpty) {
        hasRegistrationForm = true;
      } else if (data['metadata'] != null &&
          data['metadata']['registration_form_created'] == true) {
        hasRegistrationForm = true;
      }
    }

    // 檢查報名截止日期
    bool isDeadlinePassed = deadlinePassed ?? false;
    if (deadlinePassed == null &&
        data['metadata'] != null &&
        data['metadata']['registration_form'] != null &&
        data['metadata']['registration_form']['deadline'] != null) {
      final deadline = data['metadata']['registration_form']['deadline'];
      if (deadline is Timestamp) {
        isDeadlinePassed = deadline.toDate().isBefore(DateTime.now());
      }
    }

    // 處理 participants (List<dynamic> 轉 List<String>)
    List<String>? participantsList;
    if (data['participants'] != null) {
      participantsList = (data['participants'] as List<dynamic>)
          .map((item) => item.toString())
          .toList();
    }

    // 處理 categories (List<dynamic> 轉 List<String>)
    List<String>? categoriesList;
    if (data['categories'] != null) {
      categoriesList = (data['categories'] as List<dynamic>)
          .map((item) => item.toString())
          .toList();
    }

    // 處理 events (List<dynamic> 轉 List<Map<String, dynamic>>)
    List<Map<String, dynamic>>? eventsList;
    if (data['events'] != null) {
      eventsList = (data['events'] as List<dynamic>)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    }

    return CompetitionModel(
      id: doc.id,
      name: data['name'] ?? '未命名比賽',
      description: data['description'] ?? '',
      venue: data['venue'],
      startDate: startDate,
      endDate: endDate,
      status: data['status'] ?? '計劃中',
      createdBy: data['createdBy'] ?? '未知',
      createdByUid: data['createdByUid'] ?? '',
      createdAt: createdAt.toDate().toString(),
      participants: participantsList,
      results: data['results'],
      categories: categoriesList,
      events: eventsList,
      metadata: data['metadata'],
      permissions: data['permissions'],
      alreadyRegistered: isRegistered ?? false,
      isDeadlinePassed: isDeadlinePassed,
      hasRegistrationForm: hasRegistrationForm,
    );
  }

  // 從Map創建模型
  factory CompetitionModel.fromMap(
    Map<String, dynamic> map, {
    bool? isRegistered,
    bool? deadlinePassed,
    bool? hasForm,
  }) {
    // 處理日期格式
    String startDate = '';
    if (map['startDate'] is Timestamp) {
      startDate =
          (map['startDate'] as Timestamp).toDate().toString().split(' ')[0];
    } else if (map['startDate'] is String) {
      startDate = map['startDate'];
    }

    String endDate = '';
    if (map['endDate'] is Timestamp) {
      endDate = (map['endDate'] as Timestamp).toDate().toString().split(' ')[0];
    } else if (map['endDate'] is String) {
      endDate = map['endDate'];
    }

    // 處理創建時間
    Timestamp createdAt;
    if (map['createdAt'] is Timestamp) {
      createdAt = map['createdAt'];
    } else if (map['createdAt'] is String) {
      try {
        createdAt = Timestamp.fromDate(DateTime.parse(map['createdAt']));
      } catch (e) {
        createdAt = Timestamp.now();
      }
    } else {
      createdAt = Timestamp.now();
    }

    // 檢查報名表狀態
    bool hasRegistrationForm = hasForm ?? false;
    if (hasForm == null) {
      if (map['registrationFormId'] != null &&
          map['registrationFormId'].toString().isNotEmpty) {
        hasRegistrationForm = true;
      } else if (map['metadata'] != null &&
          map['metadata']['registration_form_created'] == true) {
        hasRegistrationForm = true;
      }
    }

    // 檢查報名截止日期
    bool isDeadlinePassed = deadlinePassed ?? false;
    if (deadlinePassed == null &&
        map['metadata'] != null &&
        map['metadata']['registration_form'] != null &&
        map['metadata']['registration_form']['deadline'] != null) {
      final deadline = map['metadata']['registration_form']['deadline'];
      if (deadline is Timestamp) {
        isDeadlinePassed = deadline.toDate().isBefore(DateTime.now());
      }
    }

    // 處理 participants (List<dynamic> 轉 List<String>)
    List<String>? participantsList;
    if (map['participants'] != null) {
      participantsList = (map['participants'] as List<dynamic>)
          .map((item) => item.toString())
          .toList();
    }

    // 處理 categories (List<dynamic> 轉 List<String>)
    List<String>? categoriesList;
    if (map['categories'] != null) {
      categoriesList = (map['categories'] as List<dynamic>)
          .map((item) => item.toString())
          .toList();
    }

    // 處理 events (List<dynamic> 轉 List<Map<String, dynamic>>)
    List<Map<String, dynamic>>? eventsList;
    if (map['events'] != null) {
      eventsList = (map['events'] as List<dynamic>)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    }

    return CompetitionModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '未命名比賽',
      description: map['description'] ?? '',
      venue: map['venue'],
      startDate: startDate,
      endDate: endDate,
      status: map['status'] ?? '計劃中',
      createdBy: map['createdBy'] ?? '未知',
      createdByUid: map['createdByUid'] ?? '',
      createdAt: createdAt.toDate().toString(),
      participants: participantsList,
      results: map['results'],
      categories: categoriesList,
      events: eventsList,
      metadata: map['metadata'],
      permissions: map['permissions'],
      alreadyRegistered: isRegistered ?? map['alreadyRegistered'] ?? false,
      isDeadlinePassed: isDeadlinePassed,
      hasRegistrationForm: hasRegistrationForm,
    );
  }

  // 轉換為Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'venue': venue,
      'startDate': startDate,
      'endDate': endDate,
      'status': status,
      'createdBy': createdBy,
      'createdByUid': createdByUid,
      'createdAt': createdAt,
      'participants': participants,
      'results': results,
      'categories': categories,
      'events': events,
      'metadata': metadata,
      'permissions': permissions,
      'alreadyRegistered': alreadyRegistered,
      'isDeadlinePassed': isDeadlinePassed,
      'hasRegistrationForm': hasRegistrationForm,
    };
  }

  // 取得比賽的可報名項目
  List<String> get availableEvents {
    if (metadata == null ||
        metadata!['registration_form'] == null ||
        metadata!['registration_form']['available_events'] == null) {
      return [];
    }

    final events = metadata!['registration_form']['available_events'];
    if (events is List) {
      try {
        return List<String>.from(events.map((e) => e.toString()));
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  // 取得報名截止日期
  DateTime? get registrationDeadline {
    if (metadata == null ||
        metadata!['registration_form'] == null ||
        metadata!['registration_form']['deadline'] == null) {
      return null;
    }

    final deadline = metadata!['registration_form']['deadline'];
    if (deadline is Timestamp) {
      return deadline.toDate();
    }
    return null;
  }

  // 取得報名限制類型
  String get registrationRestriction {
    if (metadata == null ||
        metadata!['registration_form'] == null ||
        metadata!['registration_form']['registration_restriction'] == null) {
      return '所有人可報名';
    }

    return metadata!['registration_form']['registration_restriction'] as String;
  }

  // 取得限制的郵箱域名
  String? get requiredEmailDomain {
    if (registrationRestriction != '郵箱限制' ||
        metadata == null ||
        metadata!['registration_form'] == null) {
      return null;
    }

    return metadata!['registration_form']['email_domain'] as String?;
  }

  // 取得年齡限制
  Map<String, int?> get ageRestriction {
    if (registrationRestriction != '年齡限制' ||
        metadata == null ||
        metadata!['registration_form'] == null) {
      return {'minAge': null, 'maxAge': null};
    }

    final minAge = metadata!['registration_form']['min_age'];
    final maxAge = metadata!['registration_form']['max_age'];

    return {
      'minAge': minAge is int ? minAge : null,
      'maxAge': maxAge is int ? maxAge : null,
    };
  }

  // 根據狀態獲取顯示顏色
  String get statusColor {
    switch (status) {
      case '計劃中':
        return '#2196F3'; // 藍色
      case '進行中':
        return '#4CAF50'; // 綠色
      case '已結束':
        return '#F44336'; // 紅色
      default:
        return '#9E9E9E'; // 灰色
    }
  }

  // 複製並更新部分屬性
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
    bool? alreadyRegistered,
    bool? isDeadlinePassed,
    bool? hasRegistrationForm,
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
      alreadyRegistered: alreadyRegistered ?? this.alreadyRegistered,
      isDeadlinePassed: isDeadlinePassed ?? this.isDeadlinePassed,
      hasRegistrationForm: hasRegistrationForm ?? this.hasRegistrationForm,
    );
  }
}
