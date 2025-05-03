import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'registration_service.dart';
import 'package:flutter/foundation.dart';

class CompetitionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RegistrationService _registrationService = RegistrationService();

  // 緩存機制
  final Map<String, dynamic> _cache = {};

  // 獲取可報名的比賽列表
  Future<List<Map<String, dynamic>>> getAvailableCompetitions() async {
    try {
      // 檢查緩存
      if (_cache.containsKey('availableCompetitions')) {
        final cacheTime = _cache['availableCompetitionsTime'] as DateTime;
        // 如果緩存時間不超過10分鐘，直接返回緩存
        if (DateTime.now().difference(cacheTime).inMinutes < 10) {
          return List<Map<String, dynamic>>.from(
              _cache['availableCompetitions']);
        }
      }

      // 獲取所有比賽
      final competitionDocs = await _firestore.collection('competitions').get();
      final currentUser = _auth.currentUser;

      List<Map<String, dynamic>> competitions = [];

      // 處理比賽數據
      for (var doc in competitionDocs.docs) {
        final data = doc.data();
        final String competitionId = doc.id;

        // 檢查是否有報名表格
        bool hasRegistrationForm = false;
        if (data['metadata'] != null &&
            data['metadata']['registration_form_created'] == true) {
          hasRegistrationForm = true;
        }

        // 檢查報名截止日期
        bool isDeadlinePassed = false;
        if (data['metadata'] != null &&
            data['metadata']['registration_form'] != null &&
            data['metadata']['registration_form']['deadline'] != null) {
          final deadline = data['metadata']['registration_form']['deadline'];
          if (deadline is Timestamp) {
            isDeadlinePassed = deadline.toDate().isBefore(DateTime.now());
          }
        }

        // 使用報名服務檢查是否已報名
        bool alreadyRegistered = false;
        if (currentUser != null) {
          alreadyRegistered =
              await _registrationService.isUserRegistered(competitionId);
        }

        final competition = {
          ...data,
          'id': competitionId,
          'alreadyRegistered': alreadyRegistered,
          'isDeadlinePassed': isDeadlinePassed,
          'hasRegistrationForm': hasRegistrationForm,
        };

        competitions.add(competition);
      }

      // 更新緩存
      _cache['availableCompetitions'] = competitions;
      _cache['availableCompetitionsTime'] = DateTime.now();

      return competitions;
    } catch (e) {
      debugPrint('獲取比賽列表出錯: $e');
      return [];
    }
  }

  // 獲取單個比賽詳情
  Future<Map<String, dynamic>?> getCompetitionDetails(
      String competitionId) async {
    try {
      // 檢查緩存
      final cacheKey = 'competition_$competitionId';
      if (_cache.containsKey(cacheKey)) {
        final cacheTime = _cache['${cacheKey}_time'] as DateTime;
        // 如果緩存時間不超過10分鐘，直接返回緩存
        if (DateTime.now().difference(cacheTime).inMinutes < 10) {
          return Map<String, dynamic>.from(_cache[cacheKey]);
        }
      }

      // 獲取比賽詳情
      final competitionDoc =
          await _firestore.collection('competitions').doc(competitionId).get();

      if (!competitionDoc.exists) {
        return null;
      }

      final data = competitionDoc.data()!;
      data['id'] = competitionId;

      // 使用報名服務檢查是否已報名
      bool isRegistered = false;
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        isRegistered =
            await _registrationService.isUserRegistered(competitionId);
      }

      // 檢查報名表是否存在
      bool hasRegistrationForm = false;
      if (data['metadata'] != null &&
          data['metadata']['registration_form_created'] == true) {
        hasRegistrationForm = true;
      }

      // 檢查報名截止日期
      bool isDeadlinePassed = false;
      if (data['metadata'] != null &&
          data['metadata']['registration_form'] != null &&
          data['metadata']['registration_form']['deadline'] != null) {
        final deadline = data['metadata']['registration_form']['deadline'];
        if (deadline is Timestamp) {
          isDeadlinePassed = deadline.toDate().isBefore(DateTime.now());
        }
      }

      final competitionDetails = {
        ...data,
        'alreadyRegistered': isRegistered,
        'isDeadlinePassed': isDeadlinePassed,
        'hasRegistrationForm': hasRegistrationForm,
      };

      // 更新緩存
      _cache[cacheKey] = competitionDetails;
      _cache['${cacheKey}_time'] = DateTime.now();

      return competitionDetails;
    } catch (e) {
      debugPrint('獲取比賽詳情出錯: $e');
      return null;
    }
  }

  // 清除緩存
  void clearCache() {
    _cache.clear();
  }

  // 清除特定比賽的緩存
  void clearCompetitionCache(String competitionId) {
    _cache.remove('competition_$competitionId');
    _cache.remove('competition_${competitionId}_time');
    // 同時清除競賽列表緩存，因為可能發生變化
    _cache.remove('availableCompetitions');
    _cache.remove('availableCompetitionsTime');
  }

  // 設置比賽列表的監聽器
  Stream<QuerySnapshot> getCompetitionsStream() {
    return _firestore.collection('competitions').snapshots();
  }

  // 設置用戶報名記錄的監聽器
  Stream<QuerySnapshot> getUserRegistrationsStream(String userId) {
    return _firestore
        .collection('participants')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }
}
