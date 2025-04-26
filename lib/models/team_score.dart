import 'event_result.dart';

class TeamScore {
  final String teamId;
  final String teamName;
  final String? school;
  final int totalScore;
  final List<Medal> medals;
  final Map<String, int> eventScores; // 各項目得分

  TeamScore({
    required this.teamId,
    required this.teamName,
    this.school,
    required this.totalScore,
    required this.medals,
    required this.eventScores,
  });

  // 從 Map 創建模型
  factory TeamScore.fromMap(Map<String, dynamic> data) {
    List<Medal> medals = [];
    if (data['medals'] != null) {
      medals = (data['medals'] as List).map((m) => Medal.fromMap(m)).toList();
    }

    Map<String, int> eventScores = {};
    if (data['eventScores'] != null) {
      data['eventScores'].forEach((key, value) {
        eventScores[key] = value;
      });
    }

    return TeamScore(
      teamId: data['teamId'] ?? '',
      teamName: data['teamName'] ?? '',
      school: data['school'],
      totalScore: data['totalScore'] ?? 0,
      medals: medals,
      eventScores: eventScores,
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
      medals.add(Medal(type: 'gold', count: goldCount));
    }
    if (silverCount > 0) {
      medals.add(Medal(type: 'silver', count: silverCount));
    }
    if (bronzeCount > 0) {
      medals.add(Medal(type: 'bronze', count: bronzeCount));
    }

    return TeamScore(
      teamId: teamId,
      teamName: teamName,
      school: school,
      totalScore: totalScore,
      medals: medals,
      eventScores: eventScores,
    );
  }

  // 獲取總獎牌數
  int get totalMedals {
    return medals.fold(0, (sum, medal) => sum + medal.count);
  }

  // 獲取金牌數
  int get goldMedals {
    return medals
        .where((m) => m.type == 'gold')
        .fold(0, (sum, medal) => sum + medal.count);
  }

  // 獲取銀牌數
  int get silverMedals {
    return medals
        .where((m) => m.type == 'silver')
        .fold(0, (sum, medal) => sum + medal.count);
  }

  // 獲取銅牌數
  int get bronzeMedals {
    return medals
        .where((m) => m.type == 'bronze')
        .fold(0, (sum, medal) => sum + medal.count);
  }
}

class Medal {
  final String type; // 'gold', 'silver', 'bronze'
  final int count;

  Medal({required this.type, required this.count});

  factory Medal.fromMap(Map<String, dynamic> data) {
    return Medal(
      type: data['type'] ?? '',
      count: data['count'] ?? 0,
    );
  }
}
