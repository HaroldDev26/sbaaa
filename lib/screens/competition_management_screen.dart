import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../widgets/custom_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'manage_competitions_screen.dart';
import 'create_competition_screen.dart';

class CompetitionManagementScreen extends StatefulWidget {
  const CompetitionManagementScreen({Key? key}) : super(key: key);

  @override
  State<CompetitionManagementScreen> createState() =>
      _CompetitionManagementScreenState();
}

class _CompetitionManagementScreenState
    extends State<CompetitionManagementScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isJudge = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 獲取當前登入用戶
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        // 從 Firestore 獲取用戶資料
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          // 檢查用戶角色是否為裁判
          if (userData['role'] == 'referee') {
            setState(() {
              _isJudge = true;
              _isLoading = false;
            });
          } else {
            setState(() {
              _errorMessage = '只有裁判才能訪問此頁面';
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('您沒有權限管理比賽')),
            );
            Navigator.pop(context);
          }
        } else {
          setState(() {
            _errorMessage = '找不到用戶資料';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = '請先登入';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '發生錯誤: $e';
        _isLoading = false;
      });
    }
  }

  void _navigateToManageCompetitions() {
    // 導航到管理比賽頁面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ManageCompetitionsScreen(),
      ),
    );
  }

  void _navigateToAddCompetition() {
    // 導航到新增比賽頁面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateCompetitionScreen(),
      ),
    ).then((result) {
      if (result == true) {
        // 如果創建成功，顯示提示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('比賽已成功創建')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('比賽管理系統')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isJudge) {
      return Scaffold(
        appBar: AppBar(title: const Text('比賽管理系統')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: '返回',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('比賽管理系統', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '比賽管理系統',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              _buildOptionCard(
                '管理比賽',
                '查看和管理現有比賽',
                Icons.event_note,
                _navigateToManageCompetitions,
              ),
              const SizedBox(height: 20),
              _buildOptionCard(
                '新增比賽',
                '申請新增比賽項目',
                Icons.add_box,
                _navigateToAddCompetition,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    String title,
    String description,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.black, width: 1.0),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: primaryColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
