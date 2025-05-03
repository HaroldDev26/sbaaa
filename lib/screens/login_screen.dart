import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/colors.dart';
import '../widgets/custom_button.dart';
import '../widgets/text_field_input.dart';
import '../resources/auth_methods.dart';
import 'competition_management_screen.dart';
import 'athlete_home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _selectedRole = 'public'; // 默認角色

  @override
  void initState() {
    super.initState();
    // 延遲執行，等待 context 完全初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _extractArguments();
    });
  }

  void _extractArguments() {
    // 從路由參數中提取角色信息
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments != null && arguments is Map<String, dynamic>) {
      setState(() {
        _selectedRole = arguments['selectedRole'] ?? 'public';
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> loginUser() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請填寫電子郵件和密碼')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 使用 AuthMethods 進行登入
      final authMethods = AuthMethods();
      String res = await authMethods.loginUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return; // 檢查組件是否還掛載

      if (res == "success") {
        // 獲取用戶資料
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .get();

        if (!mounted) return; // 再次檢查組件是否還掛載

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          String userRole = userData['role'] ?? 'public';

          // 根據用戶角色導航到不同頁面
          if (userRole == 'referee') {
            // 裁判角色導航到比賽管理頁面
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const CompetitionManagementScreen(),
              ),
            );
          } else if (userRole == 'athlete') {
            // 運動員角色導航到運動員首頁
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => AthleteHomeScreen(
                  userId: _auth.currentUser!.uid,
                ),
              ),
            );
          } else {
            // 其他角色導航到個人資料頁面
            Navigator.pushReplacementNamed(context, '/athlete-edit-profile');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('找不到用戶資料')),
          );
        }
      } else {
        // 登入失敗
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res)),
        );
      }
    } catch (e) {
      if (!mounted) return; // 檢查組件是否還掛載

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登入失敗: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重設密碼'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('請輸入您的電子郵件，我們將發送重設密碼的連結'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: '電子郵件',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _auth.sendPasswordResetEmail(
                  email: emailController.text.trim(),
                );

                if (!mounted) return;

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('重設密碼連結已發送至您的郵箱')),
                );
              } catch (e) {
                if (!mounted) return;

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('發送失敗: $e')),
                );
              }
            },
            child: const Text('發送'),
          ),
        ],
      ),
    );
  }

  // 將英文角色標識轉換為中文顯示
  String _getRoleDisplayName(String roleIdentifier) {
    switch (roleIdentifier) {
      case 'athlete':
        return '運動員';
      case 'referee':
        return '裁判';
      case 'public':
        return '公眾';
      default:
        return '用戶';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 獲取角色的顯示名稱
    String roleDisplayName = _getRoleDisplayName(_selectedRole);

    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '返回',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: _showForgotPasswordDialog,
            child: const Text(
              '忘記密碼？',
              style: TextStyle(color: primaryColor),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            width: double.infinity,
            height: MediaQuery.of(context).size.height -
                AppBar().preferredSize.height -
                MediaQuery.of(context).padding.top -
                MediaQuery.of(context).padding.bottom,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                // 顯示當前選擇的角色
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryColor, width: 1.0),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        '當前選擇: $roleDisplayName',
                        style: const TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '電子郵件',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextFieldInput(
                  textEditingController: _emailController,
                  hintText: 'your@email.com',
                  textInputType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 24),
                const Text(
                  '密碼',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextFieldInput(
                  textEditingController: _passwordController,
                  hintText: '••••••••',
                  textInputType: TextInputType.text,
                  isPass: true,
                ),
                const Spacer(),
                CustomButton(
                  text: '登入',
                  onTap: loginUser,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: '建立新帳號',
                  onTap: _navigateToRegister,
                  isOutlined: true,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
