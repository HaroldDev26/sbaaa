import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_result.dart';
import '../models/team_score.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 獲取所有比賽成績
  Future<List<EventResult>> getAllResults() async {
    try {
      final snapshot = await _firestore.collection('eventResults').get();
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        data['id'] = doc.id; // 確保ID被包含
        return EventResult.fromFirestore(data);
      }).toList();
    } catch (e) {
      print('獲取成績出錯: $e');
      return [];
    }
  }

  // 獲取特定項目的成績
  Future<List<EventResult>> getResultsByEvent(String eventName) async {
    try {
      final snapshot = await _firestore
          .collection('eventResults')
          .where('eventName', isEqualTo: eventName)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        return EventResult.fromFirestore(data);
      }).toList();
    } catch (e) {
      print('獲取項目成績出錯: $e');
      return [];
    }
  }

  // 獲取特定學校的成績
  Future<List<EventResult>> getResultsBySchool(String school) async {
    try {
      final snapshot = await _firestore
          .collection('eventResults')
          .where('school', isEqualTo: school)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        return EventResult.fromFirestore(data);
      }).toList();
    } catch (e) {
      print('獲取學校成績出錯: $e');
      return [];
    }
  }

  // 計算團隊排名和得分
  Future<List<TeamScore>> calculateTeamScores() async {
    try {
      // 獲取所有成績
      List<EventResult> allResults = await getAllResults();

      // 按學校分組
      Map<String, List<EventResult>> resultsBySchool = {};

      for (var result in allResults) {
        if (result.school != null) {
          if (!resultsBySchool.containsKey(result.school)) {
            resultsBySchool[result.school!] = [];
          }
          resultsBySchool[result.school!]!.add(result);
        }
      }

      // 計算每個學校的得分
      List<TeamScore> teamScores = [];

      resultsBySchool.forEach((school, results) {
        TeamScore score = TeamScore.calculateFromResults(
          school, // 用學校作為隊伍ID
          school, // 用學校作為隊伍名稱
          school,
          results,
        );
        teamScores.add(score);
      });

      // 按總分排序（降序）
      teamScores.sort((a, b) => b.totalScore.compareTo(a.totalScore));

      return teamScores;
    } catch (e) {
      print('計算團隊得分出錯: $e');
      return [];
    }
  }

  // 獲取項目的成績分佈數據
  Future<Map<String, dynamic>> getEventDistribution(String eventName) async {
    try {
      List<EventResult> results = await getResultsByEvent(eventName);

      if (results.isEmpty) {
        return {
          'count': 0,
          'avgTime': null,
          'maxTime': null,
          'minTime': null,
          'timeDistribution': {},
        };
      }

      // 過濾有時間記錄的成績
      var validResults = results.where((r) => r.time != null).toList();
      if (validResults.isEmpty) {
        return {
          'count': results.length,
          'avgTime': null,
          'maxTime': null,
          'minTime': null,
          'timeDistribution': {},
        };
      }

      // 計算平均、最大、最小時間（假設時間已轉為秒）
      double sumTime = 0;
      double maxTime = validResults.first.time!.toDouble();
      double minTime = validResults.first.time!.toDouble();

      for (var result in validResults) {
        double time = result.time!.toDouble();
        sumTime += time;
        if (time > maxTime) maxTime = time;
        if (time < minTime) minTime = time;
      }

      double avgTime = sumTime / validResults.length;

      // 創建時間分佈直方圖數據
      Map<String, int> timeDistribution = {};

      // 創建5個範圍
      double range = (maxTime - minTime) / 5;
      if (range > 0) {
        for (var result in validResults) {
          double time = result.time!.toDouble();
          int bucketIndex = ((time - minTime) / range).floor();
          if (bucketIndex >= 5) bucketIndex = 4; // 確保在範圍內

          String bucketKey =
              '${(minTime + bucketIndex * range).toStringAsFixed(2)}-${(minTime + (bucketIndex + 1) * range).toStringAsFixed(2)}';

          timeDistribution[bucketKey] = (timeDistribution[bucketKey] ?? 0) + 1;
        }
      }

      return {
        'count': results.length,
        'avgTime': avgTime,
        'maxTime': maxTime,
        'minTime': minTime,
        'timeDistribution': timeDistribution,
      };
    } catch (e) {
      print('獲取項目分佈出錯: $e');
      return {'count': 0, 'error': e.toString()};
    }
  }
}
