import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateRegistrationFormScreen extends StatefulWidget {
  final String competitionId;
  final String competitionName;

  const CreateRegistrationFormScreen({
    Key? key,
    required this.competitionId,
    required this.competitionName,
  }) : super(key: key);

  @override
  State<CreateRegistrationFormScreen> createState() =>
      _CreateRegistrationFormScreenState();
}

class _CreateRegistrationFormScreenState
    extends State<CreateRegistrationFormScreen> {
  bool _isLoading = false;
  bool _existingForm = false;
  String? _existingFormId;
  final ScrollController _scrollController = ScrollController();
  bool _useAutoFetch = true; // 是否自動抽取用戶資料

  // 所有可選擇的欄位，分為自動抽取和手動輸入兩類
  final List<Map<String, dynamic>> autoFetchFields = [
    {"key": "name", "label": "姓名", "type": "text", "source": "profile"},
    {"key": "school", "label": "學校", "type": "text", "source": "profile"},
    {
      "key": "gender",
      "label": "性別",
      "type": "dropdown",
      "source": "profile",
      "options": ["男", "女"]
    },
    {"key": "birthday", "label": "出生日期", "type": "date", "source": "profile"},
    {"key": "phone", "label": "聯絡電話", "type": "text", "source": "profile"},
    {"key": "email", "label": "電子郵件", "type": "text", "source": "auth"},
  ];

  final List<Map<String, dynamic>> manualFields = [
    {"key": "organization", "label": "機構", "type": "text"},
    {"key": "bestResult", "label": "最佳成績", "type": "text"},
    {"key": "emergencyContact", "label": "緊急聯絡人", "type": "text"},
    {"key": "emergencyPhone", "label": "緊急聯絡電話", "type": "text"},
    {"key": "class", "label": "班別", "type": "text"},
    {"key": "studentId", "label": "學號", "type": "text"},
    {"key": "remarks", "label": "備註", "type": "text"},
  ];

  // 存儲是否選中和是否必填的狀態
  Map<String, bool> selectedFields = {};
  Map<String, bool> requiredFields = {};

  // 項目列表和所選項目
  List<Map<String, dynamic>> _availableEvents = [];
  Map<String, bool> selectedEvents = {};
  bool _isLoadingEvents = true;

  @override
  void initState() {
    super.initState();
    // 初始化所有欄位為未選中
    for (var field in [...autoFetchFields, ...manualFields]) {
      selectedFields[field['key']] = false;
      requiredFields[field['key']] = true; // 預設為必填
    }

    // 自動選中常用欄位
    selectedFields["name"] = true;
    selectedFields["gender"] = true;
    selectedFields["birthday"] = true;
    selectedFields["phone"] = true;
    selectedFields["email"] = true;

    // 載入可用項目
    _loadAvailableEvents();

    // 檢查是否已有報名表設定
    _checkExistingForm();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 載入可用項目
  Future<void> _loadAvailableEvents() async {
    setState(() {
      _isLoadingEvents = true;
    });

    try {
      // 首先檢查競賽詳情中是否有指定項目
      final competitionDoc = await FirebaseFirestore.instance
          .collection('competitions')
          .doc(widget.competitionId)
          .get();

      List<Map<String, dynamic>> events = [];

      // 如果競賽文檔包含events欄位，使用它
      if (competitionDoc.exists &&
          competitionDoc.data()!.containsKey('events')) {
        final List<dynamic> competitionEvents =
            competitionDoc.data()!['events'];
        for (var event in competitionEvents) {
          if (event is Map) {
            events.add(Map<String, dynamic>.from(event));
          } else if (event is String) {
            events.add({"id": event, "name": event});
          }
        }
      }

      // 如果競賽沒有指定項目，從全局events集合獲取
      if (events.isEmpty) {
        final eventsSnapshot =
            await FirebaseFirestore.instance.collection('events').get();
        for (var doc in eventsSnapshot.docs) {
          events.add({
            "id": doc.id,
            "name": doc['name'],
            "category": doc['category'],
            "limit": doc['limit'] ?? 20, // 預設限制為20人
          });
        }
      }

      // 初始化所有項目為未選中
      for (var event in events) {
        selectedEvents[event['id'].toString()] = false;
      }

      setState(() {
        _availableEvents = events;
        _isLoadingEvents = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingEvents = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入項目失敗: $e')),
        );
      }
    }
  }

  // 檢查是否已存在此比賽的報名表格
  Future<void> _checkExistingForm() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('registrationForms')
          .where('competitionId', isEqualTo: widget.competitionId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // 找到現有表格
        final formDoc = querySnapshot.docs.first;
        _existingFormId = formDoc.id;
        _existingForm = true;

        // 載入現有設定
        final fields = formDoc['fields'] as List<dynamic>;
        for (var field in fields) {
          selectedFields[field['key']] = true;
          requiredFields[field['key']] = field['required'] ?? true;
        }

        // 載入自動抽取設定
        if (formDoc.data().containsKey('useAutoFetch')) {
          _useAutoFetch = formDoc['useAutoFetch'] as bool;
        }

        // 載入選中的項目
        if (formDoc.data().containsKey('availableEvents')) {
          final events = formDoc['availableEvents'] as List<dynamic>;
          for (var event in events) {
            if (event is Map) {
              selectedEvents[event['id'].toString()] = true;
            } else if (event is String) {
              selectedEvents[event] = true;
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入報名表設定出錯: $e')),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 儲存報名表格設定
  Future<void> _saveFormConfig() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 篩選已選中的欄位
      final autoSelected = autoFetchFields
          .where((field) => selectedFields[field['key']] == true)
          .map((field) {
        // 創建基本欄位數據
        final Map<String, dynamic> fieldData = {
          "key": field['key'],
          "label": field['label'],
          "required": requiredFields[field['key']] ?? true,
          "type": field['type'],
          "source": field['source'],
        };

        // 只有在字段有選項時才添加選項數據
        if (field.containsKey('options')) {
          fieldData["options"] = field['options'];
        }
        return fieldData;
      }).toList();

      final manualSelected = manualFields
          .where((field) => selectedFields[field['key']] == true)
          .map((field) {
        // 創建基本欄位數據
        final Map<String, dynamic> fieldData = {
          "key": field['key'],
          "label": field['label'],
          "required": requiredFields[field['key']] ?? true,
          "type": field['type'],
        };

        // 只有在字段有選項時才添加選項數據
        if (field.containsKey('options')) {
          fieldData["options"] = field['options'];
        }
        return fieldData;
      }).toList();

      // 合併所有選中的欄位
      final allSelected = [...autoSelected, ...manualSelected];

      print('已選欄位數量: ${allSelected.length}');
      print('選中的自動欄位: ${autoSelected.length}');
      print('選中的手動欄位: ${manualSelected.length}');

      if (allSelected.isEmpty) {
        throw Exception('請至少選擇一個欄位');
      }

      // 篩選已選中的項目
      final selectedEventsList = _availableEvents
          .where((event) => selectedEvents[event['id'].toString()] == true)
          .toList();

      print('已選項目數量: ${selectedEventsList.length}');

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('請先登入');
      }

      // 準備要儲存的數據
      final Map<String, dynamic> formData = {
        "competitionId": widget.competitionId,
        "competitionName": widget.competitionName,
        "fields": allSelected,
        "availableEvents": selectedEventsList,
        "useAutoFetch": _useAutoFetch,
        "createdBy": currentUser.uid,
        "updatedAt": FieldValue.serverTimestamp(),
        "lastUpdatedBy": currentUser.displayName ?? currentUser.email,
      };

      // 僅在新建表單時設置創建時間
      if (!_existingForm) {
        formData["createdAt"] = FieldValue.serverTimestamp();
      }

      print('準備保存表單數據到 Firebase...');
      print('表單ID: ${_existingFormId ?? "新表單"}');

      // 根據是否已存在表格決定更新或新增
      if (_existingForm && _existingFormId != null) {
        print('正在更新現有表單...');
        await FirebaseFirestore.instance
            .collection('registrationForms')
            .doc(_existingFormId)
            .update(formData);

        print('表單更新成功!');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('報名表格已更新'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('正在創建新表單...');
        final docRef = await FirebaseFirestore.instance
            .collection('registrationForms')
            .add(formData);

        print('表單創建成功! 新ID: ${docRef.id}');

        // 更新比賽文檔，將表單ID關聯到比賽中
        await FirebaseFirestore.instance
            .collection('competitions')
            .doc(widget.competitionId)
            .update({
          'registrationFormId': docRef.id,
          'registrationFormCreatedAt': FieldValue.serverTimestamp(),
          'metadata.registration_form_created': true,
          'metadata.registration_status': 'pending', // 等待開放報名
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('報名表格已創建並關聯到比賽'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      // 返回上一頁
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('儲存表單失敗: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('儲存報名表格失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('設定報名表格: ${widget.competitionName}'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('儲存', style: TextStyle(color: Colors.white)),
            onPressed: _isLoading ? null : _saveFormConfig,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 120,
                    floating: true,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                          '已選 ${selectedFields.values.where((v) => v).length} 個欄位'),
                      background: Container(
                        color: Colors.blue.withOpacity(0.1),
                        child: _buildSelectedChips(),
                      ),
                    ),
                  ),
                ];
              },
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 項目選擇區域
                      const Text(
                        '可報名項目',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '選擇運動員可以報名的項目',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _isLoadingEvents
                          ? const Center(child: CircularProgressIndicator())
                          : _buildEventsSelection(),

                      const Divider(height: 32),

                      // 自動抽取設置
                      SwitchListTile(
                        title: const Text('自動抽取運動員資料'),
                        subtitle: const Text('從運動員個人檔案中自動獲取基本資料，無需重複輸入'),
                        value: _useAutoFetch,
                        onChanged: (value) {
                          setState(() {
                            _useAutoFetch = value;
                          });
                        },
                        activeColor: Colors.green,
                      ),

                      const Divider(height: 32),

                      // 自動抽取的欄位選擇
                      const Text(
                        '自動抽取的欄位',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '這些欄位將從運動員檔案中自動獲取，運動員無需手動輸入',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildFieldSelection(autoFetchFields, _useAutoFetch),

                      const Divider(height: 32),

                      // 手動輸入的欄位選擇
                      const Text(
                        '手動輸入欄位',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '這些欄位需要運動員在報名時手動填寫',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildFieldSelection(manualFields, true),

                      // 年齡自動計算提示
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.3),
                          ),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '年齡和組別自動計算',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '系統將根據出生日期自動計算運動員年齡，並根據競賽設定的年齡組別自動分配。',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 100), // 底部間距
                    ],
                  ),
                ),
              ),
            ),
      // 添加浮動提交按鈕
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: _saveFormConfig,
              label: const Text('提交表單'),
              icon: const Icon(Icons.check),
              backgroundColor: Colors.green,
            ),
    );
  }

  // 構建已選欄位的標籤展示
  Widget _buildSelectedChips() {
    final allFields = [...autoFetchFields, ...manualFields];
    final selectedList = allFields
        .where((field) => selectedFields[field['key']] == true)
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.bottomLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: selectedList.map((field) {
          final bool isAutoFetch =
              autoFetchFields.any((item) => item['key'] == field['key']);
          return Chip(
            label: Text(field['label']),
            backgroundColor: isAutoFetch
                ? Colors.blue.withOpacity(0.1)
                : Colors.green.withOpacity(0.1),
            labelStyle: const TextStyle(fontSize: 12),
            avatar: isAutoFetch
                ? const Icon(Icons.download_done, size: 16)
                : const Icon(Icons.edit, size: 16),
          );
        }).toList(),
      ),
    );
  }

  // 構建項目選擇部分
  Widget _buildEventsSelection() {
    // 將項目按類別分組
    Map<String, List<Map<String, dynamic>>> eventsByCategory = {};

    for (var event in _availableEvents) {
      final category = event['category'] as String? ?? '未分類';
      if (!eventsByCategory.containsKey(category)) {
        eventsByCategory[category] = [];
      }
      eventsByCategory[category]!.add(event);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: eventsByCategory.entries.map((entry) {
        final category = entry.key;
        final categoryEvents = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categoryEvents.map((event) {
                final eventId = event['id'].toString();
                final isSelected = selectedEvents[eventId] ?? false;

                return FilterChip(
                  label: Text(event['name']),
                  selected: isSelected,
                  onSelected: (value) {
                    setState(() {
                      selectedEvents[eventId] = value;
                    });
                  },
                  backgroundColor: Colors.white,
                  selectedColor: Colors.blue.withOpacity(0.2),
                  checkmarkColor: Colors.blue,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.blue : Colors.black,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  // 構建欄位選擇部分
  Widget _buildFieldSelection(List<Map<String, dynamic>> fields, bool enabled) {
    return Column(
      children: fields.map((field) {
        final key = field['key'];
        final isSelected = selectedFields[key] ?? false;
        final isRequired = requiredFields[key] ?? true;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(field['label']),
            subtitle: Text('類型: ${_getFieldTypeText(field['type'])}'),
            leading: Checkbox(
              value: isSelected,
              onChanged: enabled
                  ? (value) {
                      setState(() {
                        selectedFields[key] = value ?? false;
                      });
                    }
                  : null,
            ),
            trailing: isSelected && enabled
                ? Switch(
                    value: isRequired,
                    onChanged: (value) {
                      setState(() {
                        requiredFields[key] = value;
                      });
                    },
                    activeColor: Colors.green,
                  )
                : null,
            enabled: enabled,
          ),
        );
      }).toList(),
    );
  }

  // 獲取欄位類型的顯示文本
  String _getFieldTypeText(String type) {
    switch (type) {
      case 'text':
        return '文字';
      case 'number':
        return '數字';
      case 'dropdown':
        return '下拉選單';
      case 'date':
        return '日期';
      default:
        return type;
    }
  }
}
