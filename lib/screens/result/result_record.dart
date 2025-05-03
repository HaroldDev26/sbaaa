import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'track_event_timer_screen.dart';
import 'field_event_record_screen.dart';
import 'event_result_screen.dart';
import 'relay_event_timer_screen.dart';

class ResultRecordScreen extends StatefulWidget {
  final String competitionId;
  final String competitionName;

  const ResultRecordScreen({
    Key? key,
    required this.competitionId,
    required this.competitionName,
  }) : super(key: key);

  @override
  State<ResultRecordScreen> createState() => _ResultRecordScreenState();
}

class _ResultRecordScreenState extends State<ResultRecordScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _matchedEvents = [];
  int _completedEventsCount = 0; // 追蹤已有成績記錄的項目數量

  late TabController _tabController;

  // 項目類型
  final List<String> _eventTypes = ['徑賽', '田賽', '接力'];
  int _selectedEventTypeIndex = 0;

  // 記錄每個項目的類型
  Map<String, String> _eventTypeMap = {};

  // 數據緩存
  final Map<String, List<Map<String, dynamic>>> _participantsCache = {};
  final Map<String, bool> _eventStatusCache = {};

  // 分頁加載設置
  final int _pageSize = 20;
  final Map<String, DocumentSnapshot?> _lastDocuments = {};
  final Map<String, bool> _hasMoreData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _eventTypes.length, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          _selectedEventTypeIndex = _tabController.index;
        });
      }
    });
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 載入比賽項目
  Future<void> _loadEvents() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // 從比賽資料中載入項目
      final competitionDoc = await _firestore
          .collection('competitions')
          .doc(widget.competitionId)
          .get();

      if (!competitionDoc.exists) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showError('找不到比賽資料');
        }
        return;
      }

      final competitionData = competitionDoc.data() as Map<String, dynamic>;

      // 嘗試從score_setup/event_types讀取已設定的項目類型
      final setupSnapshot = await _firestore
          .collection('competitions')
          .doc(widget.competitionId)
          .collection('score_setup')
          .doc('event_types')
          .get();

      if (setupSnapshot.exists) {
        final setupData = setupSnapshot.data();
        if (setupData != null && setupData.containsKey('eventTypes')) {
          _eventTypeMap = Map<String, String>.from(
              setupData['eventTypes'] as Map<dynamic, dynamic>);
          debugPrint('已從score_setup/event_types載入項目類型映射: $_eventTypeMap');
        }
      } else {
        // 如果沒有找到設定，嘗試從比賽設定中載入項目類型映射（舊版相容）
        if (competitionData.containsKey('eventTypeMappings')) {
          _eventTypeMap = Map<String, String>.from(
              competitionData['eventTypeMappings'] as Map<dynamic, dynamic>);
          debugPrint('已從Firebase載入項目類型映射: $_eventTypeMap');
        }
      }

      // 嘗試從metadata或events欄位獲取項目列表
      List<Map<String, dynamic>> events = [];

      if (competitionData.containsKey('metadata') &&
          competitionData['metadata'] != null &&
          competitionData['metadata']['events'] != null) {
        final eventsList =
            competitionData['metadata']['events'] as List<dynamic>;

        for (var event in eventsList) {
          if (event is Map<String, dynamic> && event.containsKey('name')) {
            final eventName = event['name'] as String;
            final eventType = _eventTypeMap[eventName] ?? '未分類';
            events.add({
              'id': eventName,
              'name': eventName,
              'type': eventType,
            });
          }
        }
      } else if (competitionData.containsKey('events')) {
        final eventsList = competitionData['events'];

        if (eventsList is List) {
          for (var event in eventsList) {
            String eventName;

            if (event is Map<String, dynamic> && event.containsKey('name')) {
              eventName = event['name'] as String;
            } else if (event is String) {
              eventName = event;
            } else {
              continue;
            }

            final eventType = _eventTypeMap[eventName] ?? '未分類';
            events.add({
              'id': eventName,
              'name': eventName,
              'type': eventType,
            });
          }
        }
      }

      // 檢查每個項目是否已有成績記錄
      List<Map<String, dynamic>> filteredEvents = [];
      int completedCount = 0;

      for (var event in events) {
        final eventName = event['name'] as String;

        // 檢查緩存中是否有該項目的狀態
        if (!_eventStatusCache.containsKey(eventName)) {
          final summaryRef = _firestore
              .collection('competitions')
              .doc(widget.competitionId)
              .collection('event_summaries')
              .doc(eventName.replaceAll(' ', '_').toLowerCase());

          final summaryDoc = await summaryRef.get();
          _eventStatusCache[eventName] =
              summaryDoc.exists && (summaryDoc.data()?['hasResults'] == true);
        }

        // 根據緩存決定是否顯示該項目
        if (!_eventStatusCache[eventName]!) {
          filteredEvents.add(event);
        } else {
          completedCount++;
        }
      }

      setState(() {
        _events = filteredEvents;
        _completedEventsCount = completedCount;
        _isLoading = false;
        _filterEventsByType();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('載入項目失敗: $e');
      }
      debugPrint('載入項目出錯: $e');
    }
  }

  // 根據所選類型篩選項目
  void _filterEventsByType() {
    final selectedType = _eventTypes[_selectedEventTypeIndex];
    setState(() {
      _matchedEvents = _events
          .where((event) =>
              event['type'] == selectedType || event['type'] == '未分類')
          .toList();
    });
  }

  // 顯示錯誤訊息
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 统一的参与者加载方法（选手和团队）
  Future<List<Map<String, dynamic>>> _loadParticipants(
      String eventName, String participantType, // 'athlete' 或 'relayTeam'
      {bool refresh = false}) async {
    // 缓存键
    final cacheKey = '${eventName}_$participantType';

    // 如果有缓存且不是强制刷新，直接返回缓存数据
    if (!refresh && _participantsCache.containsKey(cacheKey)) {
      return _participantsCache[cacheKey]!;
    }

    // 重置分页状态（如果刷新）
    if (refresh) {
      _lastDocuments[cacheKey] = null;
      _hasMoreData[cacheKey] = true;
    }

    try {
      final collectionName = 'competition_${widget.competitionId}';
      Query query = _firestore.collection(collectionName);

      // 根据参与者类型设置不同的查询条件
      if (participantType == 'relayTeam') {
        query = query
            .where('isRelayTeam', isEqualTo: true)
            .where('events', arrayContains: eventName);
      } else {
        // 个人选手筛选
        query = query.where('events', arrayContains: eventName);

        // 确保不包括接力队
        query = query.where('isRelayTeam', isEqualTo: false);
      }

      // 应用分页
      if (_lastDocuments[cacheKey] != null) {
        query = query.startAfterDocument(_lastDocuments[cacheKey]!);
      }

      // 限制每页大小
      query = query.limit(_pageSize);

      // 执行查询
      final snapshot = await query.get();

      // 检查是否还有更多数据
      _hasMoreData[cacheKey] = snapshot.docs.length >= _pageSize;

      // 更新最后一个文档（用于下一页）
      if (snapshot.docs.isNotEmpty) {
        _lastDocuments[cacheKey] = snapshot.docs.last;
      }

      List<Map<String, dynamic>> participants = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        if (participantType == 'relayTeam') {
          // 处理接力队数据 - 确保使用teamName作为name
          participants.add({
            'id': doc.id,
            'name': data['teamName'] ??
                '隊伍 ${participants.length + 1}', // 使用teamName作为name
            'teamName': data['teamName'] ?? '隊伍 ${participants.length + 1}',
            'school': data['school'] ?? '',
            'members': data['members'] ?? [],
            'lane': data['lane'] ?? '${participants.length + 1}',
            'athleteNumber': data['athleteNumber'] ?? '',
            'gender': data['gender'] ?? '未知',
            'ageGroup': data['ageGroup'] ?? '',
            'isRelayTeam': true,
          });
        } else {
          // 处理个人选手数据
          participants.add({
            'id': doc.id,
            'name': data['userName'] ?? '未知',
            'gender': data['gender'] ?? '未知',
            'ageGroup': data['ageGroup'] ?? '',
            'school': data['school'] ?? '',
            'athleteNumber': data['athleteNumber'] ??
                'A${participants.length + 1}'.padLeft(4, '0'),
            'isRelayTeam': false,
          });
        }
      }

      // 对数据进行排序
      if (participantType == 'relayTeam') {
        // 先按性別排序，再按學校名稱排序
        participants.sort((a, b) {
          int genderCompare = (a['gender'] ?? '').compareTo(b['gender'] ?? '');
          if (genderCompare != 0) return genderCompare;
          return (a['school'] ?? '').compareTo(b['school'] ?? '');
        });
      } else {
        // 先按性別，再按名字排序
        participants.sort((a, b) {
          int genderCompare = (a['gender'] ?? '').compareTo(b['gender'] ?? '');
          if (genderCompare != 0) return genderCompare;
          return (a['name'] ?? '').compareTo(b['name'] ?? '');
        });
      }

      // 更新缓存（如果是刷新则替换，否则追加）
      if (refresh || !_participantsCache.containsKey(cacheKey)) {
        _participantsCache[cacheKey] = participants;
      } else {
        _participantsCache[cacheKey]!.addAll(participants);
      }

      return _participantsCache[cacheKey]!;
    } catch (e) {
      debugPrint('加載參與者出錯 ($participantType): $e');
      return [];
    }
  }

  // 转到项目记录页面
  void _navigateToEventRecord(Map<String, dynamic> event) async {
    final eventType = event['type'] as String;
    final eventName = event['name'] as String;

    // 先检查是否已有结果
    try {
      // 使用缓存检查项目状态
      if (!_eventStatusCache.containsKey(eventName)) {
        final summaryRef = _firestore
            .collection('competitions')
            .doc(widget.competitionId)
            .collection('event_summaries')
            .doc(eventName.replaceAll(' ', '_').toLowerCase());

        final summaryDoc = await summaryRef.get();
        _eventStatusCache[eventName] =
            summaryDoc.exists && (summaryDoc.data()?['hasResults'] == true);
      }

      if (_eventStatusCache[eventName] == true) {
        // 如果已有結果，則檢查是否為接力賽並加載適當的結果頁面
        final finalResultRef = _firestore
            .collection('competitions')
            .doc(widget.competitionId)
            .collection('final_results')
            .doc(eventName.replaceAll(' ', '_').toLowerCase());

        final resultDoc = await finalResultRef.get();
        if (resultDoc.exists) {
          final resultData = resultDoc.data() as Map<String, dynamic>;

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EventResultScreen(
                  competitionId: widget.competitionId,
                  competitionName: widget.competitionName,
                  eventName: eventName,
                  eventResults: resultData,
                ),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('該項目已有成績記錄，但無法讀取結果數據'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        // 如果沒有結果，根據項目類型導航到相應的計時或記錄頁面
        if (mounted) {
          if (eventType == '徑賽') {
            // 導航到徑賽計時頁面
            final athletes = await _loadParticipants(eventName, 'athlete');

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TrackEventTimerScreen(
                  competitionId: widget.competitionId,
                  competitionName: widget.competitionName,
                  eventName: eventName,
                  athletes: athletes,
                ),
              ),
            );
          } else if (eventType == '田賽') {
            // 導航到田賽記錄頁面
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FieldEventRecordScreen(
                  competitionId: widget.competitionId,
                  competitionName: widget.competitionName,
                  eventName: eventName,
                  groupName: eventName, // 使用項目名稱作為組別名稱
                ),
              ),
            );
          } else if (eventType == '接力') {
            // 導航到接力賽計時頁面
            final teams = await _loadParticipants(eventName, 'relayTeam');

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RelayEventTimerScreen(
                  competitionId: widget.competitionId,
                  competitionName: widget.competitionName,
                  eventName: eventName,
                  teams: teams,
                ),
              ),
            );
          } else {
            // 未知項目類型
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('未知項目類型: $eventType，無法導航到相應頁面'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('檢查項目狀態時出錯: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${widget.competitionName} - 成績紀錄'),
          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.competitionName} - 成績紀錄',
          style: TextStyle(fontSize: isSmallScreen ? 16 : 20),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: _eventTypes.map((type) => Tab(text: type)).toList(),
          onTap: (index) {
            if (mounted) {
              setState(() {
                _selectedEventTypeIndex = index;
                _filterEventsByType();
              });
            }
          },
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'refresh') {
                _loadEvents();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'refresh',
                child: Text('重新載入項目'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadEvents();
              },
              child: Column(
                children: [
                  // 頂部資訊區
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.grey.shade50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 類型和狀態資訊
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const SizedBox(width: 8),
                                  Text(
                                    '當前顯示: ${_eventTypes[_selectedEventTypeIndex]}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 項目統計
                        Row(
                          children: [
                            Chip(
                              label: Text('待記錄: ${_events.length} 個項目'),
                              backgroundColor: Colors.blue.shade50,
                              avatar: Icon(Icons.pending_actions,
                                  size: 18, color: Colors.blue.shade700),
                            ),
                            const SizedBox(width: 8),
                            if (_completedEventsCount > 0)
                              Chip(
                                label: Text('已完成: $_completedEventsCount 個項目'),
                                backgroundColor: Colors.green.shade50,
                                avatar: Icon(Icons.check_circle,
                                    size: 18, color: Colors.green.shade700),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 項目列表
                  Expanded(
                    child: _matchedEvents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_busy,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  '沒有${_eventTypes[_selectedEventTypeIndex]}類型的項目',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _matchedEvents.length,
                            itemBuilder: (context, index) {
                              final event = _matchedEvents[index];
                              final eventName = event['name'] as String;
                              final eventType = event['type'] as String;

                              // 為不同類型選擇不同圖標
                              IconData typeIcon;
                              if (eventType == '徑賽') {
                                typeIcon = Icons.directions_run;
                              } else if (eventType == '田賽') {
                                typeIcon = Icons.flag;
                              } else if (eventType == '接力') {
                                typeIcon = Icons.people;
                              } else {
                                typeIcon = Icons.help_outline;
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: eventType == '接力'
                                        ? Colors.purple.shade200
                                        : eventType == '未分類'
                                            ? Colors.orange.shade200
                                            : Colors.transparent,
                                    width: eventType == '接力' ? 2 : 1,
                                  ),
                                ),
                                color: eventType == '接力'
                                    ? Colors.purple.shade50
                                    : null,
                                child: InkWell(
                                  onTap: () => _navigateToEventRecord(event),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: eventType == '接力'
                                                  ? Colors.purple.shade100
                                                  : eventType == '未分類'
                                                      ? Colors.orange.shade100
                                                      : Colors.blue.shade100,
                                              child: Icon(
                                                typeIcon,
                                                color: eventType == '接力'
                                                    ? Colors.purple
                                                    : eventType == '未分類'
                                                        ? Colors.orange
                                                        : Colors.blue,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    eventName,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  Text(
                                                    '類型: ${eventType == '未分類' ? '未設定類型' : eventType}',
                                                    style: TextStyle(
                                                      color: eventType == '接力'
                                                          ? Colors.purple
                                                          : eventType == '未分類'
                                                              ? Colors.orange
                                                              : Colors.green,
                                                      fontWeight: eventType ==
                                                              '接力'
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        // 底部操作區
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              onPressed: () =>
                                                  _navigateToEventRecord(event),
                                              icon: const Icon(Icons.timer),
                                              label: Text(
                                                eventType == '接力'
                                                    ? '接力計時'
                                                    : '記錄成績',
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    eventType == '接力'
                                                        ? Colors.purple
                                                        : Colors.blue,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: null,
    );
  }
}
