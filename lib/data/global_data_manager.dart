import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/competition_data.dart';
import 'package:flutter/foundation.dart'; // 添加這一行以使用 debugPrint

/// 全局數據管理器 - 負責處理所有比賽相關的數據一致性
/// 確保徑賽、田賽和接力賽的數據處理統一
class GlobalDataManager {
  // 單例模式實現
  static final GlobalDataManager _instance = GlobalDataManager._internal();

  factory GlobalDataManager() {
    return _instance;
  }

  GlobalDataManager._internal();

  // Firestore 實例
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 比賽數據緩存
  Map<String, dynamic> _competitionCache = {};

  // 選手/隊伍計時數據緩存 - 比賽ID -> 項目名稱 -> 運動員ID -> 時間(厘秒)
  Map<String, Map<String, Map<String, int>>> _timingCache = {};

  // 田賽成績緩存 - 比賽ID -> 項目名稱 -> 運動員ID -> 嘗試成績列表
  Map<String, Map<String, Map<String, List<double>>>> _fieldEventCache = {};

  /// 初始化比賽緩存
  void initCompetitionCache(String competitionId) {
    if (!_competitionCache.containsKey(competitionId)) {
      _competitionCache[competitionId] = {};
    }

    if (!_timingCache.containsKey(competitionId)) {
      _timingCache[competitionId] = {};
    }

    if (!_fieldEventCache.containsKey(competitionId)) {
      _fieldEventCache[competitionId] = {};
    }
  }

  /// 清除特定比賽的緩存數據
  void clearCompetitionCache(String competitionId) {
    _competitionCache.remove(competitionId);
    _timingCache.remove(competitionId);
    _fieldEventCache.remove(competitionId);
  }

  /// 獲取比賽數據
  Future<Map<String, dynamic>?> getCompetitionData(String competitionId) async {
    try {
      if (_competitionCache.containsKey(competitionId) &&
          _competitionCache[competitionId].isNotEmpty) {
        return _competitionCache[competitionId];
      }

      final doc =
          await _firestore.collection('competitions').doc(competitionId).get();
      if (doc.exists) {
        _competitionCache[competitionId] = doc.data() ?? {};
        return _competitionCache[competitionId];
      }
      return null;
    } catch (e) {
      debugPrint('獲取比賽數據失敗: $e');
      return null;
    }
  }

  /// 獲取項目類型
  Future<String> getEventType(
      {required String competitionId, required String eventName}) async {
    try {
      // 先從緩存中查找
      if (_competitionCache.containsKey(competitionId) &&
          _competitionCache[competitionId].containsKey('eventTypes') &&
          _competitionCache[competitionId]['eventTypes']
              .containsKey(eventName)) {
        return _competitionCache[competitionId]['eventTypes'][eventName];
      }

      // 從數據庫加載
      final eventTypes = await CompetitionData.getEventTypes(competitionId);

      // 緩存結果
      if (!_competitionCache.containsKey(competitionId)) {
        _competitionCache[competitionId] = {};
      }
      _competitionCache[competitionId]['eventTypes'] = eventTypes;

      return eventTypes[eventName] ?? '未分類';
    } catch (e) {
      debugPrint('獲取項目類型失敗: $e');
      return '未分類';
    }
  }

  /// 記錄徑賽成績 (個人)
  Future<void> recordTrackEventTime({
    required String competitionId,
    required String eventName,
    required String athleteId,
    required int timeInCentiseconds,
  }) async {
    try {
      // 更新緩存
      initCompetitionCache(competitionId);

      if (!_timingCache[competitionId]!.containsKey(eventName)) {
        _timingCache[competitionId]![eventName] = {};
      }

      // 記錄時間
      _timingCache[competitionId]![eventName]![athleteId] = timeInCentiseconds;
    } catch (e) {
      debugPrint('記錄徑賽成績失敗: $e');
      throw Exception('記錄徑賽成績失敗: $e');
    }
  }

  /// 記錄接力賽成績 (團隊)
  Future<void> recordRelayEventTime({
    required String competitionId,
    required String eventName,
    required String teamId,
    required int timeInCentiseconds,
    required List<int> legTimes,
  }) async {
    try {
      // 更新緩存
      initCompetitionCache(competitionId);

      if (!_timingCache[competitionId]!.containsKey(eventName)) {
        _timingCache[competitionId]![eventName] = {};
      }

      // 記錄時間
      _timingCache[competitionId]![eventName]![teamId] = timeInCentiseconds;

      // 記錄分棒時間
      final String docId = CompetitionData.getEventDocName(eventName);

      await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('event_details')
          .doc(docId)
          .collection('teams')
          .doc(teamId)
          .set({
        'legTimes': legTimes,
        'totalTime': timeInCentiseconds,
        'recordedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('記錄接力賽成績失敗: $e');
      throw Exception('記錄接力賽成績失敗: $e');
    }
  }

  /// 記錄田賽成績 (個人)
  Future<void> recordFieldEventResult({
    required String competitionId,
    required String eventName,
    required String athleteId,
    required double result,
    required int attemptNumber,
    bool isFoul = false,
  }) async {
    try {
      // 更新緩存
      initCompetitionCache(competitionId);

      if (!_fieldEventCache[competitionId]!.containsKey(eventName)) {
        _fieldEventCache[competitionId]![eventName] = {};
      }

      if (!_fieldEventCache[competitionId]![eventName]!
          .containsKey(athleteId)) {
        _fieldEventCache[competitionId]![eventName]![athleteId] =
            List<double>.filled(6, 0.0);
      }

      // 記錄成績 (田賽通常有多次嘗試，從0開始算索引)
      if (!isFoul) {
        _fieldEventCache[competitionId]![eventName]![athleteId]![
            attemptNumber - 1] = result;
      } else {
        // 犯規標記為-1.0
        _fieldEventCache[competitionId]![eventName]![athleteId]![
            attemptNumber - 1] = -1.0;
      }
    } catch (e) {
      debugPrint('記錄田賽成績失敗: $e');
      throw Exception('記錄田賽成績失敗: $e');
    }
  }

  /// 獲取徑賽成績
  int? getTrackEventTime({
    required String competitionId,
    required String eventName,
    required String athleteId,
  }) {
    try {
      return _timingCache[competitionId]?[eventName]?[athleteId];
    } catch (e) {
      debugPrint('獲取徑賽成績失敗: $e');
      return null;
    }
  }

  /// 獲取田賽成績
  List<double>? getFieldEventResults({
    required String competitionId,
    required String eventName,
    required String athleteId,
  }) {
    try {
      return _fieldEventCache[competitionId]?[eventName]?[athleteId];
    } catch (e) {
      debugPrint('獲取田賽成績失敗: $e');
      return null;
    }
  }

  /// 獲取排名 (徑賽/接力賽)
  List<Map<String, dynamic>> getTrackEventRanking({
    required String competitionId,
    required String eventName,
    required List<Map<String, dynamic>> participants,
  }) {
    try {
      // 確保緩存已初始化
      initCompetitionCache(competitionId);

      // 過濾出有成績的參賽者
      final participantsWithTimes = participants.where((participant) {
        final id = participant['id'] as String;
        return _timingCache[competitionId]?.containsKey(eventName) == true &&
            _timingCache[competitionId]![eventName]?.containsKey(id) == true &&
            _timingCache[competitionId]![eventName]![id]! > 0;
      }).map((participant) {
        final id = participant['id'] as String;
        return {
          ...participant,
          'time': _timingCache[competitionId]![eventName]![id]!,
        };
      }).toList();

      // 按照時間排序 (升序)
      participantsWithTimes.sort(
        (a, b) => (a['time'] as int).compareTo(b['time'] as int),
      );

      // 添加排名
      for (int i = 0; i < participantsWithTimes.length; i++) {
        participantsWithTimes[i]['rank'] = i + 1;
      }

      return participantsWithTimes;
    } catch (e) {
      debugPrint('獲取排名失敗: $e');
      return [];
    }
  }

  /// 獲取田賽排名
  List<Map<String, dynamic>> getFieldEventRanking({
    required String competitionId,
    required String eventName,
    required List<Map<String, dynamic>> athletes,
    required bool isHigherBetter, // 是否越高越好 (如：跳高)
  }) {
    try {
      // 確保緩存已初始化
      initCompetitionCache(competitionId);

      // 過濾出有成績的運動員
      final athletesWithResults = athletes
          .where((athlete) {
            final id = athlete['id'] as String;
            return _fieldEventCache[competitionId]?.containsKey(eventName) ==
                    true &&
                _fieldEventCache[competitionId]![eventName]?.containsKey(id) ==
                    true;
          })
          .map((athlete) {
            final id = athlete['id'] as String;
            final attempts = _fieldEventCache[competitionId]![eventName]![id]!;

            // 找出最佳成績 (忽略負值，代表犯規)
            double bestResult = 0.0;
            if (isHigherBetter) {
              // 跳高、撐竿跳等：最高的成績最好
              bestResult = attempts
                  .where((value) => value > 0)
                  .fold(0.0, (max, value) => value > max ? value : max);
            } else {
              // 鉛球、鐵餅等：最遠的成績最好
              bestResult = attempts
                  .where((value) => value > 0)
                  .fold(0.0, (max, value) => value > max ? value : max);
            }

            return {
              ...athlete,
              'bestResult': bestResult,
              'attempts': attempts,
            };
          })
          .where((athlete) =>
              (athlete['bestResult'] as double) > 0) // 過濾掉沒有有效成績的運動員
          .toList();

      // 按照成績排序
      if (isHigherBetter) {
        // 跳高等：從高到低排序
        athletesWithResults.sort(
          (a, b) =>
              (b['bestResult'] as double).compareTo(a['bestResult'] as double),
        );
      } else {
        // 鉛球等：從遠到近排序
        athletesWithResults.sort(
          (a, b) =>
              (b['bestResult'] as double).compareTo(a['bestResult'] as double),
        );
      }

      // 添加排名
      for (int i = 0; i < athletesWithResults.length; i++) {
        athletesWithResults[i]['rank'] = i + 1;
      }

      return athletesWithResults;
    } catch (e) {
      debugPrint('獲取田賽排名失敗: $e');
      return [];
    }
  }

  /// 保存所有結果到數據庫
  Future<void> saveEventResults({
    required String competitionId,
    required String eventName,
    required List<Map<String, dynamic>> rankedResults,
  }) async {
    try {
      // 格式化結果數據
      final formattedResults = {
        'results': rankedResults,
        'recordedAt': FieldValue.serverTimestamp(),
      };

      // 保存結果
      await CompetitionData.saveEventResults(
        competitionId: competitionId,
        eventName: eventName,
        results: formattedResults,
      );
    } catch (e) {
      debugPrint('保存比賽結果失敗: $e');
      throw Exception('保存比賽結果失敗: $e');
    }
  }

  /// 保存田賽成績結果到數據庫
  Future<void> saveFieldEventResults({
    required String competitionId,
    required String eventName,
    required String groupName,
    required Map<String, List<Map<String, dynamic>>> attemptResults,
  }) async {
    try {
      final eventDoc =
          CompetitionData.getEventDocName('field_${eventName}_${groupName}');

      await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('final_results')
          .doc(eventDoc)
          .set({
        'eventName': eventName,
        'groupName': groupName,
        'eventType': '田賽',
        'results': attemptResults,
        'recordedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 更新項目狀態摘要
      await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('event_summaries')
          .doc(CompetitionData.getEventDocName(eventName))
          .set({
        'hasResults': true,
        'eventType': '田賽',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('保存田賽成績失敗: $e');
      throw Exception('保存田賽成績失敗: $e');
    }
  }

  /// 加載田賽成績結果
  Future<Map<String, List<Map<String, dynamic>>>> loadFieldEventResults({
    required String competitionId,
    required String eventName,
    required String groupName,
  }) async {
    try {
      final eventDoc =
          CompetitionData.getEventDocName('field_${eventName}_${groupName}');

      final docRef = _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('final_results')
          .doc(eventDoc);

      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('results')) {
          return Map<String, List<Map<String, dynamic>>>.from(data['results']);
        }
      }
      return {};
    } catch (e) {
      debugPrint('載入田賽成績失敗: $e');
      return {};
    }
  }

  /// 獲取項目參賽者
  Future<List<Map<String, dynamic>>> getEventParticipants({
    required String competitionId,
    required String eventName,
    String? ageGroup,
    String? gender,
  }) async {
    try {
      // 使用CompetitionData類的方法獲取參賽者
      final participants = await CompetitionData.getEventParticipants(
        competitionId: competitionId,
        eventName: eventName,
        ageGroup: ageGroup,
        gender: gender,
      );

      // 標準化每位參賽者的數據
      return participants
          .map((participant) => standardizeParticipantData(participant))
          .toList();
    } catch (e) {
      debugPrint('獲取項目參賽者失敗: $e');
      return [];
    }
  }

  /// 標準化參賽者數據，確保所有必要字段都存在並統一命名
  Map<String, dynamic> standardizeParticipantData(Map<String, dynamic> data) {
    // 創建新的標準化數據對象
    final standardizedData = Map<String, dynamic>.from(data);

    // 確保ID字段存在
    if (!standardizedData.containsKey('id') && data.containsKey('userId')) {
      standardizedData['id'] = data['userId'];
    }

    // 標準化姓名字段
    standardizedData['name'] =
        data['name'] ?? data['userName'] ?? data['athleteName'] ?? '未知選手';

    // 標準化選手編號字段
    standardizedData['athleteNumber'] = data['athleteNumber'] ??
        data['number'] ??
        data['id']?.toString().substring(0, 6) ??
        '編號未知';

    // 標準化學校/組織字段
    standardizedData['school'] =
        data['school'] ?? data['userSchool'] ?? data['organization'] ?? '未知學校';

    // 標準化性別字段
    standardizedData['gender'] = data['gender'] ?? '未知';

    // 標準化年齡組別字段
    standardizedData['ageGroup'] =
        data['ageGroup'] ?? data['age_group'] ?? '未分類';

    // 標準化狀態字段
    standardizedData['status'] = data['status'] ?? 'pending';

    debugPrint(
        '標準化後的參賽者數據: ${standardizedData['name']} (${standardizedData['id']})');

    return standardizedData;
  }

  /// 直接從 Firestore 加載原始參賽者數據，不經過標準化，用於診斷
  Future<List<Map<String, dynamic>>> loadRawEventParticipants({
    required String competitionId,
    required String eventName,
  }) async {
    try {
      final collectionName =
          CompetitionData.getCompetitionCollectionName(competitionId);

      // 直接使用 Firestore 查詢
      final query = _firestore
          .collection(collectionName)
          .where('status', isEqualTo: 'approved')
          .where('events', arrayContains: eventName);

      final snapshot = await query.get();

      debugPrint('從 Firestore 直接加載了 ${snapshot.docs.length} 位選手的原始數據');

      // 返回原始數據，添加 ID 字段
      final rawData = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // 輸出第一個選手的數據，幫助診斷
      if (rawData.isNotEmpty) {
        debugPrint('原始選手數據示例: ${rawData[0]}');
      }

      return rawData;
    } catch (e) {
      debugPrint('直接加載原始參賽者數據失敗: $e');
      return [];
    }
  }

  /// 將田賽結果從舊的field_results集合遷移到final_results集合
  ///
  /// 這是一個一次性操作，用於數據遷移
  Future<int> migrateFieldResults(String competitionId) async {
    try {
      // 獲取field_results中的所有文檔
      final snapshot = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('field_results')
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('沒有找到需要遷移的田賽結果');
        return 0;
      }

      int migratedCount = 0;
      final batch = _firestore.batch();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final docId = 'field_${doc.id}'; // 添加前綴，避免與其他類型結果衝突

        // 確保數據包含必要的字段
        if (!data.containsKey('eventName')) {
          data['eventName'] = doc.id.split('_').first;
        }

        if (!data.containsKey('eventType')) {
          data['eventType'] = '田賽';
        }

        if (!data.containsKey('lastUpdated')) {
          data['lastUpdated'] =
              data['recordedAt'] ?? FieldValue.serverTimestamp();
        }

        // 添加到批處理
        final newDocRef = _firestore
            .collection('competitions')
            .doc(competitionId)
            .collection('final_results')
            .doc(docId);

        batch.set(newDocRef, data, SetOptions(merge: true));
        migratedCount++;
      }

      // 執行批處理
      if (migratedCount > 0) {
        await batch.commit();
        debugPrint('成功遷移 $migratedCount 個田賽結果到final_results集合');
      }

      return migratedCount;
    } catch (e) {
      debugPrint('遷移田賽結果失敗: $e');
      return 0;
    }
  }
}
