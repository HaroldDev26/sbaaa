import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class AuthMethods {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current logged-in user
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

  // Register new user
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
    String res = "An unexpected error occurred";
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        // Register Firebase Auth
        UserCredential cred = await _auth.createUserWithEmailAndPassword(
            email: email, password: password);

        // Create user model
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
        res = "Please fill in all required fields";
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        res = "Email address is already registered";
      } else if (e.code == 'weak-password') {
        res = "Password is too weak";
      } else if (e.code == 'invalid-email') {
        res = "Invalid email format";
      } else {
        res = "Registration failed: ${e.message}";
      }
    } catch (error) {
      res = "Registration failed: $error";
    }
    return res;
  }

  // Login user
  Future<String> loginUser({
    required String email,
    required String password,
  }) async {
    String res = "An unexpected error occurred";
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        // Login to Firebase Auth
        await _auth.signInWithEmailAndPassword(
            email: email, password: password);
        res = "success";
      } else {
        res = "Please enter email and password";
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        res = "No account exists with this email address";
      } else if (e.code == 'wrong-password') {
        res = "Incorrect password";
      } else if (e.code == 'invalid-email') {
        res = "Invalid email format";
      } else if (e.code == 'user-disabled') {
        res = "This account has been disabled";
      } else if (e.code == 'too-many-requests') {
        res = "Too many login attempts. Please try again later";
      } else {
        res = "Login failed: ${e.message}";
      }
    } catch (err) {
      res = "Login failed: $err";
    }
    return res;
  }

  // Logout user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Update user data
  Future<String> updateUserData(Map<String, dynamic> userData) async {
    String res = "An unexpected error occurred";
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore
            .collection("users")
            .doc(currentUser.uid)
            .update(userData);
        res = "success";
      } else {
        res = "User not logged in";
      }
    } catch (error) {
      res = "Update failed: $error";
    }
    return res;
  }
}
