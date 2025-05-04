import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide FieldValue;
import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:intl/intl.dart';
import '../utils/age_group_handler.dart'; // 添加年齡分組處理工具的匯入
import '../utils/searching_function.dart'; // 添加搜索函數導入

class RegistrationsListScreen extends StatefulWidget {
  final String competitionId;
  final String competitionName;

  const RegistrationsListScreen({
    Key? key,
    required this.competitionId,
    required this.competitionName,
  }) : super(key: key);

  @override
  State<RegistrationsListScreen> createState() =>
      _RegistrationsListScreenState();
}

class _RegistrationsListScreenState extends State<RegistrationsListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  List<Map<String, dynamic>> _registrations = [];
  List<Map<String, dynamic>> _filteredRegistrations = [];
  String _selectedFilter = '全部';

  // 新增：存儲項目人數上限資料
  List<Map<String, dynamic>> _eventLimits = [];
  bool _isLoadingEventLimits = true;

  // 改為動態從Firebase載入的年齡分組對應表
  Map<String, Map<String, int>> _ageGroups = {};

  // 新增：用於追踪選中的運動員f
  Set<String> _selectedAthletes = {};
  bool _selectAllMode = false;

  bool _isEventListExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadAgeGroups(); // 先載入年齡分組設定
    _loadRegistrations();
    _loadEventLimits(); // 新增：載入項目人數上限
    _searchController.addListener(_filterRegistrations);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterRegistrations);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 載入年齡分組設定
  Future<void> _loadAgeGroups() async {
    try {
      // 從比賽文檔中獲取年齡分組設定
      final competitionDoc = await _firestore
          .collection('competitions')
          .doc(widget.competitionId)
          .get();

      if (!competitionDoc.exists) {
        setState(() {
          _ageGroups = {}; // 不使用預設值，保持空集合
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('找不到比賽資料，無法載入年齡分組'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final competitionData = competitionDoc.data() as Map<String, dynamic>;

      // 使用 AgeGroupHandler 統一處理年齡分組
      List<Map<String, dynamic>> ageGroups =
          AgeGroupHandler.loadAgeGroupsFromMetadata(
              competitionData['metadata'] as Map<String, dynamic>?);

      if (ageGroups.isNotEmpty) {
        // 轉換為報名列表頁面需要的格式
        Map<String, Map<String, int>> parsedAgeGroups = {};

        for (var group in ageGroups) {
          final String groupName = group['name'] ?? '未命名';
          final int startAge = group['startAge'] ?? 0;
          final int endAge = group['endAge'] ?? 0;

          parsedAgeGroups[groupName] = {
            'min': startAge,
            'max': endAge,
          };
        }

        setState(() {
          _ageGroups = parsedAgeGroups;
        });
      } else {
        // 如果沒有找到有效的年齡分組設定，使用空集合
        setState(() {
          _ageGroups = {};
        });
      }
    } catch (e) {
      debugPrint('載入年齡分組設定失敗: $e');
      // 發生錯誤時，設置為空集合
      setState(() {
        _ageGroups = {};
      });
    }
  }

  // 載入所有報名者
  Future<void> _loadRegistrations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 從參與者集合獲取數據
      final participantsSnapshot = await _firestore
          .collection('participants')
          .where('competitionId', isEqualTo: widget.competitionId)
          .get();

      // 2. 從舊的registrations集合獲取數據
      final registrationsSnapshot = await _firestore
          .collection('registrations')
          .where('competitionId', isEqualTo: widget.competitionId)
          .get();

      List<Map<String, dynamic>> registrations = [];
      Set<String> userIds = {}; // 存儲所有需要獲取數據的用戶ID

      // 3. 處理participants數據並收集用戶ID
      for (var doc in participantsSnapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String;
        userIds.add(userId);

        registrations.add({
          'id': doc.id,
          'userId': userId,
          'competitionId': data['competitionId'],
          'events': data['events'] as List<dynamic>,
          'status': data['status'] as String,
          'formData': data['formData'] as Map<String, dynamic>,
          'submittedAt': data['submittedAt'],
          'userName': data['formData']['name'] ?? '未知用戶',
          'userEmail': '',
          'userSchool': data['formData']['school'] ?? '',
          'userClass': data['formData']['class'] ?? '',
          'ageGroup': data['formData']['ageGroup'] ?? '',
        });
      }

      // 4. 處理registrations數據並收集用戶ID
      for (var doc in registrationsSnapshot.docs) {
        final data = doc.data();
        final athleteId =
            data['athleteId'] as String? ?? data['userId'] as String?;

        if (athleteId == null) continue;
        userIds.add(athleteId);

        final formData = data['data'] as Map<String, dynamic>? ?? {};

        // 嘗試從formData中獲取events
        List<dynamic> events = [];
        if (formData.containsKey('events')) {
          final eventsValue = formData['events'];
          if (eventsValue is String) {
            events = eventsValue.split(',').map((e) => e.trim()).toList();
          } else if (eventsValue is List) {
            events = eventsValue;
          }
        } else if (data.containsKey('events') && data['events'] is List) {
          events = data['events'] as List<dynamic>;
        }

        registrations.add({
          'id': doc.id,
          'userId': athleteId,
          'competitionId': data['competitionId'],
          'competitionName': data['competitionName'],
          'events': events,
          'status': data['status'] ?? 'pending', // 默認狀態
          'formData': formData,
          'submittedAt': data['submittedAt'],
          'userName': formData['name'] ?? '未知用戶',
          'userEmail': '',
          'userSchool': formData['school'] ?? '',
          'userClass': formData['class'] ?? '',
          'ageGroup': formData['ageGroup'] ?? '',
        });
      }

      // 5. 批量獲取用戶數據
      Map<String, Map<String, dynamic>> usersData =
          await _batchGetUsersData(userIds.toList());

      // 6. 更新報名數據中的用戶信息
      for (var i = 0; i < registrations.length; i++) {
        final userId = registrations[i]['userId'] as String;
        if (usersData.containsKey(userId)) {
          final userData = usersData[userId]!;

          // 只在表單中沒有值時，才使用用戶文檔中的值
          if (registrations[i]['userName'] == '未知用戶') {
            registrations[i]['userName'] = userData['username'] ?? '未知用戶';
          }

          registrations[i]['userEmail'] = userData['email'] ?? '';

          if (registrations[i]['userSchool'].toString().isEmpty) {
            registrations[i]['userSchool'] = userData['school'] ?? '';
          }
        }
      }

      // 按提交時間降序排序
      registrations.sort((a, b) {
        final aTime = a['submittedAt'] as Timestamp?;
        final bTime = b['submittedAt'] as Timestamp?;

        if (aTime == null) return 1;
        if (bTime == null) return -1;

        return bTime.compareTo(aTime);
      });

      setState(() {
        _registrations = registrations;
        _filteredRegistrations = registrations;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('載入報名資料出錯: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('載入報名資料出錯: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 批量獲取用戶數據
  Future<Map<String, Map<String, dynamic>>> _batchGetUsersData(
      List<String> userIds) async {
    Map<String, Map<String, dynamic>> result = {};

    if (userIds.isEmpty) return result;

    try {
      // Firestore一次最多查詢10個文檔，所以需要分批處理
      for (var i = 0; i < userIds.length; i += 10) {
        final end = (i + 10 < userIds.length) ? i + 10 : userIds.length;
        final batch = userIds.sublist(i, end);

        try {
          final querySnapshot = await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: batch)
              .get();

          for (var doc in querySnapshot.docs) {
            result[doc.id] = doc.data();
          }
        } catch (batchError) {
          // 如果批量查詢失敗，嘗試單個查詢
          debugPrint('批量查詢失敗，使用單個查詢: $batchError');
          for (var userId in batch) {
            try {
              final userDoc =
                  await _firestore.collection('users').doc(userId).get();
              if (userDoc.exists) {
                result[userId] = userDoc.data() as Map<String, dynamic>;
              }
            } catch (individualError) {
              debugPrint('獲取用戶 $userId 的資料失敗: $individualError');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('批量獲取用戶數據出錯: $e');
    }

    return result;
  }

  // 新增：載入項目人數上限資料
  Future<void> _loadEventLimits() async {
    setState(() {
      _isLoadingEventLimits = true;
    });

    try {
      // 從比賽文檔中獲取項目設置
      final competitionDoc = await _firestore
          .collection('competitions')
          .doc(widget.competitionId)
          .get();

      if (!competitionDoc.exists) {
        setState(() {
          _eventLimits = [];
          _isLoadingEventLimits = false;
        });
        return;
      }

      final competitionData = competitionDoc.data() as Map<String, dynamic>;
      List<Map<String, dynamic>> events = [];
      List<String> eventNames = []; // 儲存所有項目名稱
      Map<String, int> eventLimits = {}; // 儲存每個項目的人數上限

      // 從metadata中獲取項目資料和限制
      if (competitionData.containsKey('metadata') &&
          competitionData['metadata'] != null &&
          competitionData['metadata']['events'] != null) {
        final eventsData =
            competitionData['metadata']['events'] as List<dynamic>;

        // 提取所有項目名稱和上限
        for (var event in eventsData) {
          if (event is Map<String, dynamic>) {
            final String eventName = event['name'] ?? '未命名項目';
            final int limit = event['limit'] ?? 50; // 預設上限為50人
            eventNames.add(eventName);
            eventLimits[eventName] = limit;
          }
        }
      }
      // 從events欄位獲取項目資料(舊格式兼容)
      else if (competitionData.containsKey('events')) {
        try {
          final dynamic eventsData = competitionData['events'];

          if (eventsData is List) {
            for (var event in eventsData) {
              String eventName;
              int limit = 50; // 預設上限

              if (event is Map<String, dynamic>) {
                eventName = event['name'] ?? '未命名項目';
                limit = event['limit'] ?? 50;
              } else if (event is String) {
                eventName = event;
              } else {
                continue; // 跳過無效格式
              }

              eventNames.add(eventName);
              eventLimits[eventName] = limit;
            }
          }
        } catch (e) {
          debugPrint('處理舊格式的項目數據時出錯: $e');
        }
      }

      // 如果沒有項目數據，使用默認的示例數據
      if (eventNames.isEmpty) {
        eventNames = ["100米短跑", "跳遠", "鉛球"];
        eventLimits = {"100米短跑": 50, "跳遠": 50, "鉛球": 50};
      }

      // 獲取各項目報名人數 - 批量查詢以減少網絡請求
      Map<String, int> eventCounts = {};

      // 初始化計數器
      for (var eventName in eventNames) {
        eventCounts[eventName] = 0;
      }

      // 從 registrations 集合統一獲取數據
      try {
        final registrationsSnapshot = await _firestore
            .collection('registrations')
            .where('competitionId', isEqualTo: widget.competitionId)
            .get();

        // 遍歷所有報名，統計各項目報名人數
        for (var doc in registrationsSnapshot.docs) {
          final data = doc.data();
          List<dynamic> selectedEvents = [];

          // 提取選擇的項目
          if (data.containsKey('events') && data['events'] != null) {
            selectedEvents = data['events'] as List<dynamic>;
          } else if (data.containsKey('data') &&
              data['data'] != null &&
              data['data'] is Map<String, dynamic> &&
              data['data'].containsKey('events')) {
            final eventsData = data['data']['events'];
            if (eventsData is List) {
              selectedEvents = eventsData;
            } else if (eventsData is String) {
              selectedEvents =
                  eventsData.split(',').map((e) => e.trim()).toList();
            }
          }

          // 更新各項目計數
          for (var eventName in eventNames) {
            if (selectedEvents.any((e) => e.toString() == eventName)) {
              eventCounts[eventName] = (eventCounts[eventName] ?? 0) + 1;
            }
          }
        }

        debugPrint('從 registrations 集合統計項目報名人數: $eventCounts');
      } catch (e) {
        debugPrint('從 registrations 統計報名人數出錯: $e');

        // 如果 registrations 集合出錯，嘗試從 participants 集合獲取
        try {
          final participantsSnapshot = await _firestore
              .collection('participants')
              .where('competitionId', isEqualTo: widget.competitionId)
              .get();

          // 遍歷所有報名，統計各項目報名人數
          for (var doc in participantsSnapshot.docs) {
            final data = doc.data();
            if (data.containsKey('events') && data['events'] is List<dynamic>) {
              final events = data['events'] as List<dynamic>;

              // 更新各項目計數
              for (var eventName in eventNames) {
                if (events.contains(eventName)) {
                  eventCounts[eventName] = (eventCounts[eventName] ?? 0) + 1;
                }
              }
            }
          }

          debugPrint('從 participants 集合統計項目報名人數: $eventCounts');
        } catch (e) {
          debugPrint('從 participants 統計報名人數出錯: $e');
        }
      }

      // 構建最終的項目數據
      for (var eventName in eventNames) {
        events.add({
          "name": eventName,
          "limit": eventLimits[eventName] ?? 50,
          "registered": eventCounts[eventName] ?? 0,
        });
      }

      setState(() {
        _eventLimits = events;
        _isLoadingEventLimits = false;
      });
    } catch (e) {
      debugPrint('載入項目人數上限出錯: $e');
      setState(() {
        _eventLimits = [];
        _isLoadingEventLimits = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('載入項目人數上限出錯: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _filterRegistrations() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      if (query.isEmpty && _selectedFilter == '全部') {
        _filteredRegistrations = _registrations;
        return;
      }

      Map<String, String> filters = {};
      if (_selectedFilter != '全部' && _ageGroups.containsKey(_selectedFilter)) {
        filters['ageGroup'] = _selectedFilter;
      }

      _filteredRegistrations = searchAthletes(
        _registrations,
        query,
        filters,
      );
    });
  }

  void _viewRegistrationDetails(Map<String, dynamic> registration) {
    final formData = registration['formData'] as Map<String, dynamic>;
    final String? birthDate = formData['birthDate'] as String?;
    final String? ageGroup = registration['ageGroup'] as String?;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          '${registration['userName']} 的報名資料',
          style: const TextStyle(fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顯示報名狀態
              Text(
                '狀態: ${_getStatusText(registration['status'])}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(registration['status']),
                ),
              ),
              const SizedBox(height: 16),

              // 顯示用戶基本信息
              Text('電子郵件: ${registration['userEmail']}'),
              if (registration['userSchool'] != null &&
                  registration['userSchool'].isNotEmpty)
                Text('學校: ${registration['userSchool']}'),
              if (registration['userClass'] != null &&
                  registration['userClass'].isNotEmpty)
                Text('班級: ${registration['userClass']}'),
              if (ageGroup != null && ageGroup.isNotEmpty)
                Text('年齡組別: $ageGroup'),
              if (birthDate != null && birthDate.isNotEmpty)
                Text('出生日期: $birthDate'),
              const Divider(height: 24),

              // 顯示報名項目
              const Text('報名項目:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              ...(registration['events'] as List<dynamic>).map(
                (event) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.sports, size: 16),
                      const SizedBox(width: 8),
                      Text(event.toString()),
                    ],
                  ),
                ),
              ),

              const Divider(height: 24),

              // 顯示表單數據
              const Text('表單數據:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              ...formData.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.key}:',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(entry.value.toString()),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 24),

              // 顯示提交時間
              if (registration['submittedAt'] != null)
                Text(
                  '提交時間: ${DateFormat('yyyy-MM-dd HH:mm').format((registration['submittedAt'] as Timestamp).toDate())}',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
          TextButton(
            onPressed: () => _updateStatus(registration, 'approved'),
            child: const Text('核准', style: TextStyle(color: Colors.green)),
          ),
          TextButton(
            onPressed: () => _updateStatus(registration, 'rejected'),
            child: const Text('拒絕', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 更新報名狀態
  Future<void> _updateStatus(
      Map<String, dynamic> registration, String newStatus,
      [String reason = '']) async {
    try {
      // 確認操作
      bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('確認${newStatus == 'approved' ? '核准' : '拒絕'}'),
          content: Text(
              '確定要${newStatus == 'approved' ? '核准' : '拒絕'} ${registration['userName']} 的報名嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('確認'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // 使用try-catch確保對話框可以正確關閉
      try {
        // 確認成功後，顯示載入指示器
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('處理中...'),
              ],
            ),
          ),
        );

        final registrationId = registration['id'];
        if (registrationId == null) {
          throw Exception('報名ID為空');
        }

        // 根據文檔ID判斷是participants還是registrations集合
        bool isParticipant = registrationId.toString().contains('_');

        if (isParticipant) {
          // 更新participants集合中的文檔
          await _firestore
              .collection('participants')
              .doc(registrationId.toString())
              .update({
            'status': newStatus,
            'statusReason': reason.isNotEmpty ? reason : null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // 更新registrations集合中的文檔
          await _firestore
              .collection('registrations')
              .doc(registrationId.toString())
              .update({
            'status': newStatus,
            'statusReason': reason.isNotEmpty ? reason : null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // 如果是核准狀態，將資料儲存到比賽專屬的集合中
        if (newStatus == 'approved') {
          await _saveToCompetitionCollection(registration);
        }

        // 確保載入對話框已關閉
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();

        // 更新本地數據
        if (!mounted) return;
        setState(() {
          final index =
              _registrations.indexWhere((r) => r['id'] == registrationId);
          if (index != -1) {
            _registrations[index]['status'] = newStatus;
            if (reason.isNotEmpty) {
              _registrations[index]['statusReason'] = reason;
            }
          }

          // 重新過濾
          _filterRegistrations();
        });

        // 關閉詳情對話框
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();

        // 顯示成功信息
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已${newStatus == 'approved' ? '核准' : '拒絕'}報名'),
            backgroundColor:
                newStatus == 'approved' ? Colors.green : Colors.red,
          ),
        );
      } catch (dialogError) {
        // 確保在出錯時所有對話框都被關閉
        try {
          if (!mounted) return;
          Navigator.of(context, rootNavigator: true).pop();
        } catch (e) {
          debugPrint('關閉載入對話框出錯: $e');
        }
        rethrow; // 重新拋出異常讓外層處理
      }
    } catch (e) {
      debugPrint('處理報名狀態時出錯: $e');

      // 確保對話框被關閉
      try {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
      } catch (navError) {
        debugPrint('關閉對話框出錯: $navError');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('更新狀態失敗: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 將核准的報名資料儲存到比賽專屬的集合中
  Future<void> _saveToCompetitionCollection(
      Map<String, dynamic> registration) async {
    try {
      // 顯示載入指示器
      if (!mounted) return; // 添加 mounted 檢查

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const SimpleDialog(
          contentPadding: EdgeInsets.all(16),
          children: [
            Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text("儲存中...", style: TextStyle(fontSize: 16)),
              ],
            ),
          ],
        ),
      );

      // 安全提取必要的資料，避免空值和型別錯誤
      final String competitionId =
          registration['competitionId']?.toString() ?? '';
      final String userId = registration['userId']?.toString() ?? '';

      // 檢查必要欄位
      if (competitionId.isEmpty || userId.isEmpty) {
        debugPrint('無法儲存到比賽專屬集合: 缺少必要的competitionId或userId');
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop(); // 關閉載入對話框
        return;
      }

      final String userName = registration['userName']?.toString() ?? '未知用戶';

      // 安全處理可能為null的列表
      List<dynamic> events = [];
      if (registration['events'] != null) {
        if (registration['events'] is List) {
          events = List<dynamic>.from(registration['events'] as List<dynamic>);
        } else if (registration['events'] is String) {
          // 嘗試將字串轉換為列表
          events = [registration['events']];
        }
      }

      final String? ageGroup = registration['ageGroup']?.toString();

      // 安全處理formData - 使用深度複製避免引用問題
      Map<String, dynamic> formData = {};
      if (registration['formData'] != null && registration['formData'] is Map) {
        formData = Map<String, dynamic>.from(registration['formData'] as Map);
      }

      // 建立一個包含所有必要資料的文檔
      Map<String, dynamic> athleteData = {
        'userId': userId,
        'userName': userName,
        'ageGroup': ageGroup,
        'events': events,
        'status': 'approved',
        'school': registration['userSchool']?.toString() ??
            formData['school']?.toString() ??
            '',
        'class': registration['userClass']?.toString() ??
            formData['class']?.toString() ??
            '',
        'email': registration['userEmail']?.toString() ?? '',
        'phone': formData['phone']?.toString() ?? '',
        'formData': formData,
        'approvedAt': FieldValue.serverTimestamp(),
        'registrationId': registration['id'],
        'competitionId': competitionId,
        'gender': '男', // 所有核准的運動員預設為男性
      };

      // 建立比賽專屬的集合名稱
      String collectionName = 'competition_$competitionId';

      // 使用事務來確保數據一致性
      await _firestore.runTransaction((transaction) async {
        // 儲存到比賽專屬的集合中，使用userId作為文檔ID以避免重複
        transaction.set(
          _firestore.collection(collectionName).doc(userId),
          athleteData,
        );

        // 嘗試更新用戶資料以記錄其參加的比賽
        try {
          // 先獲取現有的用戶文檔
          DocumentSnapshot userDoc = await transaction.get(
            _firestore.collection('users').doc(userId),
          );

          if (userDoc.exists) {
            // 檢查用戶是否已有competitions欄位
            Map<String, dynamic> userData =
                userDoc.data() as Map<String, dynamic>;
            List<dynamic> competitions = [];

            if (userData.containsKey('competitions') &&
                userData['competitions'] is List) {
              competitions =
                  List<dynamic>.from(userData['competitions'] as List);
            }

            // 檢查競賽是否已存在於列表中
            bool competitionExists = competitions.any((comp) =>
                comp is Map && comp['competitionId'] == competitionId);

            if (!competitionExists) {
              // 添加新的比賽記錄
              competitions.add({
                'competitionId': competitionId,
                'ageGroup': ageGroup,
                'status': 'active',
                'approvedAt': FieldValue.serverTimestamp()
              });

              // 更新用戶文檔
              transaction.update(
                _firestore.collection('users').doc(userId),
                {'competitions': competitions},
              );
            }
          }
        } catch (userUpdateError) {
          // 不中斷流程，但記錄錯誤
          debugPrint('更新用戶參賽記錄失敗，但運動員資料已成功儲存: $userUpdateError');
        }
      });

      debugPrint('成功將運動員資料儲存到比賽專屬集合: $collectionName');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('核准成功，運動員資料已加入比賽'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('儲存到比賽專屬集合失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('儲存運動員資料失敗: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // 確保對話框被關閉
      try {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
      } catch (e) {
        debugPrint('關閉對話框出錯: $e');
      }
    }
  }

  // 獲取狀態文字
  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return '待審核';
      case 'approved':
        return '已核准';
      case 'rejected':
        return '已拒絕';
      default:
        return '未知';
    }
  }

  // 獲取狀態顏色
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // 構建報名卡片
  Widget _buildRegistrationCard(Map<String, dynamic> registration) {
    final status = registration['status'] as String;
    final events = registration['events'] as List<dynamic>;
    final Timestamp? submittedAt = registration['submittedAt'] as Timestamp?;
    final String registrationId = registration['id'] as String;
    final bool isSelected = _selectedAthletes.contains(registrationId);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      elevation: 1,
      // 在選擇模式下，卡片可能會有不同的外觀
      shape: _selectAllMode
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
                width: isSelected ? 2.0 : 1.0,
              ),
            )
          : null,
      child: InkWell(
        onTap: () {
          // 在選擇模式下，點擊卡片會選中/取消選中
          if (_selectAllMode) {
            setState(() {
              if (isSelected) {
                _selectedAthletes.remove(registrationId);
              } else {
                _selectedAthletes.add(registrationId);
              }
            });
          } else {
            // 非選擇模式下，點擊查看詳情
            _viewRegistrationDetails(registration);
          }
        },
        child: Column(
          children: [
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: _selectAllMode
                  ? Icon(
                      isSelected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: isSelected ? Colors.blue : Colors.grey,
                    )
                  : const Icon(Icons.person, color: Colors.blue),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      registration['userName'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _getStatusColor(status)),
                    ),
                    child: Text(
                      _getStatusText(status),
                      style: TextStyle(
                          color: _getStatusColor(status), fontSize: 12),
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.school, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${registration['userSchool']} ${registration['userClass']}',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (registration['ageGroup'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(Icons.people, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${registration['ageGroup']} 組',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  if (submittedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('yyyy-MM-dd HH:mm')
                                .format(submittedAt.toDate()),
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle,
                        color: Colors.green, size: 20),
                    onPressed: () => _updateStatus(registration, 'approved'),
                    tooltip: '核准',
                  ),
                  IconButton(
                    icon: const Icon(Icons.visibility, size: 20),
                    onPressed: () => _viewRegistrationDetails(registration),
                    tooltip: '查看詳情',
                  ),
                ],
              ),
            ),
            if (events.isNotEmpty && !_selectAllMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: events
                          .map((event) => Chip(
                                label: Text(event.toString()),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                labelStyle: const TextStyle(fontSize: 12),
                                backgroundColor:
                                    Colors.blue.withValues(alpha: 0.1),
                                padding: EdgeInsets.zero,
                                labelPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 0),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('已報名運動員: ${widget.competitionName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRegistrations,
          ),
        ],
      ),
      body: Column(
        children: [
          // 顯示各項目參賽人數上限卡片
          Card(
            margin: const EdgeInsets.all(16),
            child: InkWell(
              onTap: () {
                setState(() {
                  _isEventListExpanded = !_isEventListExpanded;
                });
                // 重新載入數據
                if (_isEventListExpanded && !_isLoadingEventLimits) {
                  _loadEventLimits();
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 標題行
                    Row(
                      children: [
                        const Text(
                          '查看報名人數',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 只在標題旁顯示總參賽人數上限
                        if (!_isLoadingEventLimits && _eventLimits.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Text(
                              '總上限：${_calculateTotalLimit()}人',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const Spacer(),
                        // 更明確的展開/收起提示
                        Row(
                          children: [
                            Text(
                              _isEventListExpanded ? '收起' : '展開',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 14,
                              ),
                            ),
                            Icon(
                              _isEventListExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.blue.shade700,
                            ),
                          ],
                        ),
                      ],
                    ),
                    // 項目列表 - 僅在展開狀態顯示
                    if (_isEventListExpanded)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: _isLoadingEventLimits
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : _buildEventLimitsList(),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 搜索欄
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索參賽者姓名、學校或項目',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // 添加選擇模式切換按鈕和批量核准按鈕
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      icon:
                          Icon(_selectAllMode ? Icons.cancel : Icons.checklist),
                      label: Text(_selectAllMode ? '取消' : '選擇'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectAllMode
                            ? Colors.red.shade100
                            : Colors.blue.shade100,
                        foregroundColor: _selectAllMode
                            ? Colors.red.shade700
                            : Colors.blue.shade700,
                      ),
                      onPressed: () {
                        setState(() {
                          _selectAllMode = !_selectAllMode;
                          // 切換模式時清空選擇
                          _selectedAthletes.clear();
                        });
                      },
                    ),

                    // 批量核准按鈕 - 僅在選擇模式下顯示，且有選中項目時
                    if (_selectAllMode && _selectedAthletes.isNotEmpty)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle),
                        label: Text('批量核准(${_selectedAthletes.length})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _batchApproveAthletes,
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // 選擇模式下顯示全選按鈕
                if (_selectAllMode)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(
                            _selectedAthletes.length ==
                                    _filteredRegistrations.length
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                          ),
                          label: Text(
                            _selectedAthletes.length ==
                                    _filteredRegistrations.length
                                ? '取消全選'
                                : '全選',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedAthletes.length ==
                                    _filteredRegistrations.length
                                ? Colors.blue
                                : Colors.grey.shade200,
                            foregroundColor: _selectedAthletes.length ==
                                    _filteredRegistrations.length
                                ? Colors.white
                                : Colors.black,
                          ),
                          onPressed: () {
                            setState(() {
                              if (_selectedAthletes.length ==
                                  _filteredRegistrations.length) {
                                // 如果已經全選，則取消全選
                                _selectedAthletes.clear();
                              } else {
                                // 否則選擇所有項目
                                _selectedAthletes = _filteredRegistrations
                                    .map((reg) => reg['id'] as String)
                                    .toSet();
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '已選擇: ${_selectedAthletes.length}/${_filteredRegistrations.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                _buildFilterChips(),
              ],
            ),
          ),

          // 報名者列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRegistrations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.assignment,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty &&
                                      _selectedFilter == '全部'
                                  ? '此比賽尚無人報名'
                                  : '沒有符合條件的報名者',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 16),
                        controller: _scrollController,
                        itemCount: _filteredRegistrations.length,
                        itemBuilder: (context, index) {
                          final registration = _filteredRegistrations[index];
                          return _buildRegistrationCard(registration);
                        },
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // 構建上方的篩選chip
  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: [
              // 全部
              FilterChip(
                label: const Text('全部'),
                selected: _selectedFilter == '全部',
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedFilter = '全部';
                      _filterRegistrations();
                    });
                  }
                },
              ),
              // 年齡分組篩選 - 只在有分組數據時顯示
              if (_ageGroups.isNotEmpty)
                ..._ageGroups.keys.map((groupName) {
                  final ageRange = _ageGroups[groupName]!;
                  return FilterChip(
                    // 分組名稱來自Firebase，就不需要額外添加"組"字
                    label: Text(
                        '$groupName (${ageRange['min']}-${ageRange['max']}歲)'),
                    selected: _selectedFilter == groupName,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedFilter = groupName;
                          _filterRegistrations();
                        });
                      }
                    },
                  );
                }).toList(),
            ],
          ),
        ],
      ),
    );
  }

  // 構建項目人數上限列表
  Widget _buildEventLimitsList() {
    // 如果正在加載數據，顯示加載指示器
    if (_isLoadingEventLimits) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(height: 8),
            Text('正在載入項目數據...', style: TextStyle(fontSize: 14)),
          ],
        ),
      );
    }

    // 如果沒有項目數據，顯示提示信息
    if (_eventLimits.isEmpty) {
      return const Center(
        child: Text('未找到項目設置數據',
            style: TextStyle(fontSize: 14, color: Colors.grey)),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _eventLimits.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final event = _eventLimits[index];
        return ListTile(
          dense: true,
          title: Text(
            event["name"],
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Text(
            "${event["registered"]} 人已報名",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
            ),
          ),
          onTap: () => _showEventRegistrations(event["name"]),
        );
      },
    );
  }

  // 顯示選擇特定項目的報名者
  void _showEventRegistrations(String eventName) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$eventName 的報名選手'),
        content: FutureBuilder<List<Map<String, dynamic>>>(
          future: _getEventRegistrations(eventName),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text('載入 $eventName 的報名選手...'),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return SizedBox(
                height: 100,
                child: Center(
                  child: Text(
                    '載入失敗: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            }

            final registrations = snapshot.data ?? [];

            if (registrations.isEmpty) {
              return const SizedBox(
                height: 100,
                child: Center(
                  child: Text('沒有選手報名此項目'),
                ),
              );
            }

            return SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: registrations.length,
                itemBuilder: (context, index) {
                  final registration = registrations[index];
                  return ListTile(
                    title: Text(registration['userName'] ?? '未知選手'),
                    subtitle: Text(
                        '${registration['userSchool'] ?? ''} ${registration['ageGroup'] ?? ''}'),
                    trailing: Text(
                      _getStatusText(registration['status'] ?? 'pending'),
                      style: TextStyle(
                        color: _getStatusColor(
                            registration['status'] ?? 'pending'),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _viewRegistrationDetails(registration);
                    },
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  // 獲取報名特定項目的選手
  Future<List<Map<String, dynamic>>> _getEventRegistrations(
      String eventName) async {
    List<Map<String, dynamic>> eventRegistrations = [];

    try {
      // 從 registrations 集合獲取數據（優先）
      final registrationsSnapshot = await _firestore
          .collection('registrations')
          .where('competitionId', isEqualTo: widget.competitionId)
          .get();

      for (var doc in registrationsSnapshot.docs) {
        final data = doc.data();
        List<dynamic> selectedEvents = [];

        // 提取選擇的項目
        if (data.containsKey('events') && data['events'] != null) {
          selectedEvents = data['events'] as List<dynamic>;
        } else if (data.containsKey('data') &&
            data['data'] != null &&
            data['data'] is Map<String, dynamic> &&
            data['data'].containsKey('events')) {
          final eventsData = data['data']['events'];
          if (eventsData is List) {
            selectedEvents = eventsData;
          } else if (eventsData is String) {
            selectedEvents =
                eventsData.split(',').map((e) => e.trim()).toList();
          }
        }

        // 檢查這位報名者是否選擇了當前項目
        if (selectedEvents.any((e) => e.toString() == eventName)) {
          String userName = data['name'] ?? '未知選手';
          String userSchool = '';
          String ageGroup = '';
          String status = 'pending';

          if (data.containsKey('data') &&
              data['data'] is Map<String, dynamic>) {
            final formData = data['data'] as Map<String, dynamic>;
            userName = formData['name'] ?? userName;
            userSchool = formData['school'] ?? '';
            ageGroup = formData['ageGroup'] ?? '';
          }

          eventRegistrations.add({
            'id': doc.id,
            'userName': userName,
            'userSchool': userSchool,
            'ageGroup': ageGroup,
            'status': status,
            'events': selectedEvents,
            'formData': data.containsKey('data') ? data['data'] : {},
            'submittedAt': data['submittedAt'],
          });
        }
      }

      // 如果從 registrations 找不到數據，嘗試從 participants 獲取
      if (eventRegistrations.isEmpty) {
        final participantsSnapshot = await _firestore
            .collection('participants')
            .where('competitionId', isEqualTo: widget.competitionId)
            .where('events', arrayContains: eventName)
            .get();

        for (var doc in participantsSnapshot.docs) {
          final data = doc.data();

          eventRegistrations.add({
            'id': doc.id,
            'userName': data['userName'] ?? '未知選手',
            'userSchool': data['userSchool'] ?? '',
            'ageGroup': data['ageGroup'] ?? '',
            'status': data['status'] ?? 'pending',
            'events': data['events'] ?? [],
            'formData': data['formData'] ?? {},
            'submittedAt': data['submittedAt'],
          });
        }
      }

      // 按提交時間排序
      eventRegistrations.sort((a, b) {
        final aTime = a['submittedAt'] as Timestamp?;
        final bTime = b['submittedAt'] as Timestamp?;

        if (aTime == null) return 1;
        if (bTime == null) return -1;

        return bTime.compareTo(aTime);
      });

      return eventRegistrations;
    } catch (e) {
      debugPrint('獲取項目 $eventName 的報名者出錯: $e');
      return [];
    }
  }

  // 批量核准選擇的運動員
  Future<void> _batchApproveAthletes() async {
    if (_selectedAthletes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先選擇要核准的運動員')),
      );
      return;
    }

    // 顯示確認對話框
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量核准運動員'),
        content: Text('確定要一次核准所選的 ${_selectedAthletes.length} 名運動員嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('確定核准'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 檢查組件是否仍然掛載
    if (!mounted) return;

    // 顯示進度對話框
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          title: Text('正在批量核准'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在處理，請耐心等待...'),
            ],
          ),
        );
      },
    );

    try {
      // 獲取所有選中的運動員資料
      List<Map<String, dynamic>> selectedRegistrations = [];

      for (var registration in _filteredRegistrations) {
        if (_selectedAthletes.contains(registration['id'])) {
          selectedRegistrations.add(registration);
        }
      }

      // 批量處理所有選中的運動員
      int successCount = 0;
      int skipCount = 0;
      List<String> failedAthletes = [];

      for (var registration in selectedRegistrations) {
        try {
          final id = registration['id'];
          final status = registration['status'];

          // 跳過已經是核准狀態的資料
          if (status == 'approved') {
            skipCount++;
            continue;
          }

          // 創建副本避免影響原始數據
          Map<String, dynamic> registrationCopy = Map.from(registration);

          // 設定性別為男
          registrationCopy['gender'] = '男';

          // 更新狀態並保存到專屬集合
          registrationCopy['status'] = 'approved';

          await _saveToCompetitionCollection(registrationCopy);

          // 更新原始集合中的狀態
          try {
            // 優先嘗試更新 participants 集合
            final competitionId = registration['competitionId'];
            if (competitionId != null) {
              try {
                final participantsQuery = await _firestore
                    .collection('participants')
                    .where('competitionId', isEqualTo: competitionId)
                    .where(FieldPath.documentId, isEqualTo: id)
                    .get();

                if (participantsQuery.docs.isNotEmpty) {
                  await _firestore.collection('participants').doc(id).update({
                    'status': 'approved',
                    'approvedAt': FieldValue.serverTimestamp(),
                  });
                }
              } catch (e) {
                debugPrint('更新 participants 集合出錯，嘗試更新 registrations: $e');
              }
            }

            // 嘗試更新 registrations 集合
            await _firestore.collection('registrations').doc(id).update({
              'status': 'approved',
              'approvedAt': FieldValue.serverTimestamp(),
            });
          } catch (updateError) {
            debugPrint('更新狀態失敗，但已儲存到比賽專屬集合: $updateError');
          }

          // 計數成功處理的數量
          successCount++;
        } catch (e) {
          failedAthletes.add(registration['userName'] ?? '未知運動員');
          debugPrint('批量處理運動員時出錯: $e');
          // 繼續處理下一個，不中斷整個批次
        }
      }

      // 關閉進度對話框
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      // 刷新列表
      await _loadRegistrations();

      // 清空選擇
      if (!mounted) return;
      setState(() {
        _selectedAthletes.clear();
        _selectAllMode = false; // 完成後退出選擇模式
      });

      // 顯示處理結果
      String resultMessage;
      if (failedAthletes.isEmpty) {
        resultMessage =
            '成功核准 $successCount 名運動員${skipCount > 0 ? '，跳過 $skipCount 名已核准運動員' : ''}';
      } else {
        resultMessage =
            '已核准 $successCount 名運動員，但有 ${failedAthletes.length} 名運動員處理失敗';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultMessage),
          backgroundColor:
              failedAthletes.isEmpty ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 5),
          action: failedAthletes.isNotEmpty
              ? SnackBarAction(
                  label: '查看失敗名單',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('處理失敗的運動員'),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: failedAthletes.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                leading: const Icon(Icons.error_outline,
                                    color: Colors.red),
                                title: Text(failedAthletes[index]),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                )
              : null,
        ),
      );
    } catch (e) {
      // 關閉進度對話框
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      // 顯示錯誤
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('批量處理時發生錯誤: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 計算總人數上限
  int _calculateTotalLimit() {
    int totalLimit = 0;
    for (var event in _eventLimits) {
      totalLimit += event["limit"] as int;
    }
    return totalLimit;
  }
}
