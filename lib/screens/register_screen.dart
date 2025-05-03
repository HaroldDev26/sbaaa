import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'athlete_home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _gender;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthdayController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  // 顯示日期選擇器並更新日期
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          DateTime.now().subtract(const Duration(days: 365 * 18)), // 預設18歲
      firstDate: DateTime(1940), // 最早可選日期
      lastDate: DateTime.now(), // 最晚可選日期（今天）
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1A237E), // 日期選擇器主要顏色
              onPrimary: Colors.white, // 選中日期的文字顏色
              onSurface: Colors.black, // 日曆文字顏色
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1A237E), // 按鈕文字顏色
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (!mounted) return; // 添加 mounted 檢查

    if (picked != null) {
      setState(() {
        _birthdayController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('註冊', style: TextStyle(color: Colors.black)),
      ),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('個人資料',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      _buildTextField(
                          label: '電子郵件',
                          hint: 'your@email.com',
                          controller: _emailController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '請輸入電子郵件';
                            }
                            if (!value.contains('@') || !value.contains('.')) {
                              return '請輸入有效的電子郵件';
                            }
                            return null;
                          }),
                      _buildTextField(
                        label: '電話號碼',
                        hint: '0912345678',
                        controller: _phoneController,
                      ),
                      // 日期選擇欄位
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextFormField(
                          controller: _birthdayController,
                          readOnly: true, // 設為只讀，不允許直接輸入
                          decoration: InputDecoration(
                            labelText: '出生日期',
                            hintText: '選擇日期',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () => _selectDate(context),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '請選擇出生日期';
                            }
                            return null;
                          },
                          onTap: () => _selectDate(context), // 點擊欄位也會彈出選擇器
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: '性別',
                          border: OutlineInputBorder(),
                        ),
                        value: _gender,
                        items: ['男', '女']
                            .map((g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(g),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _gender = value),
                        validator: (value) => value == null ? '請選擇性別' : null,
                      ),
                      const SizedBox(height: 10),
                      _buildTextField(
                        label: '密碼',
                        obscureText: true,
                        controller: _passwordController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '請輸入密碼';
                          }
                          if (value.length < 6 ||
                              !RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)')
                                  .hasMatch(value)) {
                            return '密碼須包含大小寫字母與數字，且長度不少於6位';
                          }
                          return null;
                        },
                      ),
                      _buildTextField(
                        label: '確認密碼',
                        obscureText: true,
                        controller: _confirmPasswordController,
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return '密碼不一致';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '密碼必須包含大小寫字母和數字',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _onRegisterPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A237E),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            '註冊',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ⏳ Loading 遮罩
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    String? hint,
    bool obscureText = false,
    TextEditingController? controller,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        validator: validator ??
            (value) {
              if (value == null || value.isEmpty) {
                return '請輸入$label';
              }
              return null;
            },
      ),
    );
  }

  Future<void> _onRegisterPressed() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final auth = FirebaseAuth.instance;
        final firestore = FirebaseFirestore.instance;

        UserCredential userCred = await auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (!mounted) return; // 添加 mounted 檢查

        // ✅ 自動寫入 Firestore 的 users 集合
        await firestore.collection('users').doc(userCred.user!.uid).set({
          'uid': userCred.user!.uid,
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'birthday': _birthdayController.text,
          'role': 'athlete', // 或 future admin 用來區分
          'gender': _gender,
          'createdAt': FieldValue.serverTimestamp(),
          'username': _emailController.text.split('@')[0], // 新增用戶名欄位，使用郵箱前綴
        });

        if (!mounted) return; // 添加 mounted 檢查

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('註冊成功！')),
        );

        // 註冊成功後直接導向運動員首頁
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AthleteHomeScreen(
                userId: userCred.user!.uid,
              ),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        if (!mounted) return; // 添加 mounted 檢查

        String msg = '註冊失敗';
        if (e.code == 'email-already-in-use') {
          msg = '該電子郵件已註冊';
        } else if (e.code == 'invalid-email') {
          msg = '電子郵件格式錯誤';
        } else if (e.code == 'weak-password') {
          msg = '密碼太弱，請至少6位數';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      } finally {
        if (mounted) {
          // 添加 mounted 檢查
          setState(() => _isLoading = false);
        }
      }
    }
  }
}
