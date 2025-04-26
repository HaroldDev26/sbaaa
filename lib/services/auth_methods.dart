import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class AuthMethods {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 獲取當前登入用戶
  Future<UserModel?> getCurrentUser() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (doc.exists) {
        return UserModel.fromDoc(doc);
      }
    }
    return null;
  }

  // 註冊新用戶
  Future<String> signUpUser({
    required String email,
    required String password,
    required String username,
    required String role,
    String? school,
    String? phone,
    String? gender,
    String? birthday,
  }) async {
    String res = "Some error occurred";
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        // 註冊 Firebase Auth
        UserCredential cred = await _auth.createUserWithEmailAndPassword(
            email: email, password: password);

        // 創建用戶模型
        UserModel user = UserModel(
          uid: cred.user!.uid,
          email: email,
          username: username,
          role: role,
          phone: phone,
          gender: gender,
          birthday: birthday,
          school: school,
          createdAt: DateTime.now().toIso8601String(),
        );

        await _firestore
            .collection("users")
            .doc(cred.user!.uid)
            .set(user.toMap());

        res = "success";
      } else {
        res = "請輸入所有必填欄位";
      }
    } catch (error) {
      res = error.toString();
    }
    return res;
  }

  // 登入用戶
  Future<String> loginUser({
    required String email,
    required String password,
  }) async {
    String res = "Some error occurred";
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        // 登入 Firebase Auth
        await _auth.signInWithEmailAndPassword(
            email: email, password: password);
        res = "success";
      } else {
        res = "請輸入電子郵件和密碼";
      }
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  // 登出用戶
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 更新用戶資料
  Future<String> updateUserData(Map<String, dynamic> userData) async {
    String res = "Some error occurred";
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore
            .collection("users")
            .doc(currentUser.uid)
            .update(userData);
        res = "success";
      } else {
        res = "用戶未登入";
      }
    } catch (error) {
      res = error.toString();
    }
    return res;
  }
}
