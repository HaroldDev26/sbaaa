import 'event_result.dart';
import 'medal_type.dart';

class TeamScore {
  final String school; // 學校/團隊名稱
  final Map<String, int> medalCounts; // 獎牌數量統計
  final Map<String, int> pointsByEvent; // 每項目的得分
  int totalPoints; // 總得分 - 移除 final 關鍵字以允許修改

  TeamScore({
    required this.school,
    required this.medalCounts,
    required this.pointsByEvent,
    required this.totalPoints,
  });

  // 工廠方法 - 從JSON創建
  factory TeamScore.fromJson(Map<String, dynamic> json) {
    return TeamScore(
      school: json['school'] ?? '未知學校',
      medalCounts: Map<String, int>.from(json['medalCounts'] ?? {}),
      pointsByEvent: Map<String, int>.from(json['pointsByEvent'] ?? {}),
      totalPoints: json['totalPoints'] ?? 0,
    );
  }

  // 轉換為JSON
  Map<String, dynamic> toJson() {
    return {
      'school': school,
      'medalCounts': medalCounts,
      'pointsByEvent': pointsByEvent,
      'totalPoints': totalPoints,
    };
  }

  // 創建副本並更新數據
  TeamScore copyWith({
    String? school,
    Map<String, int>? medalCounts,
    Map<String, int>? pointsByEvent,
    int? totalPoints,
  }) {
    return TeamScore(
      school: school ?? this.school,
      medalCounts: medalCounts ?? Map<String, int>.from(this.medalCounts),
      pointsByEvent: pointsByEvent ?? Map<String, int>.from(this.pointsByEvent),
      totalPoints: totalPoints ?? this.totalPoints,
    );
  }

  @override
  String toString() {
    return 'TeamScore{school: $school, totalPoints: $totalPoints, medalCounts: $medalCounts}';
  }

  // 從 Map 創建模型
  factory TeamScore.fromMap(Map<String, dynamic> data) {
    // 移除未使用的medals變數
    Map<String, int> medalCounts = {};
    if (data['medals'] != null) {
      for (var medal in data['medals'] as List) {
        final Medal medalObj = Medal.fromMap(medal);
        medalCounts[medalTypeToString(medalObj.type)] = medalObj.count;
      }
    }

    Map<String, int> eventScores = {};
    if (data['eventScores'] != null) {
      data['eventScores'].forEach((key, value) {
        eventScores[key] = value;
      });
    }

    return TeamScore(
      school: data['school'] ?? '',
      medalCounts: medalCounts,
      pointsByEvent: eventScores,
      totalPoints: data['totalScore'] ?? 0,
    );
  }

  // 根據成績計算隊伍得分
  static TeamScore calculateFromResults(String teamId, String teamName,
      String? school, List<EventResult> results) {
    int totalScore = 0;
    List<Medal> medals = [];
    Map<String, int> eventScores = {};

    // 計分規則：第一名8分、第二名7分...第八名1分
    const Map<int, int> rankToPoints = {
      1: 8,
      2: 7,
      3: 6,
      4: 5,
      5: 4,
      6: 3,
      7: 2,
      8: 1,
    };

    // 獎牌計數
    int goldCount = 0;
    int silverCount = 0;
    int bronzeCount = 0;

    for (var result in results) {
      if (result.rank != null && result.rank! <= 8) {
        // 計算得分
        int points = rankToPoints[result.rank!] ?? 0;
        totalScore += points;

        // 統計各項目得分
        if (eventScores.containsKey(result.eventName)) {
          eventScores[result.eventName] =
              eventScores[result.eventName]! + points;
        } else {
          eventScores[result.eventName] = points;
        }

        // 統計獎牌
        if (result.rank == 1) {
          goldCount++;
        } else if (result.rank == 2) {
          silverCount++;
        } else if (result.rank == 3) {
          bronzeCount++;
        }
      }
    }

    // 添加獎牌
    if (goldCount > 0) {
      medals.add(Medal(type: MedalType.gold, count: goldCount));
    }
    if (silverCount > 0) {
      medals.add(Medal(type: MedalType.silver, count: silverCount));
    }
    if (bronzeCount > 0) {
      medals.add(Medal(type: MedalType.bronze, count: bronzeCount));
    }

    return TeamScore(
      school: school ?? '',
      medalCounts: {
        'gold': goldCount,
        'silver': silverCount,
        'bronze': bronzeCount,
      },
      pointsByEvent: eventScores,
      totalPoints: totalScore,
    );
  }

  // 獲取總獎牌數
  int get totalMedals {
    return medalCounts.values.fold(0, (sum, count) => sum + count);
  }

  // 獲取金牌數
  int get goldMedals {
    return medalCounts['gold'] ?? 0;
  }

  // 獲取銀牌數
  int get silverMedals {
    return medalCounts['silver'] ?? 0;
  }

  // 獲取銅牌數
  int get bronzeMedals {
    return medalCounts['bronze'] ?? 0;
  }
}

class Medal {
  final MedalType type; // 使用枚舉代替字符串
  final int count;

  Medal({required this.type, required this.count});

  factory Medal.fromMap(Map<String, dynamic> data) {
    // 從字符串轉換為枚舉
    MedalType medalType = stringToMedalType(data['type'] ?? '');

    return Medal(
      type: medalType,
      count: data['count'] ?? 0,
    );
  }

  // 轉換為Map
  Map<String, dynamic> toMap() {
    return {
      'type': medalTypeToString(type),
      'count': count,
    };
  }
}
