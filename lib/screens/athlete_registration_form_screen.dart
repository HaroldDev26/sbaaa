import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../utils/age_group_handler.dart';
import '../utils/events_handler.dart';

class AthleteRegistrationFormScreen extends StatefulWidget {
  final String competitionId;
  final String competitionName;
  final bool viewMode;

  const AthleteRegistrationFormScreen({
    Key? key,
    required this.competitionId,
    required this.competitionName,
    this.viewMode = false,
  }) : super(key: key);

  @override
  State<AthleteRegistrationFormScreen> createState() =>
      _AthleteRegistrationFormScreenState();
}

class _AthleteRegistrationFormScreenState
    extends State<AthleteRegistrationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _hasSubmitted = false;
  bool _isSubmitting = false;
  double _formProgress = 0.0;
  List<Map<String, dynamic>> _formFields = [];
  Map<String, dynamic> _formData = {};
  Map<String, dynamic> _userData = {};
  String? _formError;
  Map<String, dynamic>? _userSubmittedData;
  int _currentStep = 0;
  int? _calculatedAge;
  String? _calculatedAgeGroup;
  List<Map<String, dynamic>> _ageGroups = [];
  List<Map<String, dynamic>> _availableEvents = [];
  List<String> _selectedEvents = [];
  int _maxEventsAllowed = 0;

  // 表單控制器
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadRegistrationForm();
  }

  @override
  void dispose() {
    // 釋放所有控制器
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // 載入用戶基本資料
  Future<void> _loadUserData() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          setState(() {
            _userData = userDoc.data() as Map<String, dynamic>;
          });

          // 如果有出生日期，計算年齡和年齡組別
          if (_userData.containsKey('birthday') &&
              _userData['birthday'] != null) {
            DateTime? birthDate;

            // 嘗試解析不同格式的出生日期
            if (_userData['birthday'] is String) {
              try {
                birthDate = DateTime.parse(_userData['birthday']);
              } catch (e) {
                debugPrint('無法解析出生日期字符串: $e');
                // 嘗試使用DateFormat解析常見格式
                try {
                  birthDate =
                      DateFormat('yyyy-MM-dd').parse(_userData['birthday']);
                } catch (dateFormatError) {
                  debugPrint('DateFormat解析失敗: $dateFormatError');
                }
              }
            } else if (_userData['birthday'] is Timestamp) {
              birthDate = (_userData['birthday'] as Timestamp).toDate();
            }

            if (birthDate != null) {
              _calculatedAge = _calculateAge(birthDate);

              // 自動設定表單中的年齡欄位
              if (_controllers.containsKey('age')) {
                _controllers['age']!.text = _calculatedAge.toString();
                _formData['age'] = _calculatedAge.toString();
              }

              debugPrint('已自動計算年齡: $_calculatedAge 歲');

              // 根據年齡計算年齡組別
              if (_ageGroups.isNotEmpty && _calculatedAge != null) {
                _calculatedAgeGroup =
                    AgeGroupHandler.getAgeGroup(_calculatedAge!, _ageGroups);
                if (_calculatedAgeGroup != null) {
                  debugPrint('已自動計算年齡組別: $_calculatedAgeGroup');
                  _formData['ageGroup'] = _calculatedAgeGroup;

                  // 預先設置下拉選單的值
                  if (_controllers.containsKey('ageGroup')) {
                    _controllers['ageGroup']!.text = _calculatedAgeGroup!;
                  }
                }
              }
            }
          }

          // 預填充表單中的其他欄位
          _prefillFormData();
        }
      }
    } catch (e) {
      debugPrint('載入用戶資料失敗: $e');
    }
  }

  // 使用用戶資料預填充表單
  void _prefillFormData() {
    // 預填姓名
    if (_userData.containsKey('username')) {
      _controllers['name']?.text = _userData['username'];
      _formData['name'] = _userData['username'];
    }

    // 預填電子郵件
    if (_userData.containsKey('email')) {
      _controllers['email']?.text = _userData['email'];
      _formData['email'] = _userData['email'];
    }

    // 預填學校
    if (_userData.containsKey('school')) {
      _controllers['school']?.text = _userData['school'];
      _formData['school'] = _userData['school'];
    }

    // 預填電話
    if (_userData.containsKey('phone')) {
      _controllers['phone']?.text = _userData['phone'];
      _formData['phone'] = _userData['phone'];
    }

    // 預填性別
    if (_userData.containsKey('gender')) {
      _formData['gender'] = _userData['gender'];
    }

    // 如果已經計算了年齡組別，預填年齡組別
    if (_calculatedAgeGroup != null) {
      _formData['ageGroup'] = _calculatedAgeGroup;
    }
  }

  // 計算年齡
  int _calculateAge(DateTime birthDate) {
    return AgeGroupHandler.calculateAge(birthDate);
  }

  // 載入報名表格
  Future<void> _loadRegistrationForm() async {
    // 檢查用戶是否登入
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() {
        _formError = '請先登入才能報名比賽';
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // 1. 首先獲取報名表單數據
      debugPrint('開始從報名表單ID查找比賽數據和項目');
      DocumentSnapshot? formDoc;
      String competitionId = widget.competitionId; // 預設使用傳入的比賽ID

      try {
        // 如果有提供formId，則先查詢報名表單集合
        if (widget.competitionId.contains('form_')) {
          debugPrint('檢測到formId格式，從報名表單集合查詢');
          // 從報名表單ID查詢
          formDoc = await _firestore
              .collection('registrationForms')
              .doc(widget.competitionId)
              .get();

          if (formDoc.exists) {
            Map<String, dynamic> formData =
                formDoc.data() as Map<String, dynamic>;
            // 從報名表單獲取對應的比賽ID
            if (formData.containsKey('competitionId')) {
              competitionId = formData['competitionId'] as String;
              debugPrint('從報名表單獲取到比賽ID: $competitionId');
            } else {
              debugPrint('報名表單中沒有找到比賽ID');
            }
          }
        } else {
          // 使用比賽ID查詢對應的報名表單
          debugPrint('使用比賽ID查詢對應的報名表單');
          QuerySnapshot formSnap = await _firestore
              .collection('registrationForms')
              .where('competitionId', isEqualTo: competitionId)
              .get();

          if (formSnap.docs.isNotEmpty) {
            formDoc = formSnap.docs.first;
            debugPrint('找到對應的報名表單');
          }
        }
      } catch (e) {
        debugPrint('獲取報名表單設定出錯: $e');
      }

      // 2. 獲取比賽數據
      debugPrint('使用比賽ID獲取比賽數據: $competitionId');
      DocumentSnapshot competitionDoc =
          await _firestore.collection('competitions').doc(competitionId).get();

      if (!competitionDoc.exists) {
        throw Exception('找不到比賽數據，ID: $competitionId');
      }

      Map<String, dynamic> competitionData =
          competitionDoc.data() as Map<String, dynamic>;
      debugPrint('成功獲取比賽數據: ${competitionData['name']}');

      // 3. 從比賽數據中獲取項目
      try {
        _availableEvents = []; // 初始化項目列表

        // 使用EventsHandler從競賽元數據中加載比賽項目
        List<Map<String, dynamic>> events;

        // 檢查數據是否在metadata中還是直接在competitionData中
        if (competitionData.containsKey('metadata') &&
            competitionData['metadata'] != null &&
            competitionData['metadata'] is Map<String, dynamic>) {
          events = EventsHandler.loadEventsFromMetadata(
              competitionData['metadata'] as Map<String, dynamic>);
          debugPrint('從比賽元數據中加載項目');
        } else if (competitionData.containsKey('events')) {
          // 如果項目直接存放在competitionData的events欄位
          events = EventsHandler.loadEventsFromMetadata(
              {'events': competitionData['events']});
          debugPrint('從比賽events欄位直接加載項目');
        } else {
          events = [];
          debugPrint('未找到項目數據');
        }

        if (events.isNotEmpty) {
          // 轉換為需要的格式
          _availableEvents = events
              .map<Map<String, dynamic>>((event) => {
                    "id": event['name'],
                    "name": event['name'],
                    "category": "一般項目",
                    "status": event['status'] ?? '進行中'
                  })
              .toList();

          debugPrint('成功使用EventsHandler獲取到 ${_availableEvents.length} 個項目');
        } else {
          debugPrint('未獲取到有效項目');
          setState(() {
            _formError = '此比賽沒有設置項目，請聯繫管理員添加比賽項目';
          });
        }
      } catch (e) {
        debugPrint('處理項目時發生錯誤: $e');
        setState(() {
          _formError = '讀取比賽項目失敗: $e';
        });
      }

      // 4. 處理報名表單設置
      Map<String, dynamic> formData = {};
      bool useAutoFetch = false;

      if (formDoc != null && formDoc.exists) {
        formData = formDoc.data() as Map<String, dynamic>;
        useAutoFetch = true;
        debugPrint('使用從Firebase獲取的報名表單設置');
      } else {
        // 沒有找到報名表單設定，顯示錯誤並停止加載
        setState(() {
          _formError = '無法載入報名表單設定，請聯繫比賽管理員';
          _isLoading = false;
        });
        return; // 提前退出函數，不繼續處理
      }

      // 5. 處理項目限制
      _maxEventsAllowed = formData.containsKey('maxEventsAllowed')
          ? formData['maxEventsAllowed'] as int
          : 0; // 0表示不限制
      debugPrint('項目選擇限制: $_maxEventsAllowed (0表示不限制)');

      // 6. 處理年齡組別
      _processAgeGroups(formData, competitionData);

      // 7. 處理表單欄位
      _processFormFields(formData);

      // 8. 檢查用戶是否已經提交過報名表
      await _checkExistingSubmission(currentUser.uid, useAutoFetch);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('載入報名表格錯誤: $e');
      setState(() {
        _formError = '載入報名表格失敗: $e';
        _isLoading = false;
      });
    }
  }

  // 處理年齡組別
  void _processAgeGroups(
      Map<String, dynamic> formData, Map<String, dynamic> competitionData) {
    // 優先從報名表格設置中獲取年齡組別
    if (formData.containsKey('ageGroups')) {
      final ageGroupsData = formData['ageGroups'] as List<dynamic>;
      _ageGroups = ageGroupsData.map<Map<String, dynamic>>((group) {
        if (group is Map) {
          return Map<String, dynamic>.from(group);
        } else {
          return {'name': group.toString(), 'startAge': 0, 'endAge': 100};
        }
      }).toList();
      debugPrint('從表單設置獲取到 ${_ageGroups.length} 個年齡組別');
    }
    // 使用工具類從競賽元數據中獲取年齡組別
    else {
      try {
        // 保存原始比賽數據以便其他地方使用

        // 使用AgeGroupHandler從比賽元數據中加載年齡組別
        Map<String, dynamic>? metadata =
            competitionData['metadata'] as Map<String, dynamic>?;
        _ageGroups = AgeGroupHandler.loadAgeGroupsFromMetadata(metadata);

        debugPrint('使用AgeGroupHandler成功加載了 ${_ageGroups.length} 個年齡分組');
      } catch (e) {
        debugPrint('處理年齡組別時出錯: $e');
        // 使用默認年齡組別
        _ageGroups = AgeGroupHandler.getDefaultAgeGroups();
        debugPrint('載入失敗，使用默認年齡組別');
      }
    }

    // 如果已經計算了年齡，立即計算年齡組別
    if (_calculatedAge != null) {
      try {
        _calculatedAgeGroup =
            AgeGroupHandler.getAgeGroup(_calculatedAge!, _ageGroups);
        if (_calculatedAgeGroup != null) {
          _formData['ageGroup'] = _calculatedAgeGroup;
          _formData['ageGroupDetail'] =
              '$_calculatedAge歲 ($_calculatedAgeGroup)';
          debugPrint('已根據年齡自動選擇年齡組別: $_calculatedAgeGroup');
        } else {
          debugPrint('警告: 無法根據年齡 $_calculatedAge 自動選擇年齡組別');
        }
      } catch (e) {
        debugPrint('年齡組別計算錯誤: $e');
        // 確保在出錯時不會影響表單其他部分的功能
      }
    }
  }

  // 處理表單欄位
  void _processFormFields(Map<String, dynamic> formData) {
    final List<dynamic> fields = formData['fields'] ?? [];

    // 將報名表格欄位轉換為本地格式
    _formFields = fields.map<Map<String, dynamic>>((field) {
      final key = field['key'] as String;
      _controllers[key] = TextEditingController();
      return {
        'key': key,
        'label': field['label'] as String,
        'type': field['type'] as String,
        'required': field['required'] as bool,
        'options': field['options'] as List<dynamic>? ?? [],
        'source': field['source'] as String? ?? '',
      };
    }).toList();

    debugPrint('從表單設置獲取到 ${_formFields.length} 個欄位');
  }

  // 檢查用戶是否已有報名記錄
  Future<void> _checkExistingSubmission(
      String userId, bool useAutoFetch) async {
    // 首先嘗試直接從participants集合查詢
    final participantDoc = await _firestore
        .collection('participants')
        .doc('${widget.competitionId}_$userId')
        .get();

    if (participantDoc.exists) {
      debugPrint('在 participants 集合中找到記錄');
      _hasSubmitted = true;
      _userSubmittedData = participantDoc.data();

      // 填充表單數據
      _formData = Map<String, dynamic>.from(
          _userSubmittedData?['formData'] as Map<String, dynamic>? ?? {});

      // 填充已選項目
      if (_userSubmittedData?['events'] != null) {
        _selectedEvents =
            List<String>.from(_userSubmittedData?['events'] as List<dynamic>);
      }

      // 填充表單控制器
      _formData.forEach((key, value) {
        if (_controllers.containsKey(key)) {
          _controllers[key]!.text = value.toString();
        }
      });

      // 在查看模式下，設置表單為只讀
      if (widget.viewMode) {
        _hasSubmitted = true;
      }

      _formProgress = 1.0;
    } else {
      // 嘗試從舊的registrations集合查詢
      final submissionDoc = await _firestore
          .collection('registrations')
          .where('competitionId', isEqualTo: widget.competitionId)
          .where('athleteId', isEqualTo: userId)
          .get();

      if (submissionDoc.docs.isNotEmpty) {
        _hasSubmitted = true;
        _userSubmittedData = submissionDoc.docs.first.data();

        // 填充表單數據
        _formData = Map<String, dynamic>.from(
            _userSubmittedData?['data'] as Map<String, dynamic>? ?? {});

        // 填充已選項目
        if (_userSubmittedData?['events'] != null) {
          _selectedEvents =
              List<String>.from(_userSubmittedData?['events'] as List<dynamic>);
        }

        // 填充表單控制器
        _formData.forEach((key, value) {
          if (_controllers.containsKey(key)) {
            _controllers[key]!.text = value.toString();
          }
        });

        _formProgress = 1.0;
      } else if (widget.viewMode) {
        setState(() {
          _formError = '您尚未提交此比賽的報名表';
          _isLoading = false;
        });
        return;
      } else if (useAutoFetch) {
        // 自動抽取用戶資料預填充表單
        await _autoFillFromUserProfile();
      }
    }
  }

  // 從用戶檔案自動填充表單數據
  Future<void> _autoFillFromUserProfile() async {
    try {
      if (_userData.isEmpty) {
        // 如果沒有用戶數據，重新載入
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          final userDoc =
              await _firestore.collection('users').doc(currentUser.uid).get();
          if (userDoc.exists) {
            _userData = userDoc.data() as Map<String, dynamic>;
          }
        }
      }

      if (_userData.isNotEmpty) {
        // 自動填充表單欄位
        for (var field in _formFields) {
          final key = field['key'] as String;
          final source = field['source'] as String? ?? '';

          if (source == 'profile' &&
              _userData.containsKey(key) &&
              _userData[key] != null) {
            _formData[key] = _userData[key];
            _controllers[key]!.text = _userData[key].toString();
          } else if (source == 'auth' &&
              key == 'email' &&
              _auth.currentUser?.email != null) {
            _formData[key] = _auth.currentUser!.email;
            _controllers[key]!.text = _auth.currentUser!.email!;
          }
        }

        // 預填姓名
        if (_controllers.containsKey('name') &&
            !_formData.containsKey('name')) {
          if (_userData.containsKey('username')) {
            _controllers['name']?.text = _userData['username'];
            _formData['name'] = _userData['username'];
          } else if (_userData.containsKey('name')) {
            _controllers['name']?.text = _userData['name'];
            _formData['name'] = _userData['name'];
          }
        }
      }
    } catch (e) {
      debugPrint('自動填充用戶資料錯誤: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.viewMode ? '報名詳情' : '比賽報名'),
          centerTitle: true,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('載入表單中...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${widget.competitionName} ${widget.viewMode ? '報名詳情' : '報名表'}'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        elevation: 0,
      ),
      body: widget.viewMode || _userSubmittedData != null
          ? _buildViewMode()
          : _buildStepperForm(),
    );
  }

  // 使用Stepper小部件實現分步表單
  Widget _buildStepperForm() {
    return Form(
      key: _formKey,
      child: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 1) {
            // 驗證當前步驟
            if (_currentStep == 0) {
              // 驗證個人資料表單
              bool isValid = true;
              for (var field in _formFields) {
                final key = field['key'] as String;
                final required = field['required'] as bool;
                final text = _controllers[key]?.text ?? '';

                if (required && text.isEmpty) {
                  isValid = false;
                  break;
                }
              }

              if (!isValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('請填寫所有必填欄位')),
                );
                return;
              }
            }

            setState(() {
              _currentStep += 1;
            });
          } else {
            // 最後一步，提交表單
            _submitForm();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() {
              _currentStep -= 1;
            });
          }
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              children: [
                FilledButton(
                  onPressed: _isSubmitting ? null : details.onStepContinue,
                  child: _isSubmitting && _currentStep == 1
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('提交中...'),
                          ],
                        )
                      : Text(_currentStep == 1 ? '提交報名表' : '下一步'),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : details.onStepCancel,
                    child: const Text('上一步'),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          // 步驟1：個人資料
          Step(
            isActive: _currentStep >= 0,
            title: const Text('個人資料'),
            subtitle: const Text('填寫基本資訊'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  // 顯示錯誤信息（如果有）
                  if (_formError != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(_formError!,
                          style: TextStyle(color: Colors.red.shade700)),
                    ),

                  // 表單進度顯示
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '填表進度',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${(_formProgress * 100).toInt()}%',
                              style: TextStyle(
                                color: _formProgress > 0.7
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _formProgress,
                            backgroundColor: Colors.grey.shade200,
                            minHeight: 8,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _formProgress > 0.7
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 動態生成個人資料表單欄位
                  ..._buildDynamicFormFields(),
                ],
              ),
            ),
          ),

          // 步驟2：選擇參賽項目
          Step(
            isActive: _currentStep >= 1,
            title: const Text('選擇項目'),
            subtitle: const Text('選擇你要參加的比賽項目'),
            content: _availableEvents.isEmpty
                ?
                // 如果沒有項目，顯示完整的錯誤信息
                Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade800, size: 24),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                '無法獲取比賽項目',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _formError ?? '此比賽沒有設置項目，請聯繫比賽管理員',
                          style: TextStyle(
                              fontSize: 14, color: Colors.red.shade700),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '報名表單要求比賽必須有項目設置才能繼續。請返回並選擇其他比賽，或聯繫比賽管理員添加項目。',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  )
                :
                // 有項目時顯示正常的選擇界面
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 比賽項目說明卡片
                      Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.blue.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.blue.shade700, size: 24),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '比賽項目選擇',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Text(
                                '請根據您的能力選擇要參加的比賽項目。',
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 項目選擇區域
                      const Text(
                        '請選擇您想參加的項目：',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCategorizedEventSelection(),

                      if (_selectedEvents.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(top: 16),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.amber.shade800, size: 24),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  '請至少選擇一個參賽項目才能提交報名',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // 動態生成表單欄位
  List<Widget> _buildDynamicFormFields() {
    List<Widget> formFieldWidgets = [];

    for (var field in _formFields) {
      final String key = field['key'];
      final String label = field['label'];
      final String type = field['type'];
      final bool required = field['required'];
      final List<dynamic> options = field['options'] ?? [];

      // 根據欄位類型生成不同的表單元素
      Widget formField;

      switch (type) {
        case 'text':
          formField = TextFormField(
            controller: _controllers[key],
            decoration: InputDecoration(
              labelText: label + (required ? ' *' : ''),
              border: const OutlineInputBorder(),
            ),
            validator: required
                ? (value) =>
                    (value == null || value.isEmpty) ? '請輸入$label' : null
                : null,
          );
          break;

        case 'number':
          formField = TextFormField(
            controller: _controllers[key],
            decoration: InputDecoration(
              labelText: label + (required ? ' *' : ''),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            validator: required
                ? (value) {
                    if (value == null || value.isEmpty) return '請輸入$label';
                    if (int.tryParse(value) == null) return '$label必須是數字';
                    return null;
                  }
                : null,
          );
          break;

        case 'dropdown':
          final List<String> dropdownOptions =
              options.map((o) => o.toString()).toList();
          formField = DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: label + (required ? ' *' : ''),
              border: const OutlineInputBorder(),
            ),
            value: _formData[key]?.toString(),
            items: dropdownOptions
                .map((value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _formData[key] = value;
              });
            },
            validator: required
                ? (value) =>
                    (value == null || value.isEmpty) ? '請選擇$label' : null
                : null,
          );
          break;

        case 'date':
          formField = TextFormField(
            controller: _controllers[key],
            decoration: InputDecoration(
              labelText: label + (required ? ' *' : ''),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _selectDate(context, key),
              ),
            ),
            readOnly: true,
            validator: required
                ? (value) =>
                    (value == null || value.isEmpty) ? '請選擇$label' : null
                : null,
            onTap: () => _selectDate(context, key),
          );
          break;

        default:
          formField = TextFormField(
            controller: _controllers[key],
            decoration: InputDecoration(
              labelText: label + (required ? ' *' : ''),
              border: const OutlineInputBorder(),
            ),
            validator: required
                ? (value) =>
                    (value == null || value.isEmpty) ? '請輸入$label' : null
                : null,
          );
      }

      formFieldWidgets.add(formField);
      formFieldWidgets.add(const SizedBox(height: 16));
    }

    return formFieldWidgets;
  }

  // 日期選擇器
  Future<void> _selectDate(BuildContext context, String fieldKey) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1A237E),
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
        final dateStr = DateFormat('yyyy-MM-dd').format(picked);
        _controllers[fieldKey]!.text = dateStr;
        _formData[fieldKey] = dateStr;

        // 如果是生日欄位，自動計算年齡
        if (fieldKey == 'birthday' && _calculatedAge == null) {
          _calculatedAge = _calculateAge(picked);
          // 更新年齡組
          _calculatedAgeGroup =
              AgeGroupHandler.getAgeGroup(_calculatedAge!, _ageGroups);
          if (_calculatedAgeGroup != null) {
            _formData['ageGroup'] = _calculatedAgeGroup;
            if (_controllers.containsKey('ageGroup')) {
              _controllers['ageGroup']!.text = _calculatedAgeGroup!;
            }
          }
        }
      });
    }
  }

  // 修改項目選擇方法，提供更簡單的項目展示
  Widget _buildCategorizedEventSelection() {
    // 如果沒有可用項目，顯示錯誤提示
    if (_availableEvents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade800, size: 24),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    '無法獲取比賽項目',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formError ?? '此比賽沒有設置項目，請聯繫比賽管理員',
              style: TextStyle(fontSize: 14, color: Colors.red.shade700),
            ),
          ],
        ),
      );
    }

    // 簡單顯示所有項目，不分類
    return Wrap(
      spacing: 8,
      runSpacing: 12,
      children: _availableEvents.map((event) {
        final eventId = event['id'].toString();
        final isSelected = _selectedEvents.contains(eventId);
        final isDisabled = _maxEventsAllowed > 0 &&
            _selectedEvents.length >= _maxEventsAllowed &&
            !isSelected;

        return FilterChip(
          label: Text(
            event['name'].toString(),
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          selected: isSelected,
          showCheckmark: true,
          checkmarkColor: Colors.white,
          tooltip: '點擊選擇此項目',
          onSelected: isDisabled
              ? null
              : (selected) {
                  setState(() {
                    if (selected) {
                      if (!_selectedEvents.contains(eventId)) {
                        _selectedEvents.add(eventId);
                      }
                    } else {
                      _selectedEvents.remove(eventId);
                    }
                  });
                },
          backgroundColor: Colors.white,
          selectedColor: Colors.blue,
          disabledColor: Colors.grey.shade200,
          labelStyle: TextStyle(
            color: isSelected
                ? Colors.white
                : isDisabled
                    ? Colors.grey
                    : Colors.black,
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 12,
          ),
        );
      }).toList(),
    );
  }

  // 提交報名表單
  Future<void> _submitForm() async {
    // 檢查是否已經提交過
    if (_hasSubmitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('您已經提交過報名表了'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_selectedEvents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('請至少選擇一個參賽項目'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isSubmitting = true; // 設置提交狀態為true
      });

      try {
        // 獲取當前用戶
        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          throw Exception('用戶未登錄');
        }

        // 獲取表單控制器的最新值
        for (var key in _controllers.keys) {
          _formData[key] = _controllers[key]!.text;
        }

        // 蒐集表單資料
        Map<String, dynamic> formData = {
          'userId': currentUser.uid,
          'athleteId': currentUser.uid, // 添加athleteId欄位確保兼容舊版查詢
          'userEmail': currentUser.email,
          'competitionId': widget.competitionId,
          'competitionName': widget.competitionName,
          'registrationDate': FieldValue.serverTimestamp(),
          'submittedAt': FieldValue.serverTimestamp(),
          'events': _selectedEvents,
          'ageGroup': _calculatedAgeGroup,
          'status': 'pending',
          'data': _formData, // 將所有表單數據存儲在data欄位中
        };

        // 將重要的個人資料直接存儲在根級別，以便於查詢
        formData['name'] = _formData['name'] ?? '';
        formData['school'] = _formData['school'] ?? '';
        formData['phone'] = _formData['phone'] ?? '';
        formData['email'] = _formData['email'] ?? currentUser.email ?? '';

        // 確保性別資料被保存到root level
        if (_formData.containsKey('gender')) {
          formData['gender'] = _formData['gender'];
          debugPrint('將性別資料保存到註冊資料root level: ${_formData['gender']}');
        } else if (_userData.containsKey('gender')) {
          // 如果表單中沒有但用戶資料中有，也保存
          formData['gender'] = _userData['gender'];
          debugPrint('從用戶資料獲取性別並保存到root level: ${_userData['gender']}');
        } else {
          debugPrint('未找到性別資料，將保存為未知');
          formData['gender'] = '未知';
        }

        // 添加年齡和出生日期到根級別
        if (_formData.containsKey('age')) {
          formData['age'] = _formData['age'];
        }
        if (_formData.containsKey('birthDate')) {
          formData['birthDate'] = _formData['birthDate'];
        }

        // 保存到Firestore
        DocumentReference docRef =
            await _firestore.collection('registrations').add(formData);

        debugPrint('已成功保存報名資料，文檔ID: ${docRef.id}');

        setState(() {
          _isSubmitting = false; // 提交完成
          _hasSubmitted = true;
          _userSubmittedData = formData;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('報名表提交成功！'),
            backgroundColor: Colors.green,
          ),
        );

        // 返回true表示報名成功
        Navigator.pop(context, true);
      } catch (e) {
        debugPrint('提交表單時發生錯誤: $e');

        setState(() {
          _isSubmitting = false; // 提交出錯，重置狀態
        });

        // 顯示更詳細的錯誤信息
        String errorMessage = '提交失敗';
        if (e.toString().contains('network')) {
          errorMessage = '網絡連接錯誤，請檢查您的網絡連接';
        } else if (e.toString().contains('permission')) {
          errorMessage = '權限錯誤，您可能沒有提交表單的權限';
        } else {
          errorMessage =
              '提交失敗: ${e.toString().substring(0, math.min(100, e.toString().length))}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '重試',
              onPressed: _submitForm,
              textColor: Colors.white,
            ),
          ),
        );
      }
    }
  }

  // 使用更現代的Material 3設計實現查看模式
  Widget _buildViewMode() {
    if (_userSubmittedData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              '未找到報名記錄',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '您尚未提交此比賽的報名表',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('返回'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 報名狀態卡片
          Card(
            elevation: 0,
            color: Colors.green.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.green.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle,
                        color: Colors.green.shade700, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '報名成功',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '您已成功報名此比賽，可隨時查看報名詳情',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 詳細信息標題
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '個人資料',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Chip(
                  label: Text(
                    _userSubmittedData!['ageGroup'] ?? '未分組',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.blue.shade100,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // 個人資料卡片
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow('姓名', _userSubmittedData!['name'] ?? ''),
                  const Divider(),
                  _buildInfoRow(
                      '年齡', (_userSubmittedData!['age'] ?? '').toString()),
                  const Divider(),
                  _buildInfoRow('電話', _userSubmittedData!['phone'] ?? ''),
                  const Divider(),
                  _buildInfoRow('學校', _userSubmittedData!['school'] ?? ''),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 報名項目標題
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Row(
              children: [
                const Icon(Icons.sports, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '報名項目',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_userSubmittedData!['events'] != null)
                  Chip(
                    label: Text(
                      '共${List<String>.from(_userSubmittedData!['events']).length}個項目',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.green.shade100,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),

          // 報名項目卡片
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_userSubmittedData!['events'] != null)
                    ...List<String>.from(_userSubmittedData!['events'])
                        .map((event) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.green.shade600, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      event,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList()
                  else
                    const Text('未選擇任何項目'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // 返回按鈕
          Center(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('返回'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(120, 48),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // 資訊行
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value.isEmpty ? '未提供' : value,
              style: TextStyle(
                fontSize: 15,
                color: value.isEmpty ? Colors.grey : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
