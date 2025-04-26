class EventResult {
  final String id;
  final String athleteId;
  final String athleteName;
  final String athleteNumber;
  final String? school;
  final String? ageGroup;
  final String? gender;
  final String eventName;
  final String eventType; // 徑賽、田賽、接力
  final int? time; // 用於徑賽和接力賽，單位為百分之一秒
  final double? score; // 用於田賽，如跳高、跳遠等
  final int? rank; // 排名
  final DateTime? recordedAt; // 記錄時間

  EventResult({
    required this.id,
    required this.athleteId,
    required this.athleteName,
    required this.athleteNumber,
    this.school,
    this.ageGroup,
    this.gender,
    required this.eventName,
    required this.eventType,
    this.time,
    this.score,
    this.rank,
    this.recordedAt,
  });

  // 從 Firestore 文檔創建模型
  factory EventResult.fromFirestore(Map<String, dynamic> data) {
    return EventResult(
      id: data['id'] ?? '',
      athleteId: data['athleteId'] ?? data['teamId'] ?? '',
      athleteName: data['athleteName'] ?? data['teamName'] ?? '未知',
      athleteNumber: data['athleteNumber'] ?? '',
      school: data['school'],
      ageGroup: data['ageGroup'],
      gender: data['gender'],
      eventName: data['eventName'] ?? '',
      eventType: data['eventType'] ?? '',
      time: data['time'],
      score: data['score'] != null
          ? (data['score'] is int ? data['score'].toDouble() : data['score'])
          : null,
      rank: data['rank'],
      recordedAt: data['recordedAt'] != null
          ? (data['recordedAt'] is DateTime
              ? data['recordedAt']
              : DateTime.parse(data['recordedAt'].toString()))
          : null,
    );
  }

  // 創建副本並更新屬性
  EventResult copyWith({
    String? id,
    String? athleteId,
    String? athleteName,
    String? athleteNumber,
    String? school,
    String? ageGroup,
    String? gender,
    String? eventName,
    String? eventType,
    int? time,
    double? score,
    int? rank,
    DateTime? recordedAt,
  }) {
    return EventResult(
      id: id ?? this.id,
      athleteId: athleteId ?? this.athleteId,
      athleteName: athleteName ?? this.athleteName,
      athleteNumber: athleteNumber ?? this.athleteNumber,
      school: school ?? this.school,
      ageGroup: ageGroup ?? this.ageGroup,
      gender: gender ?? this.gender,
      eventName: eventName ?? this.eventName,
      eventType: eventType ?? this.eventType,
      time: time ?? this.time,
      score: score ?? this.score,
      rank: rank ?? this.rank,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }
}
