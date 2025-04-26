import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 比賽報名相關操作的服務類
class RegistrationMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 獲取比賽的報名表格設定
  Future<Map<String, dynamic>?> getRegistrationForm(
      String competitionId) async {
    try {
      final querySnapshot = await _firestore
          .collection('registrationForms')
          .where('competitionId', isEqualTo: competitionId)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final formDoc = querySnapshot.docs.first;
      return {
        'id': formDoc.id,
        ...formDoc.data(),
      };
    } catch (e) {
      throw Exception('獲取報名表格設定失敗: $e');
    }
  }

  /// 創建或更新報名表格設定
  Future<String> createOrUpdateRegistrationForm({
    required String competitionId,
    required String competitionName,
    required List<Map<String, dynamic>> fields,
    required List<Map<String, dynamic>> availableEvents,
    required List<Map<String, dynamic>> ageGroups,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('請先登入');
      }

      // 準備要儲存的數據
      final formData = {
        "competitionId": competitionId,
        "competitionName": competitionName,
        "fields": fields,
        "availableEvents": availableEvents,
        "ageGroups": ageGroups,
        "createdBy": currentUser.uid,
        "updatedAt": FieldValue.serverTimestamp()
      };

      // 檢查是否已存在表格
      final querySnapshot = await _firestore
          .collection('registrationForms')
          .where('competitionId', isEqualTo: competitionId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // 更新現有表格
        final formId = querySnapshot.docs.first.id;
        await _firestore
            .collection('registrationForms')
            .doc(formId)
            .update(formData);
        return formId;
      } else {
        // 創建新表格
        formData["createdAt"] = FieldValue.serverTimestamp();
        final docRef =
            await _firestore.collection('registrationForms').add(formData);
        return docRef.id;
      }
    } catch (e) {
      throw Exception('儲存報名表格設定失敗: $e');
    }
  }

  /// 提交運動員報名資料
  Future<String> submitRegistration({
    required String competitionId,
    required String competitionName,
    required Map<String, dynamic> formData,
    required List<String> selectedEvents,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('請先登入');
      }

      // 創建參與者記錄
      final String participantDocId = '${competitionId}_${currentUser.uid}';
      await _firestore.collection('participants').doc(participantDocId).set({
        'competitionId': competitionId,
        'competitionName': competitionName,
        'userId': currentUser.uid,
        'events': selectedEvents,
        'status': 'pending',
        'formData': formData,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      // 更新用戶記錄，將比賽ID添加到用戶的比賽列表中
      await _firestore.collection('users').doc(currentUser.uid).update({
        'competitions': FieldValue.arrayUnion([competitionId])
      });

      return "success";
    } catch (e) {
      throw Exception('提交報名資料失敗: $e');
    }
  }

  /// 獲取比賽的所有報名者
  Future<List<Map<String, dynamic>>> getRegistrations(
      String competitionId) async {
    try {
      final List<Map<String, dynamic>> registrations = [];

      // 從participants集合獲取數據
      final participantsSnapshot = await _firestore
          .collection('participants')
          .where('competitionId', isEqualTo: competitionId)
          .get();

      for (var doc in participantsSnapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String;
        final formData = data['formData'] as Map<String, dynamic>;
        final events = (data['events'] as List<dynamic>).cast<String>();
        final status = data['status'] as String;

        // 獲取報名者的用戶資料
        final userDoc = await _firestore.collection('users').doc(userId).get();
        String userName = formData['name'] ?? '未知用戶';
        String userEmail = '';
        String userSchool = formData['school'] ?? '';
        String userClass = formData['class'] ?? '';
        String ageGroup = formData['ageGroup'] ?? '';

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          userEmail = userData['email'] ?? '';
          if (userName == '未知用戶') {
            userName = userData['username'] ?? '未知用戶';
          }
          if (userSchool.isEmpty) {
            userSchool = userData['school'] ?? '';
          }
        }

        registrations.add({
          'id': doc.id,
          'userId': userId,
          'competitionId': data['competitionId'],
          'events': events,
          'status': status,
          'formData': formData,
          'submittedAt': data['submittedAt'],
          'userName': userName,
          'userEmail': userEmail,
          'userSchool': userSchool,
          'userClass': userClass,
          'ageGroup': ageGroup,
        });
      }

      return registrations;
    } catch (e) {
      throw Exception('獲取報名者列表失敗: $e');
    }
  }

  /// 更新報名狀態
  Future<String> updateRegistrationStatus({
    required String competitionId,
    required String userId,
    required String status,
  }) async {
    try {
      final String participantDocId = '${competitionId}_$userId';
      await _firestore.collection('participants').doc(participantDocId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return "success";
    } catch (e) {
      throw Exception('更新報名狀態失敗: $e');
    }
  }

  /// 獲取用戶的報名記錄
  Future<List<Map<String, dynamic>>> getUserRegistrations(String userId) async {
    try {
      final List<Map<String, dynamic>> registrations = [];

      // 從participants集合獲取數據
      final participantsSnapshot = await _firestore
          .collection('participants')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in participantsSnapshot.docs) {
        final data = doc.data();
        final competitionId = data['competitionId'] as String;

        // 獲取比賽詳情
        final competitionDoc = await _firestore
            .collection('competitions')
            .doc(competitionId)
            .get();

        String competitionName = data['competitionName'] ?? '未知比賽';
        String competitionVenue = '';
        String competitionDate = '';

        if (competitionDoc.exists) {
          final competitionData = competitionDoc.data() as Map<String, dynamic>;
          competitionName = competitionData['name'] ?? competitionName;
          competitionVenue = competitionData['venue'] ?? '';
          competitionDate = competitionData['date'] ?? '';
        }

        registrations.add({
          'id': doc.id,
          'competitionId': competitionId,
          'competitionName': competitionName,
          'competitionVenue': competitionVenue,
          'competitionDate': competitionDate,
          'events': (data['events'] as List<dynamic>).cast<String>(),
          'status': data['status'] as String,
          'formData': data['formData'] as Map<String, dynamic>,
          'submittedAt': data['submittedAt'],
        });
      }

      return registrations;
    } catch (e) {
      throw Exception('獲取用戶報名記錄失敗: $e');
    }
  }

  /// 檢查用戶是否已報名比賽
  Future<bool> isUserRegistered({
    required String competitionId,
    required String userId,
  }) async {
    try {
      final String participantDocId = '${competitionId}_$userId';
      final docSnapshot = await _firestore
          .collection('participants')
          .doc(participantDocId)
          .get();

      return docSnapshot.exists;
    } catch (e) {
      throw Exception('檢查用戶報名狀態失敗: $e');
    }
  }

  /// 刪除報名記錄
  Future<String> deleteRegistration({
    required String competitionId,
    required String userId,
  }) async {
    try {
      final String participantDocId = '${competitionId}_$userId';
      await _firestore
          .collection('participants')
          .doc(participantDocId)
          .delete();

      // 從用戶的比賽列表中移除此比賽
      await _firestore.collection('users').doc(userId).update({
        'competitions': FieldValue.arrayRemove([competitionId])
      });

      return "success";
    } catch (e) {
      throw Exception('刪除報名記錄失敗: $e');
    }
  }
}
