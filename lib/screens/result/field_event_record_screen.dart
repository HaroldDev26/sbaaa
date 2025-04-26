import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FieldEventRecordScreen extends StatefulWidget {
  final String competitionId;
  final String competitionName;
  final String eventName;
  final String groupName; // 組別名稱，例如 "第13-15組"

  const FieldEventRecordScreen({
    Key? key,
    required this.competitionId,
    required this.competitionName,
    required this.eventName,
    required this.groupName,
  }) : super(key: key);

  @override
  State<FieldEventRecordScreen> createState() => _FieldEventRecordScreenState();
}

class _FieldEventRecordScreenState extends State<FieldEventRecordScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<Map<String, dynamic>> _athletes = [];
  List<Map<String, dynamic>> _filteredAthletes = [];

  // 儲存每位選手三次嘗試的成績
  final Map<String, List<Map<String, dynamic>>> _attemptResults = {};
  // 犯規標記
  static const String FOUL_MARKER = "FOUL";

  // 添加到類屬性
  final Map<String, List<TextEditingController>> _attemptControllers = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterAthletes);
    _loadAthletes();
    _loadSavedResults();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _attemptControllers.forEach((_, controllers) {
      for (var controller in controllers) {
        controller.dispose();
      }
    });
    super.dispose();
  }

  // 載入參賽選手
  Future<void> _loadAthletes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 從比賽的報名名單中載入選手資料
      final collectionName = 'competition_${widget.competitionId}';
      final snapshot = await _firestore
          .collection(collectionName)
          .get();

      List<Map<String, dynamic>> athletes = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final events = data['events'] as List<dynamic>? ?? [];

        // 篩選參加指定項目的選手
        if (events.contains(widget.eventName)) {
          // 檢查選手是否已檢錄
          final isCheckedIn = data['checkedIn'] == true;

          athletes.add({
            'id': doc.id,
            'name': data['userName'] ?? '未知',
            'athleteNumber': data['athleteNumber'] ??
                'A${athletes.length + 1}'.padLeft(4, '0'),
            'checkedIn': isCheckedIn,
          });

          // 初始化選手的三次嘗試成績
          _attemptResults[doc.id] = [
            {'value': null, 'isFoul': false},
            {'value': null, 'isFoul': false},
            {'value': null, 'isFoul': false}
          ];
        }
      }

      // 排序：已檢錄的排前面，然後按選手號碼排序
      athletes.sort((a, b) {
        if (a['checkedIn'] != b['checkedIn']) {
          return a['checkedIn'] ? -1 : 1;
        }
        return a['athleteNumber'].compareTo(b['athleteNumber']);
      });

      // 載入已儲存的成績（如果有）
      await _loadSavedResults();

      setState(() {
        _athletes = athletes;
        _filteredAthletes = athletes;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('載入選手資料時發生錯誤: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 載入已儲存的成績
  Future<void> _loadSavedResults() async {
    try {
      // 檢查是否有已儲存的成績記錄
      final docRef = _firestore
          .collection('competitions')
          .doc(widget.competitionId)
          .collection('field_results')
          .doc('${widget.eventName}_${widget.groupName}');

      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        if (data.containsKey('results')) {
          final results = data['results'] as Map<String, dynamic>;

          results.forEach((athleteId, attempts) {
            if (attempts is List) {
              List<Map<String, dynamic>> attemptList = [];
              for (var attempt in attempts) {
                if (attempt is Map) {
                  // 新格式資料
                  attemptList.add({
                    'value': attempt['value'] != null
                        ? double.tryParse(attempt['value'].toString())
                        : null,
                    'isFoul': attempt['isFoul'] == true
                  });
                } else if (attempt == FOUL_MARKER) {
                  // 舊格式犯規標記
                  attemptList.add({'value': null, 'isFoul': true});
                } else {
                  // 舊格式正常成績
                  attemptList.add({
                    'value': attempt != null
                        ? double.tryParse(attempt.toString())
                        : null,
                    'isFoul': false
                  });
                }
              }
              _attemptResults[athleteId] = attemptList;
            }
          });
        }
      }
    } catch (e) {
      print('載入已儲存成績時發生錯誤: $e');
    }
  }

  // 過濾選手資料
  void _filterAthletes() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        _filteredAthletes = _athletes;
      } else {
        // 自行實現線性搜索
        _filteredAthletes = [];

        for (final athlete in _athletes) {
          final name = athlete['name'].toString().toLowerCase();
          final number = athlete['athleteNumber'].toString().toLowerCase();

          if (name.contains(query) || number.contains(query)) {
            _filteredAthletes.add(athlete);
          }
        }
      }
    });

    debugPrint('搜索關鍵字: "$query", 找到 ${_filteredAthletes.length} 位符合的選手');
  }

  // 更新選手檢錄狀態
  Future<void> _toggleCheckedInStatus(
      String athleteId, bool currentStatus) async {
    try {
      // 更新 Firestore 中的檢錄狀態
      final collectionName = 'competition_${widget.competitionId}';
      await _firestore
          .collection(collectionName)
          .doc(athleteId)
          .update({'checkedIn': !currentStatus});

      // 更新本地狀態
      setState(() {
        final index = _athletes.indexWhere((a) => a['id'] == athleteId);
        if (index != -1) {
          _athletes[index]['checkedIn'] = !currentStatus;
        }

        final filteredIndex =
            _filteredAthletes.indexWhere((a) => a['id'] == athleteId);
        if (filteredIndex != -1) {
          _filteredAthletes[filteredIndex]['checkedIn'] = !currentStatus;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('選手狀態已更新'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('更新選手狀態時發生錯誤: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 更新選手成績
  void _updateAttemptResult(String athleteId, int attemptIndex,
      {double? value, bool isFoul = false}) {
    setState(() {
      if (_attemptResults.containsKey(athleteId)) {
        _attemptResults[athleteId]![attemptIndex] = {
          'value': isFoul ? null : value,
          'isFoul': isFoul
        };
      } else {
        _attemptResults[athleteId] = [
          {'value': null, 'isFoul': false},
          {'value': null, 'isFoul': false},
          {'value': null, 'isFoul': false}
        ];
        _attemptResults[athleteId]![attemptIndex] = {
          'value': isFoul ? null : value,
          'isFoul': isFoul
        };
      }
    });
  }

  // 修改保存所有成績方法
  Future<void> _saveAllResults() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 準備儲存到 Firestore 的資料格式
      Map<String, List<Map<String, dynamic>>> resultsToSave = {};

      _attemptResults.forEach((athleteId, attempts) {
        resultsToSave[athleteId] = attempts;
      });

      // 儲存到 Firestore
      await _firestore
          .collection('competitions')
          .doc(widget.competitionId)
          .collection('field_results')
          .doc('${widget.eventName}_${widget.groupName}')
          .set({
        'eventName': widget.eventName,
        'groupName': widget.groupName,
        'competitionId': widget.competitionId,
        'competitionName': widget.competitionName,
        'results': resultsToSave,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 更新比賽項目摘要
      await _firestore
          .collection('competitions')
          .doc(widget.competitionId)
          .collection('event_summaries')
          .doc(widget.eventName.replaceAll(' ', '_').toLowerCase())
          .set({
        'eventName': widget.eventName,
        'eventType': '田賽',
        'hasResults': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('所有成績已成功儲存'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('儲存成績時發生錯誤: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 獲取最佳成績
  double? _getBestAttempt(String athleteId) {
    if (!_attemptResults.containsKey(athleteId)) return null;

    double? best;
    for (var attempt in _attemptResults[athleteId]!) {
      if (!attempt['isFoul'] && attempt['value'] != null) {
        if (best == null || attempt['value'] > best) {
          best = attempt['value'];
        }
      }
    }
    return best;
  }

  // 生成排名
  List<Map<String, dynamic>> _getRankedAthletes() {
    // 創建排名列表
    List<Map<String, dynamic>> rankedAthletes = [];

    // 為每個選手找到最佳成績
    for (var athlete in _athletes) {
      final athleteId = athlete['id'] as String;
      final bestAttempt = _getBestAttempt(athleteId);

      // 只添加有有效成績的選手
      if (bestAttempt != null) {
        rankedAthletes.add({
          ...athlete,
          'bestResult': bestAttempt,
          'attempts': _attemptResults[athleteId],
        });
      }
    }

    // 根據最佳成績排序 (對於田賽項目，通常更大的數字表示更好的成績)
    rankedAthletes.sort((a, b) =>
        (b['bestResult'] as double).compareTo(a['bestResult'] as double));

    // 添加排名
    for (int i = 0; i < rankedAthletes.length; i++) {
      // 處理平局情況
      if (i > 0 &&
          (rankedAthletes[i]['bestResult'] as double) ==
              (rankedAthletes[i - 1]['bestResult'] as double)) {
        // 平局，使用相同排名
        rankedAthletes[i]['rank'] = rankedAthletes[i - 1]['rank'];
      } else {
        // 不是平局，使用當前索引+1作為排名
        rankedAthletes[i]['rank'] = i + 1;
      }
    }

    return rankedAthletes;
  }

  // 產生最終結果頁面
  Future<void> _generateResults() async {
    // 取得排名後的選手名單
    final rankedAthletes = _getRankedAthletes();

    // 如果沒有足夠的選手有成績，顯示提示
    if (rankedAthletes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('沒有選手有有效成績記錄'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // 顯示確認對話框
    if (!mounted) return;

    bool shouldProceed = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('確認保存成績'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('確定保存 ${widget.eventName} 的最終成績排名嗎？'),
                  const SizedBox(height: 16),
                  Text('共 ${rankedAthletes.length} 名選手有完成記錄：'),
                  const SizedBox(height: 8),
                  ...rankedAthletes.take(3).map((athlete) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${athlete['rank']}. ${athlete['name'] ?? '未知選手'} - ${athlete['bestResult'].toStringAsFixed(2)}m',
                          style: TextStyle(
                            fontWeight: athlete['rank'] == 1
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: athlete['rank'] == 1
                                ? Colors.blue
                                : Colors.black87,
                          ),
                        ),
                      )),
                  if (rankedAthletes.length > 3)
                    Text('... 和其他 ${rankedAthletes.length - 3} 名選手'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('確認保存'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldProceed) return;
    if (!mounted) return;

    // 顯示加載指示器
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );
    }

    try {
      // 儲存最終排名到Firestore
      final batch = _firestore.batch();

      // 結果文檔參考
      final finalResultRef = _firestore
          .collection('competitions')
          .doc(widget.competitionId)
          .collection('final_results')
          .doc(widget.eventName.replaceAll(' ', '_').toLowerCase());

      // 時間戳
      final now = DateTime.now();

      // 格式化結果數據
      final List<Map<String, dynamic>> formattedResults =
          rankedAthletes.map((athlete) {
        // 確保數據格式正確
        return {
          'athleteId': athlete['id'] ?? '',
          'athleteName': athlete['name'] ?? '未知選手',
          'athleteNumber': athlete['athleteNumber'] ?? '',
          'bestResult': athlete['bestResult'],
          'attempts': athlete['attempts'],
          'rank': athlete['rank'] ?? 0,
        };
      }).toList();

      // 最終結果數據
      final finalResultData = {
        'eventName': widget.eventName,
        'eventType': '田賽',
        'competitionId': widget.competitionId,
        'competitionName': widget.competitionName,
        'results': formattedResults,
        'recordedAt': now,
      };

      // 加入批次
      batch.set(finalResultRef, finalResultData);

      // 執行批次操作
      await batch.commit();

      // 關閉加載指示器
      if (mounted) {
        Navigator.pop(context);
      }

      // 顯示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('成績排名已成功保存'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // 應該跳轉到結果展示頁面，但這裡暫時不實現
      // 可以後續添加類似徑賽的結果頁面
    } catch (e) {
      // 關閉加載指示器
      if (mounted) {
        Navigator.pop(context);
      }

      // 顯示錯誤訊息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('生成最終結果失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 根據屏幕大小調整 UI

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.eventName} - 成績紀錄'),
            Text(
              '${widget.competitionName} - ${widget.groupName}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // 添加保存和生成排名功能
          PopupMenuButton<String>(
            tooltip: '操作選單',
            onSelected: (value) {
              if (value == 'save') {
                _saveAllResults();
              } else if (value == 'ranking') {
                _generateResults();
              } else if (value == 'reload') {
                _loadAthletes();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.save),
                    SizedBox(width: 8),
                    Text('儲存成績'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'ranking',
                child: Row(
                  children: [
                    Icon(Icons.emoji_events),
                    SizedBox(width: 8),
                    Text('生成排名'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'reload',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('重新載入'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 搜尋欄
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜尋運動員姓名或編號...',
                      prefixIcon: const Icon(Icons.search, color: Colors.blue),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _filterAthletes();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            BorderSide(color: Colors.blue.shade200, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            BorderSide(color: Colors.blue.shade200, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            BorderSide(color: Colors.blue.shade400, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.blue.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                    ),
                  ),
                ),

                // 排名結果摘要面板
                if (_getRankedAthletes().isNotEmpty)
                  Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '當前排名',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '共 ${_getRankedAthletes().length} 名選手有成績',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ..._getRankedAthletes()
                              .take(3)
                              .map((athlete) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: athlete['rank'] == 1
                                                ? Colors.amber
                                                : athlete['rank'] == 2
                                                    ? Colors.grey.shade300
                                                    : Colors.brown.shade300,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${athlete['rank']}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            athlete['name'] as String,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${athlete['bestResult'].toStringAsFixed(2)}m',
                                          style: TextStyle(
                                            color: Colors.green.shade800,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                          if (_getRankedAthletes().length > 3)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _generateResults,
                                child: const Text('查看完整排名'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                // 選手列表
                Expanded(
                  child: _filteredAthletes.isEmpty
                      ? const Center(child: Text('沒有找到符合條件的選手'))
                      : ListView.builder(
                          itemCount: _filteredAthletes.length,
                          itemBuilder: (context, index) {
                            final athlete = _filteredAthletes[index];
                            final athleteId = athlete['id'] as String;
                            final attempts = _attemptResults[athleteId] ??
                                [
                                  {'value': null, 'isFoul': false},
                                  {'value': null, 'isFoul': false},
                                  {'value': null, 'isFoul': false}
                                ];

                            return Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: athlete['checkedIn'] as bool
                                      ? Colors.green.shade200
                                      : Colors.grey.shade300,
                                  width: 1.5,
                                ),
                              ),
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Column(
                                children: [
                                  // 選手信息區頭部
                                  Container(
                                    decoration: BoxDecoration(
                                      color: athlete['checkedIn'] as bool
                                          ? Colors.green.shade50
                                          : Colors.grey.shade50,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        topRight: Radius.circular(12),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        // 選手名稱與號碼
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                athlete['name'] as String,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade200,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: Text(
                                                      athlete['athleteNumber']
                                                          as String,
                                                      style: TextStyle(
                                                        color: Colors
                                                            .grey.shade700,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  GestureDetector(
                                                    onTap: () =>
                                                        _toggleCheckedInStatus(
                                                      athleteId,
                                                      athlete['checkedIn']
                                                          as bool,
                                                    ),
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            athlete['checkedIn']
                                                                    as bool
                                                                ? Colors.green
                                                                    .shade100
                                                                : Colors.orange
                                                                    .shade100,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                      ),
                                                      child: Text(
                                                        athlete['checkedIn']
                                                                as bool
                                                            ? '已檢錄'
                                                            : '未到',
                                                        style: TextStyle(
                                                          color:
                                                              athlete['checkedIn']
                                                                      as bool
                                                                  ? Colors.green
                                                                      .shade700
                                                                  : Colors
                                                                      .orange
                                                                      .shade700,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // 最佳成績
                                        if (_getBestAttempt(athleteId) != null)
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: Colors.green.shade300),
                                            ),
                                            child: Column(
                                              children: [
                                                const Text(
                                                  '最佳成績',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                                Text(
                                                  '${_getBestAttempt(athleteId)!.toStringAsFixed(2)}m',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color:
                                                        Colors.green.shade800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // 成績輸入區
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [
                                        // 三次嘗試記錄
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text('第一次',
                                                      style: TextStyle(
                                                          fontSize: 14)),
                                                  const SizedBox(height: 4),
                                                  _buildAttemptInput(0,
                                                      athleteId, attempts[0]),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text('第二次',
                                                      style: TextStyle(
                                                          fontSize: 14)),
                                                  const SizedBox(height: 4),
                                                  _buildAttemptInput(1,
                                                      athleteId, attempts[1]),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text('第三次',
                                                      style: TextStyle(
                                                          fontSize: 14)),
                                                  const SizedBox(height: 4),
                                                  _buildAttemptInput(2,
                                                      athleteId, attempts[2]),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'save',
            onPressed: _saveAllResults,
            tooltip: '儲存成績',
            child: const Icon(Icons.save),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'ranking',
            onPressed: _generateResults,
            tooltip: '生成排名',
            backgroundColor: Colors.amber,
            child: const Icon(Icons.emoji_events),
          ),
        ],
      ),
    );
  }

  // 構建嘗試輸入框
  Widget _buildAttemptInput(
      int attemptIndex, String athleteId, Map<String, dynamic> attemptData) {
    // 確保控制器存在
    if (!_attemptControllers.containsKey(athleteId)) {
      _attemptControllers[athleteId] =
          List.generate(3, (_) => TextEditingController());
    }

    // 更新控制器文本
    final bool isFoul = attemptData['isFoul'] == true;
    final double? value = attemptData['value'];

    if (!isFoul &&
        value != null &&
        _attemptControllers[athleteId]![attemptIndex].text.isEmpty) {
      _attemptControllers[athleteId]![attemptIndex].text = value.toString();
    } else if (isFoul) {
      _attemptControllers[athleteId]![attemptIndex].text = "";
    }

    // 設置樣式
    final bool hasValue = !isFoul && value != null;
    final Color borderColor = isFoul
        ? Colors.red.shade400
        : (hasValue ? Colors.green.shade400 : Colors.grey.shade300);
    final Color fillColor = isFoul
        ? Colors.red.shade50
        : (hasValue ? Colors.green.shade50 : Colors.grey.shade50);

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            enabled: !isFoul, // 犯規時禁用輸入框
            style: TextStyle(
              fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
              color: hasValue ? Colors.green.shade800 : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: isFoul ? 'X' : '--',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              border: InputBorder.none,
              filled: true,
              fillColor: fillColor,
            ),
            controller: _attemptControllers[athleteId]![attemptIndex],
            onChanged: (value) {
              double? parsedValue;
              if (value.isNotEmpty) {
                parsedValue = double.tryParse(value);

                if (parsedValue != null) {
                  if (parsedValue < 0 || parsedValue > 300) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('請輸入有效範圍內的數值 (0-300)'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    // 重置為之前的值
                    _attemptControllers[athleteId]![attemptIndex].text =
                        attemptData['value']?.toString() ?? '';
                    return;
                  }
                }
              }
              _updateAttemptResult(athleteId, attemptIndex,
                  value: parsedValue, isFoul: false);
            },
          ),
        ),
        const SizedBox(height: 4),
        // 犯規按鈕
        InkWell(
          onTap: () {
            final newFoulState = !isFoul;
            _updateAttemptResult(athleteId, attemptIndex, isFoul: newFoulState);
            // 清空輸入框
            if (newFoulState) {
              _attemptControllers[athleteId]![attemptIndex].text = '';
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isFoul ? Colors.red.shade400 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isFoul ? "取消犯規" : "犯規",
              style: TextStyle(
                fontSize: 12,
                color: isFoul ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
