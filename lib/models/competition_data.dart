import 'package:cloud_firestore/cloud_firestore.dart';

/// 競賽數據模型，作為全局數據共享
class CompetitionData {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 生成比賽專屬的集合名稱
  static String getCompetitionCollectionName(String competitionId) {
    return 'competition_$competitionId';
  }

  /// 生成項目專屬的文檔名稱
  static String getEventDocName(String eventName) {
    return eventName.replaceAll(' ', '_').toLowerCase();
  }

  /// 保存參賽者數據到Firebase
  static Future<void> saveParticipantData({
    required String competitionId,
    required String participantId,
    required Map<String, dynamic> data,
  }) async {
    final collectionName = getCompetitionCollectionName(competitionId);

    try {
      await _firestore.collection(collectionName).doc(participantId).set(
            data,
            SetOptions(merge: true),
          );
    } catch (e) {
      throw Exception('保存參賽者數據失敗: $e');
    }
  }

  /// 獲取參賽者數據
  static Future<Map<String, dynamic>?> getParticipantData({
    required String competitionId,
    required String participantId,
  }) async {
    final collectionName = getCompetitionCollectionName(competitionId);

    try {
      final doc =
          await _firestore.collection(collectionName).doc(participantId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      throw Exception('獲取參賽者數據失敗: $e');
    }
  }

  /// 獲取指定項目的所有參賽者
  static Future<List<Map<String, dynamic>>> getEventParticipants({
    required String competitionId,
    required String eventName,
    String? ageGroup,
    String? gender,
  }) async {
    final collectionName = getCompetitionCollectionName(competitionId);

    try {
      Query query = _firestore
          .collection(collectionName)
          .where('status', isEqualTo: 'approved')
          .where('events', arrayContains: eventName);

      if (ageGroup != null && ageGroup.isNotEmpty) {
        query = query.where('ageGroup', isEqualTo: ageGroup);
      }

      if (gender != null && gender.isNotEmpty) {
        query = query.where('gender', isEqualTo: gender);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('獲取參賽者數據失敗: $e');
    }
  }

  /// 保存項目結果數據
  static Future<void> saveEventResults({
    required String competitionId,
    required String eventName,
    required Map<String, dynamic> results,
  }) async {
    try {
      // 保存到專屬的比賽項目結果集合
      await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('final_results')
          .doc(getEventDocName(eventName))
          .set({
        'eventName': eventName,
        'results': results,
        'recordedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 更新項目狀態摘要
      await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('event_summaries')
          .doc(getEventDocName(eventName))
          .set({
        'hasResults': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('保存結果數據失敗: $e');
    }
  }

  /// 獲取項目結果數據
  static Future<Map<String, dynamic>?> getEventResults({
    required String competitionId,
    required String eventName,
  }) async {
    try {
      final doc = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('final_results')
          .doc(getEventDocName(eventName))
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      throw Exception('獲取結果數據失敗: $e');
    }
  }

  /// 獲取項目類型定義
  static Future<Map<String, String>> getEventTypes(String competitionId) async {
    try {
      final doc = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .collection('score_setup')
          .doc('event_types')
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('eventTypes')) {
          return Map<String, String>.from(
              data['eventTypes'] as Map<dynamic, dynamic>);
        }
      }
      return {};
    } catch (e) {
      throw Exception('獲取項目類型失敗: $e');
    }
  }
}
