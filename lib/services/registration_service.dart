import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class RegistrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 檢查用戶是否已報名比賽
  Future<bool> isUserRegistered(String competitionId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final query = await _firestore
          .collection('registrations')
          .where('athleteId', isEqualTo: user.uid)
          .where('competitionId', isEqualTo: competitionId)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('檢查報名狀態出錯: $e');
      return false;
    }
  }

  // 報名比賽
  Future<bool> registerForCompetition(
      String competitionId, Map<String, dynamic> formData) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // 檢查是否已報名
      if (await isUserRegistered(competitionId)) {
        return true; // 已經報名了，返回成功
      }

      // 創建報名記錄
      await _firestore.collection('registrations').add({
        'athleteId': user.uid,
        'competitionId': competitionId,
        'formData': formData,
        'registeredAt': FieldValue.serverTimestamp(),
        'status': 'registered'
      });

      return true;
    } catch (e) {
      debugPrint('報名比賽出錯: $e');
      return false;
    }
  }

  // 獲取用戶的報名表單數據
  Future<Map<String, dynamic>?> getRegistrationForm(
      String competitionId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final query = await _firestore
          .collection('registrations')
          .where('athleteId', isEqualTo: user.uid)
          .where('competitionId', isEqualTo: competitionId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.data()['formData'] as Map<String, dynamic>?;
      }

      return null;
    } catch (e) {
      debugPrint('獲取報名表單出錯: $e');
      return null;
    }
  }

  // 獲取某比賽的所有報名者
  Future<List<Map<String, dynamic>>> getCompetitionRegistrations(
      String competitionId) async {
    try {
      final query = await _firestore
          .collection('registrations')
          .where('competitionId', isEqualTo: competitionId)
          .get();

      return query.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('獲取比賽報名列表出錯: $e');
      return [];
    }
  }
}
