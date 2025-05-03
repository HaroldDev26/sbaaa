import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../utils/colors.dart';
import '../utils/utils.dart';
import 'package:flutter/foundation.dart';

class AthleteEditProfileScreen extends StatefulWidget {
  const AthleteEditProfileScreen({Key? key}) : super(key: key);

  @override
  State<AthleteEditProfileScreen> createState() =>
      _AthleteEditProfileScreenState();
}

class _AthleteEditProfileScreenState extends State<AthleteEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 表單控制器
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _schoolController = TextEditingController();

  String? _selectedGender;
  bool _isLoading = true;
  Map<String, dynamic> _userData = {};
  int? _calculatedAge;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _birthdayController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  // 加載用戶數據
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();

        if (userDoc.exists) {
          setState(() {
            _userData = userDoc.data() as Map<String, dynamic>;

            // 填充表單
            _usernameController.text = _userData['username'] ?? '';
            _phoneController.text = _userData['phone'] ?? '';
            _birthdayController.text = _userData['birthday'] ?? '';
            _schoolController.text = _userData['school'] ?? '';
            _selectedGender = _userData['gender'];

            // 計算年齡
            if (_userData['birthday'] != null &&
                _userData['birthday'].isNotEmpty) {
              _calculatedAge = calculateAge(_userData['birthday']);
            }
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加載用戶數據失敗: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 選擇生日
  Future<void> _selectBirthday() async {
    final DateTime now = DateTime.now();
    DateTime initialDate;

    try {
      if (_birthdayController.text.isNotEmpty) {
        initialDate = DateTime.parse(_birthdayController.text);
      } else {
        initialDate = now.subtract(const Duration(days: 365 * 18)); // 默認18歲
      }
    } catch (e) {
      initialDate = now.subtract(const Duration(days: 365 * 18));
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1940),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _birthdayController.text = DateFormat('yyyy-MM-dd').format(picked);
        _calculatedAge = calculateAge(_birthdayController.text);
      });
    }
  }

  // 保存用戶數據
  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        // 準備要更新的數據
        final updatedData = {
          'username': _usernameController.text,
          'phone': _phoneController.text,
          'birthday': _birthdayController.text,
          'school': _schoolController.text,
          'gender': _selectedGender,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // 更新Firestore數據
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .update(updatedData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('個人資料已更新！')),
        );

        Navigator.pop(context, true); // 返回並傳遞更新成功標誌
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新用戶數據失敗: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('編輯個人資料'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 頭像部分
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: _userData['profileImage'] != null
                                ? NetworkImage(_userData['profileImage'])
                                : null,
                            child: _userData['profileImage'] == null
                                ? const Icon(Icons.person,
                                    size: 50, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              // 這裡可以添加更新頭像的功能
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('更新頭像功能將在未來版本提供')),
                              );
                            },
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('更換頭像'),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 30),

                    // 基本信息表單
                    const Text(
                      '基本資料',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 用戶名
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: '用戶名稱',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '請輸入用戶名稱';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 電話號碼
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: '電話號碼',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // 生日
                    GestureDetector(
                      onTap: _selectBirthday,
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: _birthdayController,
                          decoration: InputDecoration(
                            labelText: '出生日期',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.cake),
                            suffixIcon: _calculatedAge != null
                                ? Chip(
                                    label: Text('$_calculatedAge 歲'),
                                    backgroundColor:
                                        primaryColor.withValues(alpha: 0.1),
                                  )
                                : null,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '請選擇出生日期';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 性別
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: '性別',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.wc),
                      ),
                      items: const [
                        DropdownMenuItem(value: '男', child: Text('男')),
                        DropdownMenuItem(value: '女', child: Text('女')),
                        DropdownMenuItem(value: '其他', child: Text('其他')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '請選擇性別';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 學校
                    TextFormField(
                      controller: _schoolController,
                      decoration: const InputDecoration(
                        labelText: '學校',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.school),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // 顯示獲取的比賽組別信息
                    if (_calculatedAge != null)
                      FutureBuilder<List<Map<String, dynamic>>>(
                          future: _getEligibleAgeGroups(_calculatedAge!),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '您可參加的比賽組別',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Column(
                                    children: snapshot.data!.map((group) {
                                      return ListTile(
                                        leading: Icon(
                                          Icons.groups,
                                          color: Color(int.parse(
                                            (group['color'] as String)
                                                .replaceFirst('#', '0xFF'),
                                          )),
                                        ),
                                        title: Text(group['name']),
                                        subtitle: Text(
                                            '${group['minAge']}-${group['maxAge']}歲'),
                                        dense: true,
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            );
                          }),

                    const SizedBox(height: 30),

                    // 保存按鈕
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveUserData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                '保存資料',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // 獲取適合用戶年齡的組別
  Future<List<Map<String, dynamic>>> _getEligibleAgeGroups(int age) async {
    List<Map<String, dynamic>> eligibleGroups = [];

    try {
      // 獲取所有比賽
      final competitionsSnapshot =
          await _firestore.collection('competitions').get();

      for (var doc in competitionsSnapshot.docs) {
        final data = doc.data();

        if (data['metadata'] != null &&
            data['metadata']['age_groups'] != null) {
          final List<dynamic> ageGroups = data['metadata']['age_groups'];

          for (var group in ageGroups) {
            if (group is Map<String, dynamic> &&
                group.containsKey('minAge') &&
                group.containsKey('maxAge') &&
                group.containsKey('name')) {
              final int minAge = group['minAge'];
              final int maxAge = group['maxAge'];

              // 檢查用戶年齡是否在範圍內
              if (age >= minAge && age <= maxAge) {
                // 檢查此組別是否已添加
                bool exists = false;
                for (var existing in eligibleGroups) {
                  if (existing['name'] == group['name']) {
                    exists = true;
                    break;
                  }
                }

                if (!exists) {
                  final Map<String, dynamic> groupInfo = {
                    'name': group['name'],
                    'minAge': minAge,
                    'maxAge': maxAge,
                    'color': group['color'] ?? '#4CAF50',
                  };

                  eligibleGroups.add(groupInfo);
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('獲取年齡組別數據失敗: $e');
    }

    return eligibleGroups;
  }
}
