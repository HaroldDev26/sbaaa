import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/colors.dart';
import '../models/competition.dart';
import '../data/competition_data.dart'; // 導入數據管理類
import '../data/competition_manager.dart'; // 導入CompetitionManager類
import '../data/database_helper.dart'; // 導入DatabaseHelper類
import 'package:cloud_firestore/cloud_firestore.dart';
import '../resources/auth_methods.dart';
import '../models/user.dart';
import 'package:uuid/uuid.dart';

class CreateCompetitionScreen extends StatefulWidget {
  final CompetitionModel? competition; // 若為編輯模式則傳入現有比賽

  const CreateCompetitionScreen({
    Key? key,
    this.competition,
  }) : super(key: key);

  @override
  State<CreateCompetitionScreen> createState() =>
      _CreateCompetitionScreenState();
}

class _CreateCompetitionScreenState extends State<CreateCompetitionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final CompetitionData _competitionData = CompetitionData(); // 數據管理實例
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthMethods _authMethods = AuthMethods();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _eventsController = TextEditingController();
  final TextEditingController _ageGroupsController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String _status = '計劃中';
  String? _targetAudience;
  List<String> _events = [];
  List<Map<String, dynamic>> _ageGroups = [];
  bool _isLoading = false;
  bool _isEditMode = false;
  UserModel? _currentUser;

  // 公開對象選項
  final List<String> _targetAudienceOptions = [
    '公開',
    '僅限會員',
    '僅限邀請',
    '學校',
    '其他'
  ];

  @override
  void initState() {
    super.initState();
    // 檢查是否為編輯模式
    if (widget.competition != null) {
      _isEditMode = true;
      _loadCompetitionData();
    }

    // 立即執行第一次檢查
    _validateSQLiteData();

    // 延遲1秒後再次檢查，確保有足夠時間初始化
    Future.delayed(const Duration(seconds: 1), () {
      _validateSQLiteData();
    });

    _loadCurrentUser();
    // 設置默認日期
    DateTime now = DateTime.now();
    _startDateController.text =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _endDateController.text =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _loadCompetitionData() {
    final competition = widget.competition!;

    _nameController.text = competition.name;
    _descriptionController.text = competition.description;
    if (competition.venue != null) {
      _venueController.text = competition.venue!;
    }

    // 解析字符串日期為DateTime對象
    try {
      _startDate = DateTime.parse(competition.startDate);
      _endDate = DateTime.parse(competition.endDate);

      _startDateController.text = DateFormat('yyyy-MM-dd').format(_startDate!);
      _endDateController.text = DateFormat('yyyy-MM-dd').format(_endDate!);
    } catch (e) {
      // 如果解析失敗，直接使用日期字符串
      _startDateController.text = competition.startDate;
      _endDateController.text = competition.endDate;
    }

    _status = competition.status;

    // 載入公開對象
    if (competition.metadata != null &&
        competition.metadata!.containsKey('targetAudience')) {
      _targetAudience = competition.metadata!['targetAudience'];
    }

    // 載入比賽項目
    if (competition.events != null) {
      _events = competition.events!.map((e) => e['name'].toString()).toList();
      _eventsController.text = _events.join(',');
    }

    // 載入年齡分組
    if (competition.metadata != null &&
        competition.metadata!.containsKey('ageGroups')) {
      var sourceAgeGroups = competition.metadata!['ageGroups'];
      _ageGroups = [];

      // 轉換各種可能的輸入格式為統一的Map格式
      if (sourceAgeGroups is List) {
        for (var group in sourceAgeGroups) {
          if (group is Map) {
            _ageGroups.add(Map<String, dynamic>.from(group));
          } else if (group is String) {
            // 處理字符串格式
            String name = "未命名組別";
            int? startAge;
            int? endAge;

            if (group.contains(":")) {
              final parts = group.split(":");
              name = parts[0].trim();
              final ageRange = parts[1].trim();
              final ageParts = ageRange.replaceAll('歲', '').split('-');
              if (ageParts.length == 2) {
                try {
                  startAge = int.parse(ageParts[0]);
                  endAge = int.parse(ageParts[1]);
                } catch (e) {
                  // 解析失敗時保持默認值
                }
              }
            } else {
              // 嘗試解析簡單格式 "7-9歲"
              final parts = group.replaceAll('歲', '').split('-');
              if (parts.length == 2) {
                try {
                  startAge = int.parse(parts[0]);
                  endAge = int.parse(parts[1]);
                } catch (e) {
                  // 解析失敗時保持默認值
                }
              }
            }

            _ageGroups
                .add({'name': name, 'startAge': startAge, 'endAge': endAge});
          }
        }
      }

      // 格式化顯示文本
      List<String> displayGroups = [];
      for (var group in _ageGroups) {
        final name = group['name'] ?? '未命名組別';
        final startAge = group['startAge'];
        final endAge = group['endAge'];

        if (startAge != null && endAge != null) {
          displayGroups.add("$name ($startAge-$endAge歲)");
        } else {
          displayGroups.add(name);
        }
      }

      _ageGroupsController.text = displayGroups.join('\n');
    }
  }

  // 加載當前登錄用戶信息
  Future<void> _loadCurrentUser() async {
    try {
      _currentUser = await _authMethods.getCurrentUser();
      setState(() {}); // 更新狀態以反映用戶加載完成
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('獲取用戶信息失敗: $e')),
        );
      }
    }
  }

  // 驗證SQLite數據庫中的比賽數據
  Future<void> _validateSQLiteData() async {
    try {
      // 獲取CompetitionManager實例
      final compManager = CompetitionManager.instance;

      // 檢查數據庫路徑
      final dbPath = await compManager.getDatabasePath();
      print('💾 SQLite 數據庫路徑：$dbPath');

      // 檢查DatabaseHelper的路徑
      final dbHelperPath = await DatabaseHelper().getDatabasePath();
      print('💾 DatabaseHelper 數據庫路徑：$dbHelperPath');

      if (dbPath != dbHelperPath) {
        print('⚠️ 警告：CompetitionManager 和 DatabaseHelper 使用的數據庫路徑不同！');
      } else {
        print('✅ 確認：兩個類使用相同的數據庫路徑');
      }

      // 全面檢查數據庫結構
      try {
        final dbStructure = await compManager.checkDatabaseStructure();
        print('📘 數據庫結構檢查結果:');
        print('  • 路徑: ${dbStructure['db_path']}');
        print('  • 表數量: ${(dbStructure['tables'] as List).length}');
        print('  • 表列表: ${dbStructure['tables']}');
        print('  • Competitions表結構: ${dbStructure['competitions_schema']}');
        print('  • Competitions表記錄數: ${dbStructure['competitions_count']}');
        print('  • 測試查詢結果: ${dbStructure['test_query_count']}');

        if (dbStructure.containsKey('first_record') &&
            dbStructure['first_record'] != null) {
          print('  • 第一筆記錄: ${dbStructure['first_record']}');
        } else {
          print('  • 沒有記錄');
        }
      } catch (structureError) {
        print('❌ 數據庫結構檢查失敗: $structureError');
      }

      // 檢查數據表結構
      try {
        final schema =
            await compManager.rawQuery('PRAGMA table_info(competitions)');
        print('🧱 SQLite competitions表結構: $schema');
      } catch (schemaError) {
        print('❌ 查詢表結構失敗: $schemaError');
      }

      // 執行原始SQL查詢所有數據
      try {
        final allData =
            await compManager.rawQuery('SELECT * FROM competitions');
        print('📑 原始查詢所有數據 (${allData.length}筆):');
        for (int i = 0; i < allData.length; i++) {
          print('- 數據 #${i + 1}: ${allData[i]}');
        }
      } catch (queryError) {
        print('❌ 原始查詢失敗: $queryError');
      }

      // 獲取所有比賽數據
      final competitions = await compManager.getAllCompetitions();
      print('📦 SQLite 數據庫中有 ${competitions.length} 筆比賽資料');

      // 如果有數據，打印所有數據
      if (competitions.isNotEmpty) {
        print('📋 SQLite 中的所有比賽資料:');
        for (int i = 0; i < competitions.length; i++) {
          print('比賽 #${i + 1}: ${competitions[i].toMap()}');
        }
      } else {
        print('⚠️ SQLite 數據庫中沒有比賽資料');
      }

      // 檢查表計數
      try {
        final count = await compManager.getCompetitionCount();
        print('📊 SQLite count查詢結果: $count 筆資料');

        if (count != competitions.length) {
          print(
              '⚠️ 警告：count查詢結果 ($count) 與獲取到的資料數量 (${competitions.length}) 不一致！');
        }
      } catch (queryError) {
        print('❌ 執行count查詢失敗: $queryError');
      }

      // 檢查CompetitionData中的數據
      try {
        final compData = CompetitionData();
        final memoryComps = compData.competitions;
        print('🧠 記憶體中的比賽數量: ${memoryComps.length}');

        if (memoryComps.isNotEmpty) {
          print('📋 記憶體中第一筆比賽: ${memoryComps.first.toMap()}');
        }
      } catch (memoryError) {
        print('❌ 檢查記憶體數據失敗: $memoryError');
      }
    } catch (e, stackTrace) {
      print('❌ 驗證SQLite數據失敗: $e');
      print(stackTrace);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _eventsController.dispose();
    _ageGroupsController.dispose();
    super.dispose();
  }

  // 選擇日期
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = isStartDate
        ? _startDate ?? now
        : _endDate ??
            (_startDate != null
                ? _startDate!.add(const Duration(days: 1))
                : now.add(const Duration(days: 1)));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 30)), // 允許設置過去30天的日期
      lastDate: now.add(const Duration(days: 365 * 5)), // 5年內
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          _startDateController.text = DateFormat('yyyy-MM-dd').format(picked);

          // 如果結束日期早於開始日期，更新結束日期
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate!.add(const Duration(days: 1));
            _endDateController.text =
                DateFormat('yyyy-MM-dd').format(_endDate!);
          }
        } else {
          _endDate = picked;
          _endDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        }
      });
    }
  }

  // 處理比賽項目輸入
  void _handleEventsInput() async {
    final currentEvents = _eventsController.text;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => _buildEventsDialog(currentEvents),
    );

    if (result != null) {
      setState(() {
        _eventsController.text = result;
        _events = result.split(',').where((e) => e.trim().isNotEmpty).toList();
      });
    }
  }

  // 構建比賽項目輸入對話框
  Widget _buildEventsDialog(String initialValue) {
    final controller = TextEditingController(text: initialValue);

    return AlertDialog(
      title: const Text('輸入比賽項目'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '請輸入比賽項目，多個項目請用「,」分隔',
              helperText: '例如：100米,200米,跳遠,跳高',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('確定'),
        ),
      ],
    );
  }

  // 處理年齡分組輸入
  void _handleAgeGroupsInput() async {
    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => _buildAgeGroupsDialog(_ageGroups),
    );

    if (result != null) {
      setState(() {
        _ageGroups = result;
      });
    }
  }

  // 構建年齡分組設定對話框
  Widget _buildAgeGroupsDialog(List<Map<String, dynamic>> initialGroups) {
    List<Map<String, dynamic>> ageGroups = [];
    // 為每個輸入框創建控制器
    List<TextEditingController> nameControllers = [];
    List<TextEditingController> startAgeControllers = [];
    List<TextEditingController> endAgeControllers = [];

    // 初始化年齡分組數據
    if (initialGroups.isNotEmpty) {
      for (var group in initialGroups) {
        String name = "未命名";
        int? startAge;
        int? endAge;

        // 處理帶名稱的格式 "名稱: 7-9歲"
        if (group.containsKey('name')) {
          name = group['name'];
        }
        if (group.containsKey('startAge')) {
          startAge = group['startAge'];
        }
        if (group.containsKey('endAge')) {
          endAge = group['endAge'];
        }

        ageGroups.add({'name': name, 'startAge': startAge, 'endAge': endAge});
        // 為每個組別創建對應的控制器
        nameControllers.add(TextEditingController(text: name));
        startAgeControllers
            .add(TextEditingController(text: startAge?.toString() ?? ''));
        endAgeControllers
            .add(TextEditingController(text: endAge?.toString() ?? ''));
      }
    }

    // 如果沒有分組，添加一個默認的空分組
    if (ageGroups.isEmpty) {
      ageGroups.add({'name': '未命名', 'startAge': null, 'endAge': null});
      nameControllers.add(TextEditingController(text: '未命名'));
      startAgeControllers.add(TextEditingController());
      endAgeControllers.add(TextEditingController());
    }

    return StatefulBuilder(
      builder: (context, setState) {
        // 添加組別的函數，確保同時創建控制器
        void addAgeGroup() {
          setState(() {
            ageGroups.add({'name': '未命名', 'startAge': null, 'endAge': null});
            nameControllers.add(TextEditingController(text: '未命名'));
            startAgeControllers.add(TextEditingController());
            endAgeControllers.add(TextEditingController());
          });
        }

        // 刪除組別的函數，確保同時刪除控制器，但不允許刪除最後一個組別
        void removeAgeGroup(int index) {
          if (ageGroups.length > 1) {
            // 至少保留一個組別
            setState(() {
              ageGroups.removeAt(index);
              nameControllers.removeAt(index);
              startAgeControllers.removeAt(index);
              endAgeControllers.removeAt(index);
            });
          } else {
            // 顯示提示，不能刪除最後一個組別
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('至少需要保留一個年齡組別'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }

        return AlertDialog(
          title: const Text('設定年齡分組'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('請為每個年齡組別設定名稱、起始和結束年齡'),
                const SizedBox(height: 16),
                ...ageGroups.asMap().entries.map((entry) {
                  final index = entry.key;
                  final group = entry.value;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '組別 ${index + 1}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => removeAgeGroup(index),
                                tooltip:
                                    ageGroups.length > 1 ? '刪除此組別' : '至少需要一個組別',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: '組別名稱',
                              border: OutlineInputBorder(),
                              helperText: '例如: 少年組、青年組',
                            ),
                            controller: nameControllers[index],
                            onChanged: (value) {
                              setState(() {
                                ageGroups[index]['name'] = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: '起始年齡',
                                    border: OutlineInputBorder(),
                                    helperText: '例如: 7',
                                  ),
                                  keyboardType: TextInputType.number,
                                  controller: startAgeControllers[index],
                                  onChanged: (value) {
                                    if (value.isNotEmpty) {
                                      try {
                                        setState(() {
                                          ageGroups[index]['startAge'] =
                                              int.parse(value);
                                        });
                                      } catch (_) {}
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text('至', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: '結束年齡',
                                    border: OutlineInputBorder(),
                                    helperText: '例如: 9',
                                  ),
                                  keyboardType: TextInputType.number,
                                  controller: endAgeControllers[index],
                                  onChanged: (value) {
                                    if (value.isNotEmpty) {
                                      try {
                                        setState(() {
                                          ageGroups[index]['endAge'] =
                                              int.parse(value);
                                        });
                                      } catch (_) {}
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (group['name'] != null &&
                              group['startAge'] != null &&
                              group['endAge'] != null)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '預覽: ${group['name']} (${group['startAge']}-${group['endAge']}歲)',
                                style: const TextStyle(color: Colors.blue),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('添加年齡組別'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 24),
                  ),
                  onPressed: addAgeGroup,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                // 驗證並轉換年齡分組
                final List<Map<String, dynamic>> validGroups = [];

                for (var group in ageGroups) {
                  final name = group['name'];
                  final startAge = group['startAge'];
                  final endAge = group['endAge'];

                  if (name != null &&
                      name.isNotEmpty &&
                      startAge != null &&
                      endAge != null) {
                    validGroups.add({
                      'name': name,
                      'startAge': startAge,
                      'endAge': endAge,
                    });
                  }
                }

                // 檢查是否至少有一個有效組別
                if (validGroups.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('請至少填寫一個完整的年齡組別'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }

                Navigator.pop(context, validGroups);
              },
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }

  // 導入Excel文件
  Future<void> _importExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (result != null) {
        // 這裡需要實現解析Excel的邏輯
        // 目前只是顯示一個提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已選擇文件: ${result.files.single.name}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('選擇文件失敗: $e')),
      );
    }
  }

  // 提交表單
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // 使用已加載的_currentUser或回退到Firebase Auth
        final String uid = _currentUser?.uid ?? _auth.currentUser?.uid ?? "";
        final String createdBy = _currentUser?.username ?? '未知用戶';
        final String email =
            _currentUser?.email ?? _auth.currentUser?.email ?? "";

        // 確保有用戶ID，否則無法繼續
        if (uid.isEmpty) {
          throw Exception('創建比賽需要登錄');
        }

        // 生成唯一ID
        final String competitionId = const Uuid().v4();
        final DateTime now = DateTime.now();

        // 驗證年齡組別格式
        if (_ageGroups.isEmpty) {
          throw Exception('至少需要一個年齡組別');
        }

        // 將年齡組別轉換為規範格式
        final ageGroupsForSubmit = _ageGroups;

        // 準備比賽數據
        final Map<String, dynamic> competitionData = {
          'id': competitionId,
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'venue': _venueController.text.trim(),
          'startDate': _startDateController.text,
          'endDate': _endDateController.text,
          'status': _status,
          'createdBy': createdBy,
          'createdByUid': uid, // 明確存儲創建者UID
          'createdAt': now.toIso8601String(),
          'metadata': {
            'targetAudience': _targetAudience,
            'maxParticipants': 100,
            'currentParticipants': 0,
            'events': _events.map((e) => {'name': e, 'status': '計劃中'}).toList(),
            'ageGroups': ageGroupsForSubmit, // 使用格式化後的年齡組別
            'createdByUid': uid, // 在metadata中也保存創建者UID以便查詢
            'owner': {
              'uid': uid,
              'username': createdBy,
              'email': email,
            }
          },
          'permissions': {
            'owner': uid,
            'canEdit': [uid],
            'canDelete': [uid], // 只有創建者可以刪除
            'canManage': [uid]
          }
        };

        if (_isEditMode && widget.competition != null) {
          // 編輯模式：保留原始創建者資訊
          final String originalCreator = widget.competition!.createdBy;
          final String? originalCreatorUid =
              widget.competition!.metadata?['createdByUid'] as String?;
          final String originalCreatedAt = widget.competition!.createdAt;

          competitionData['id'] = widget.competition!.id;
          competitionData['createdBy'] = originalCreator;
          competitionData['createdAt'] = originalCreatedAt;

          // 確保保留原始創建者UID
          if (originalCreatorUid != null && originalCreatorUid.isNotEmpty) {
            competitionData['createdByUid'] = originalCreatorUid;
            competitionData['metadata']['createdByUid'] = originalCreatorUid;

            if (originalCreatorUid != uid) {
              // 如果當前用戶不是創建者，但有編輯權限，添加到canEdit列表
              competitionData['metadata']['createdByUid'] = originalCreatorUid;
              competitionData['metadata']
                  ['canEdit'] = [originalCreatorUid, uid];
              competitionData['metadata']
                  ['canManage'] = [originalCreatorUid, uid];
              // 只有原創建者可以刪除
              competitionData['metadata']['canDelete'] = [originalCreatorUid];
            }
          }

          // 調用更新方法
          await _competitionData.updateCompetition(
              widget.competition!.id, competitionData);

          // 同時更新Firestore中的用戶資料，添加此比賽到用戶的比賽列表中
          if (uid.isNotEmpty) {
            await _firestore.collection('users').doc(uid).update({
              'competitions': FieldValue.arrayUnion([widget.competition!.id])
            });
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('比賽已成功更新')),
            );
            Navigator.pop(context, true);
          }
        } else {
          // 創建模式：新建比賽
          final competitionId =
              await _competitionData.addCompetition(competitionData);

          // 同時更新Firestore中的用戶資料，添加此比賽到用戶的比賽列表中
          if (uid.isNotEmpty) {
            await _firestore.collection('users').doc(uid).update({
              'competitions': FieldValue.arrayUnion([competitionId])
            });
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('比賽已成功創建')),
            );
            Navigator.pop(context, true);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存失敗: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(
          _isEditMode ? '編輯比賽' : '新增比賽',
          style: const TextStyle(color: Colors.white),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('返回', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 比賽名稱
                const Text(
                  '比賽名稱',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: '輸入比賽名稱',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.black, width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.black, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '請輸入比賽名稱';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // 公開對象
                const Text(
                  '公開對象',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1.0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButtonFormField<String>(
                      value: _targetAudience,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        border: InputBorder.none,
                        hintText: '選擇公開對象',
                      ),
                      items: _targetAudienceOptions.map((String audience) {
                        return DropdownMenuItem<String>(
                          value: audience,
                          child: Text(audience),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _targetAudience = value;
                          });
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 舉行日期
                const Text(
                  '舉行日期',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _startDateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText: '開始日期',
                          suffixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Colors.black, width: 1.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Colors.black, width: 1.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: primaryColor, width: 1.5),
                          ),
                        ),
                        onTap: () => _selectDate(context, true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '請選擇開始日期';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _endDateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText: '結束日期',
                          suffixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Colors.black, width: 1.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Colors.black, width: 1.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: primaryColor, width: 1.5),
                          ),
                        ),
                        onTap: () => _selectDate(context, false),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 比賽地點
                const Text(
                  '比賽地點',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _venueController,
                  decoration: InputDecoration(
                    hintText: '輸入比賽地點',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.black, width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.black, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 比賽項目
                const Text(
                  '比賽項目',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _eventsController,
                  readOnly: true,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '點擊添加比賽項目',
                    suffixIcon: const Icon(Icons.edit),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.black, width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.black, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                  onTap: _handleEventsInput,
                ),

                const SizedBox(height: 16),

                // 年齡分組
                const Text(
                  '年齡分組',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ageGroupsController,
                  readOnly: true,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: '點擊添加年齡分組',
                    suffixIcon: const Icon(Icons.edit),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.black, width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.black, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                  onTap: _handleAgeGroupsInput,
                ),

                const SizedBox(height: 16),

                // 比賽描述
                const Text(
                  '比賽描述',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '輸入比賽描述',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.black, width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.black, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '請輸入比賽描述';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // 導入Excel按鈕
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _importExcel,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '導入 Excel',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 提交按鈕
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06074F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _isEditMode ? '確認修改' : '確認新增',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
