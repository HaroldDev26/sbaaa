import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/event_result.dart';
import '../models/team_score.dart' as team_score;
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
      debugPrint('獲取比賽項目失敗: $e');
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
    debugPrint(
        'getEventResults - 參數: competitionId=$competitionId, eventName=$eventName, gender=$gender, ageGroup=$ageGroup');

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
          debugPrint('沒有在final_results中找到結果，嘗試從results獲取');
          resultsSnapshot = await _firestore
              .collection('competitions')
              .doc(competitionId)
              .collection('results')
              .where('eventName', isEqualTo: eventName)
              .get();
        } else {
          debugPrint('在final_results中找到 ${resultsSnapshot.docs.length} 條結果');
        }
      } catch (e) {
        // 如果訪問final_results出錯，則從results獲取原始結果
        debugPrint('訪問final_results出錯: $e，轉而從results獲取');
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
            .collection('final_results')
            .doc('field_${eventName}_默認')
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

      debugPrint('從數據庫獲取到 ${results.length} 條原始結果');

      // 如果沒有排名信息，根據成績排序並設置排名
      bool hasRanking = results.any((result) => result.rank != null);
      if (!hasRanking) {
        if (results.isNotEmpty && results.first.time != null) {
          // 徑賽排序（時間升序）
          results.sort((a, b) => a.time!.compareTo(b.time!));
          debugPrint('按時間排序（徑賽）');
        } else if (results.isNotEmpty && results.first.score != null) {
          // 田賽排序（成績降序）
          results.sort((a, b) => b.score!.compareTo(a.score!));
          debugPrint('按成績排序（田賽）');
        }

        // 設置排名
        for (var i = 0; i < results.length; i++) {
          results[i] = results[i].copyWith(rank: i + 1);
        }
      }

      // 調試：打印前3條記錄的性別和年齡組別
      if (results.isNotEmpty) {
        debugPrint('前幾條記錄的性別和年齡組別信息:');
        for (var i = 0; i < (results.length > 3 ? 3 : results.length); i++) {
          var result = results[i];
          debugPrint(
              '  第${i + 1}名: ${result.athleteName}, 性別=${result.gender}, 年齡組別=${result.ageGroup}');
        }
      }

      // 應用過濾器
      final filteredResults = _filterResults(results, gender, ageGroup);
      debugPrint('過濾後結果數量: ${filteredResults.length}');
      return filteredResults;
    } catch (e) {
      debugPrint('獲取項目成績失敗: $e');
      return [];
    }
  }

  /// 根據性別和年齡組別過濾結果
  List<EventResult> _filterResults(
    List<EventResult> results,
    String? gender,
    String? ageGroup,
  ) {
    debugPrint(
        '過濾結果 - 總數: ${results.length}, 性別過濾: $gender, 年齡組別過濾: $ageGroup');

    if (gender == null && ageGroup == null) {
      debugPrint('沒有過濾條件，返回所有結果');
      return results;
    }

    final filteredResults = results.where((result) {
      bool matchGender = gender == null || result.gender == gender;
      bool matchAgeGroup = ageGroup == null || result.ageGroup == ageGroup;

      if (!matchGender) {
        debugPrint(
            '排除結果 - ${result.athleteName}: 性別不匹配 (需要=$gender, 實際=${result.gender})');
      }

      if (!matchAgeGroup) {
        debugPrint(
            '排除結果 - ${result.athleteName}: 年齡組別不匹配 (需要=$ageGroup, 實際=${result.ageGroup})');
      }

      return matchGender && matchAgeGroup;
    }).toList();

    debugPrint('過濾後結果數量: ${filteredResults.length}');
    return filteredResults;
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
  Future<List<team_score.TeamScore>> getTeamScores(String competitionId,
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
            'totalPoints': 0,
            'medalCounts': {'gold': 0, 'silver': 0, 'bronze': 0},
            'pointsByEvent': <String, int>{},
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
          teamsData[school]!['totalPoints'] =
              teamsData[school]!['totalPoints'] + points;

          // 更新項目得分
          final pointsByEvent =
              teamsData[school]!['pointsByEvent'] as Map<String, int>;
          pointsByEvent[result.eventName] =
              (pointsByEvent[result.eventName] ?? 0) + points;

          // 更新獎牌
          if (result.rank! <= 3) {
            final medalCounts =
                teamsData[school]!['medalCounts'] as Map<String, int>;
            String medalType;
            switch (result.rank!) {
              case 1:
                medalType = 'gold';
                break;
              case 2:
                medalType = 'silver';
                break;
              case 3:
                medalType = 'bronze';
                break;
              default:
                continue;
            }
            medalCounts[medalType] = (medalCounts[medalType] ?? 0) + 1;
          }
        }
      }

      // 將數據轉換為TeamScore對象列表
      List<team_score.TeamScore> teamScores = teamsData.values.map((data) {
        return team_score.TeamScore(
          school: data['school'],
          medalCounts: Map<String, int>.from(data['medalCounts']),
          pointsByEvent: Map<String, int>.from(data['pointsByEvent']),
          totalPoints: data['totalPoints'],
        );
      }).toList();

      // 按總分排序
      teamScores.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

      return teamScores;
    } catch (e) {
      debugPrint('獲取團隊成績失敗: $e');
      return [];
    }
  }

  // 根據年齡獲取適合的年齡組別
  String? getAgeGroupForAge(int age, List<Map<String, dynamic>> ageGroups) {
    for (var group in ageGroups) {
      final int? startAge = group['startAge'] as int?;
      final int? endAge = group['endAge'] as int?;
      if (startAge != null &&
          endAge != null &&
          age >= startAge &&
          age <= endAge) {
        return group['name'] as String?;
      }
    }
    return null;
  }

  // 獲取比賽的 metadata
  Future<Map<String, dynamic>?> getCompetitionMetadata(
      String competitionId) async {
    try {
      final compDoc =
          await _firestore.collection('competitions').doc(competitionId).get();
      if (compDoc.exists && compDoc.data() != null) {
        final data = compDoc.data()!;
        if (data.containsKey('metadata')) {
          return data['metadata'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      debugPrint('獲取比賽 metadata 失敗: $e');
      return null;
    }
  }
}
