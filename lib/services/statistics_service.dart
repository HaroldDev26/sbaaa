import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_result.dart';
import '../models/team_score.dart';
import 'analytics_service.dart';

/// 用於統計分析的服務，將UI與數據分析層連接
class StatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AnalyticsService _analyticsService = AnalyticsService();

  /// 獲取比賽所有項目
  Future<List<String>> getCompetitionEvents(String competitionId) async {
    try {
      // 先從event_summaries集合獲取所有項目信息
      final summariesSnapshot = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('event_summaries')
          .get();

      if (summariesSnapshot.docs.isNotEmpty) {
        // 從摘要中獲取項目名稱
        return summariesSnapshot.docs
            .map((doc) => doc.data()['eventName'] as String)
            .toList();
      }

      // 如果沒有摘要，嘗試從比賽metadata中獲取
      final compDoc =
          await _firestore.collection('competitions').doc(competitionId).get();

      if (compDoc.exists && compDoc.data() != null) {
        final data = compDoc.data()!;
        if (data.containsKey('metadata') &&
            data['metadata'] != null &&
            data['metadata']['events'] != null) {
          final events =
              List<Map<String, dynamic>>.from(data['metadata']['events']);
          return events.map((e) => e['name'] as String).toList();
        }
      }

      return [];
    } catch (e) {
      print('獲取比賽項目失敗: $e');
      return [];
    }
  }

  /// 獲取項目成績
  Future<List<EventResult>> getEventResults(
    String competitionId,
    String eventName, {
    String? gender,
    String? ageGroup,
  }) async {
    try {
      // 嘗試從final_results獲取最終結果
      QuerySnapshot resultsSnapshot;

      try {
        resultsSnapshot = await _firestore
            .collection('competitions')
            .doc(competitionId)
            .collection('final_results')
            .doc(eventName.replaceAll(' ', '_').toLowerCase())
            .collection('participants')
            .get();

        if (resultsSnapshot.docs.isEmpty) {
          // 如果沒有找到final_results，則從results獲取原始結果
          resultsSnapshot = await _firestore
              .collection('competitions')
              .doc(competitionId)
              .collection('results')
              .where('eventName', isEqualTo: eventName)
              .get();
        }
      } catch (e) {
        // 如果訪問final_results出錯，則從results獲取原始結果
        resultsSnapshot = await _firestore
            .collection('competitions')
            .doc(competitionId)
            .collection('results')
            .where('eventName', isEqualTo: eventName)
            .get();
      }

      if (resultsSnapshot.docs.isEmpty) {
        // 檢查是否為田賽項目
        final fieldResultsDoc = await _firestore
            .collection('competitions')
            .doc(competitionId)
            .collection('field_results')
            .doc('${eventName}_默認')
            .get();

        if (fieldResultsDoc.exists && fieldResultsDoc.data() != null) {
          // 處理田賽結果
          final data = fieldResultsDoc.data()!;
          if (data.containsKey('results')) {
            List<EventResult> results = [];
            final Map<String, dynamic> fieldResults = data['results'];

            fieldResults.forEach((athleteId, attempts) {
              if (attempts is List) {
                // 找出最佳成績
                double? bestScore;
                for (var attempt in attempts) {
                  if (attempt is Map &&
                      attempt['score'] != null &&
                      (bestScore == null || attempt['score'] > bestScore)) {
                    bestScore = (attempt['score'] is int)
                        ? (attempt['score'] as int).toDouble()
                        : attempt['score'];
                  }
                }

                if (bestScore != null) {
                  results.add(EventResult(
                    id: athleteId,
                    athleteId: athleteId,
                    athleteName: attempts.first['athleteName'] ?? '未知',
                    athleteNumber: attempts.first['athleteNumber'] ?? '',
                    school: attempts.first['school'],
                    gender: attempts.first['gender'],
                    ageGroup: attempts.first['ageGroup'],
                    eventName: eventName,
                    eventType: '田賽',
                    score: bestScore,
                  ));
                }
              }
            });

            // 根據成績排序並設置排名
            results.sort((a, b) => b.score!.compareTo(a.score!));
            for (var i = 0; i < results.length; i++) {
              results[i] = results[i].copyWith(rank: i + 1);
            }

            // 應用過濾器
            return _filterResults(results, gender, ageGroup);
          }
        }

        return [];
      }

      List<EventResult> results = resultsSnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // 添加排名信息（如果存在）
        if (!data.containsKey('rank') &&
            doc.reference.parent.id == 'participants') {
          // 從participants集合的文檔ID中獲取排名
          final parts = doc.id.split('_');
          if (parts.length > 1 && int.tryParse(parts[0]) != null) {
            data['rank'] = int.parse(parts[0]);
          }
        }

        return EventResult.fromFirestore(data);
      }).toList();

      // 如果沒有排名信息，根據成績排序並設置排名
      bool hasRanking = results.any((result) => result.rank != null);
      if (!hasRanking) {
        if (results.first.time != null) {
          // 徑賽排序（時間升序）
          results.sort((a, b) => a.time!.compareTo(b.time!));
        } else if (results.first.score != null) {
          // 田賽排序（成績降序）
          results.sort((a, b) => b.score!.compareTo(a.score!));
        }

        // 設置排名
        for (var i = 0; i < results.length; i++) {
          results[i] = results[i].copyWith(rank: i + 1);
        }
      }

      // 應用過濾器
      return _filterResults(results, gender, ageGroup);
    } catch (e) {
      print('獲取項目成績失敗: $e');
      return [];
    }
  }

  /// 根據性別和年齡組別過濾結果
  List<EventResult> _filterResults(
    List<EventResult> results,
    String? gender,
    String? ageGroup,
  ) {
    if (gender == null && ageGroup == null) {
      return results;
    }

    return results.where((result) {
      bool matchGender = gender == null || result.gender == gender;
      bool matchAgeGroup = ageGroup == null || result.ageGroup == ageGroup;
      return matchGender && matchAgeGroup;
    }).toList();
  }

  /// 計算統計數據
  Map<String, dynamic> calculateStatistics(List<EventResult> results) {
    if (results.isEmpty) {
      return {};
    }

    // 判斷是徑賽還是田賽
    bool isTrackEvent = results.first.time != null;

    if (isTrackEvent) {
      // 徑賽統計（時間）
      List<int> times = results.map((r) => r.time!).toList();
      times.sort();

      int sum = times.fold(0, (sum, time) => sum + time);
      double average = sum / times.length;
      int min = times.first;
      int max = times.last;

      // 計算中位數
      num median;
      if (times.length % 2 == 0) {
        median = (times[times.length ~/ 2 - 1] + times[times.length ~/ 2]) / 2;
      } else {
        median = times[times.length ~/ 2];
      }

      return {
        'count': times.length,
        'average': average,
        'min': min,
        'max': max,
        'median': median,
      };
    } else {
      // 田賽統計（分數）
      List<double> scores = results.map((r) => r.score!).toList();
      scores.sort();

      double sum = scores.fold(0.0, (sum, score) => sum + score);
      double average = sum / scores.length;
      double min = scores.first;
      double max = scores.last;

      // 計算中位數
      double median;
      if (scores.length % 2 == 0) {
        median =
            (scores[scores.length ~/ 2 - 1] + scores[scores.length ~/ 2]) / 2;
      } else {
        median = scores[scores.length ~/ 2];
      }

      return {
        'count': scores.length,
        'average': average,
        'min': min,
        'max': max,
        'median': median,
      };
    }
  }

  /// 獲取團隊成績
  Future<List<TeamScore>> getTeamScores(String competitionId,
      {String? event}) async {
    try {
      List<EventResult> results;

      if (event != null) {
        // 獲取特定項目的成績
        results = await getEventResults(competitionId, event);
      } else {
        // 獲取所有項目的成績
        final allEvents = await getCompetitionEvents(competitionId);
        results = [];

        for (var eventName in allEvents) {
          final eventResults = await getEventResults(competitionId, eventName);
          results.addAll(eventResults);
        }
      }

      // 按學校分組
      Map<String, Map<String, dynamic>> teamsData = {};

      for (var result in results) {
        final school = result.school ?? '未知學校';

        if (!teamsData.containsKey(school)) {
          teamsData[school] = {
            'teamId': school,
            'teamName': school,
            'school': school,
            'totalScore': 0,
            'medals': {1: 0, 2: 0, 3: 0},
            'eventScores': <String, int>{},
          };
        }

        // 如果有排名，計算得分和獎牌
        if (result.rank != null && result.rank! <= 8) {
          // 計算得分：第一名8分，第二名7分，以此類推
          int points = 9 - result.rank!;

          // 接力項目得分翻倍
          if (result.eventType.contains('接力')) {
            points *= 2;
          }

          // 更新總分
          teamsData[school]!['totalScore'] =
              teamsData[school]!['totalScore'] + points;

          // 更新項目得分
          final eventScores =
              teamsData[school]!['eventScores'] as Map<String, int>;
          eventScores[result.eventName] =
              (eventScores[result.eventName] ?? 0) + points;

          // 更新獎牌
          if (result.rank! <= 3) {
            final medals = teamsData[school]!['medals'] as Map<int, int>;
            medals[result.rank!] = medals[result.rank!]! + 1;
          }
        }
      }

      // 將數據轉換為TeamScore對象列表
      List<TeamScore> teamScores = teamsData.values.map((data) {
        List<Medal> medals = [];

        // 添加獎牌
        final medalsMap = data['medals'] as Map<int, int>;
        if (medalsMap[1]! > 0)
          medals.add(Medal(type: 'gold', count: medalsMap[1]!));
        if (medalsMap[2]! > 0)
          medals.add(Medal(type: 'silver', count: medalsMap[2]!));
        if (medalsMap[3]! > 0)
          medals.add(Medal(type: 'bronze', count: medalsMap[3]!));

        return TeamScore(
          teamId: data['teamId'],
          teamName: data['teamName'],
          school: data['school'],
          totalScore: data['totalScore'],
          medals: medals,
          eventScores: Map<String, int>.from(data['eventScores']),
        );
      }).toList();

      // 按總分排序
      teamScores.sort((a, b) => b.totalScore.compareTo(a.totalScore));

      return teamScores;
    } catch (e) {
      print('獲取團隊成績失敗: $e');
      return [];
    }
  }
}
