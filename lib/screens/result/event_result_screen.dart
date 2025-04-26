import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/colors.dart';

class EventResultScreen extends StatefulWidget {
  final String competitionId;
  final String competitionName;
  final String eventName;
  final Map<String, dynamic> eventResults;

  const EventResultScreen({
    Key? key,
    required this.competitionId,
    required this.competitionName,
    required this.eventName,
    required this.eventResults,
  }) : super(key: key);

  @override
  State<EventResultScreen> createState() => _EventResultScreenState();
}

class _EventResultScreenState extends State<EventResultScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  List<Map<String, dynamic>> _rankedAthletes = [];

  @override
  void initState() {
    super.initState();
    _processResults();
  }

  // 處理傳入的結果資料
  void _processResults() {
    try {
      if (widget.eventResults.containsKey('results')) {
        final results = widget.eventResults['results'] as List<dynamic>;
        _rankedAthletes =
            results
                .map((result) => Map<String, dynamic>.from(result as Map))
                .toList();

        // 檢查是否為接力賽（檢查第一個結果是否包含 teamName 而不是 athleteName）
        if (_rankedAthletes.isNotEmpty) {
          debugPrint("處理結果數據: ${_rankedAthletes.first}");

          // 接力賽數據適配
          for (var result in _rankedAthletes) {
            // 確保每個結果都有 athleteName 字段，用於顯示
            if (!result.containsKey('athleteName') &&
                result.containsKey('teamName')) {
              result['athleteName'] = result['teamName'];
            }

            // 確保每個結果都有 athleteNumber 字段，用於顯示
            if (!result.containsKey('athleteNumber') &&
                result.containsKey('teamId')) {
              result['athleteNumber'] = result['teamId'];
            }
          }
        }
      } else {
        debugPrint("警告: 結果數據中無 'results' 字段");
      }
    } catch (e) {
      debugPrint("處理結果數據時發生錯誤: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // 獲取螢幕尺寸，用於響應式佈局
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400 || screenSize.height < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.eventName} - 成績排名'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: '打印成績',
            onPressed: _printResults,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: '分享結果',
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('分享功能即將推出')));
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // 頂部卡片 - 比賽信息
                  Card(
                    margin: EdgeInsets.all(isSmallScreen ? 8 : 16),
                    child: Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.emoji_events,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.eventName,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 16 : 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.competitionName,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '記錄時間: ${_formatDateTime(widget.eventResults['recordedAt'])}',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 排名標題
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 8 : 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Text(
                            '排名',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 12 : 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: isSmallScreen ? 2 : 3,
                          child: Text(
                            '選手資料',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 12 : 14,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: isSmallScreen ? 1 : 2,
                          child: Text(
                            '成績',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 12 : 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 結果列表
                  Expanded(
                    child:
                        _rankedAthletes.isEmpty
                            ? const Center(
                              child: Text(
                                '沒有可顯示的成績數據',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                            : ListView.builder(
                              itemCount: _rankedAthletes.length,
                              itemBuilder: (context, index) {
                                final athlete = _rankedAthletes[index];
                                final rank = athlete['rank'] ?? (index + 1);

                                // 決定排名的背景顏色
                                Color rankColor;
                                if (rank == 1) {
                                  rankColor = Colors.amber.shade700; // 金牌
                                } else if (rank == 2) {
                                  rankColor = Colors.blueGrey.shade300; // 銀牌
                                } else if (rank == 3) {
                                  rankColor = Colors.brown.shade300; // 銅牌
                                } else {
                                  rankColor = primaryColor; // 其他排名
                                }

                                return Card(
                                  margin: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 8 : 16,
                                    vertical: 4,
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: isSmallScreen ? 4 : 8,
                                    ),
                                    child: Row(
                                      children: [
                                        // 排名
                                        Expanded(
                                          flex: 1,
                                          child: Center(
                                            child: Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                color: rankColor,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  rank.toString(),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // 選手/隊伍資訊
                                        Expanded(
                                          flex: isSmallScreen ? 2 : 3,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                athlete['athleteName']
                                                        as String? ??
                                                    athlete['teamName']
                                                        as String? ??
                                                    '未知',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize:
                                                      isSmallScreen ? 13 : 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      athlete['athleteNumber']
                                                              as String? ??
                                                          athlete['school']
                                                              as String? ??
                                                          '',
                                                      style: TextStyle(
                                                        fontSize:
                                                            isSmallScreen
                                                                ? 11
                                                                : 12,
                                                        color: Colors.grey,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        // 成績
                                        Expanded(
                                          flex: isSmallScreen ? 1 : 2,
                                          child: Center(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal:
                                                      isSmallScreen ? 8 : 16,
                                                  vertical:
                                                      isSmallScreen ? 4 : 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      rank <= 3
                                                          ? Colors
                                                              .green
                                                              .shade100
                                                          : Colors
                                                              .grey
                                                              .shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color:
                                                        rank <= 3
                                                            ? Colors
                                                                .green
                                                                .shade700
                                                            : Colors
                                                                .grey
                                                                .shade400,
                                                  ),
                                                ),
                                                child: InkWell(
                                                  onTap:
                                                      () => _showEditTimeDialog(
                                                        index,
                                                        athlete,
                                                      ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        athlete['timeFormattedWithMs'] ??
                                                            athlete['timeFormatted'] ??
                                                            '--:--:--',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize:
                                                              isSmallScreen
                                                                  ? 14
                                                                  : 16,
                                                          color:
                                                              rank <= 3
                                                                  ? Colors
                                                                      .green
                                                                      .shade800
                                                                  : Colors
                                                                      .grey
                                                                      .shade800,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width:
                                                            isSmallScreen
                                                                ? 2
                                                                : 4,
                                                      ),
                                                      Icon(
                                                        Icons.edit,
                                                        size:
                                                            isSmallScreen
                                                                ? 12
                                                                : 14,
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade600,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),

                  // 底部說明
                  Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 8 : 16),
                    child: Text(
                      '本次比賽共有${_rankedAthletes.length}名選手參加，完成記錄',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
        icon: const Icon(Icons.arrow_back),
        label: const Text('返回比賽列表'),
        backgroundColor: primaryColor,
      ),
    );
  }

  // 格式化日期時間
  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return '未記錄';

    try {
      DateTime dateTime;

      // 處理 Firestore Timestamp 類型
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      }
      // 處理 DateTime 類型
      else if (timestamp is DateTime) {
        dateTime = timestamp;
      }
      // 處理 serverTimestamp 返回的 Map 類型
      else if (timestamp is Map<String, dynamic>) {
        if (timestamp.containsKey('seconds')) {
          // 將秒轉為毫秒
          int milliseconds = (timestamp['seconds'] as int) * 1000;

          // 如果有納秒字段，添加相應的毫秒部分
          if (timestamp.containsKey('nanoseconds')) {
            milliseconds += (timestamp['nanoseconds'] as int) ~/ 1000000;
          }

          dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);
        } else {
          return '時間格式不支持';
        }
      }
      // 處理 int 類型的毫秒數
      else if (timestamp is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      // 嘗試從字符串解析
      else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      }
      // 無法識別的類型
      else {
        return '未知時間格式: ${timestamp.runtimeType}';
      }

      // 返回標準日期時間格式 YYYY/MM/DD HH:MM
      return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:'
          '${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      // 捕獲所有可能的錯誤並返回錯誤信息
      return '時間格式錯誤: $e';
    }
  }

  // 打印成績結果
  void _printResults() {
    // 顯示打印預覽對話框
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('成績單預覽'),
            content: Container(
              width: double.maxFinite,
              constraints: const BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 標題
                    Center(
                      child: Text(
                        widget.competitionName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        '${widget.eventName} - 最終成績',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        '記錄時間: ${_formatDateTime(widget.eventResults['recordedAt'])}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const Divider(),

                    // 成績表格
                    Table(
                      border: TableBorder.all(),
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      children: [
                        // 表頭
                        const TableRow(
                          decoration: BoxDecoration(color: Color(0xFFE0E0E0)),
                          children: [
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                '排名',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                '選手',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                '成績',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),

                        // 選手成績
                        ..._rankedAthletes.map((athlete) {
                          final rank = athlete['rank'] ?? 0;
                          return TableRow(
                            decoration: BoxDecoration(
                              color:
                                  rank <= 3
                                      ? const Color(0xFFF5F5F5)
                                      : Colors.white,
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  '$rank',
                                  style: TextStyle(
                                    fontWeight:
                                        rank <= 3
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  '${athlete['athleteName'] ?? athlete['teamName'] ?? '未知'}\n'
                                  '${athlete.containsKey('athleteNumber')
                                      ? '編號: ${athlete['athleteNumber']}'
                                      : athlete.containsKey('school')
                                      ? '學校: ${athlete['school']}'
                                      : ''}',
                                  style: TextStyle(
                                    fontWeight:
                                        rank <= 3
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  athlete['timeFormattedWithMs'] ??
                                      athlete['timeFormatted'] ??
                                      '--:--:--',
                                  style: TextStyle(
                                    fontWeight:
                                        rank <= 3
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        '--- 學校體育組 ---',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('關閉'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('成績單已發送到列印隊列'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.print),
                label: const Text('打印'),
              ),
            ],
          ),
    );
  }

  // 顯示編輯時間對話框
  void _showEditTimeDialog(int index, Map<String, dynamic> athlete) {
    // 解析當前時間
    int minutes = 0;
    int seconds = 0;
    int centiseconds = 0;

    if (athlete.containsKey('time') && athlete['time'] is int) {
      final time = athlete['time'] as int;
      minutes = (time ~/ (100 * 60)) % 60;
      seconds = (time ~/ 100) % 60;
      centiseconds = time % 100;
    }

    // 創建控制器
    final minutesController = TextEditingController(text: minutes.toString());
    final secondsController = TextEditingController(text: seconds.toString());
    final centisecondsController = TextEditingController(
      text: centiseconds.toString(),
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('編輯 ${athlete['athleteName'] ?? '未知選手'} 的成績'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('請輸入正確的時間：'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // 分鐘
                    Expanded(
                      child: TextField(
                        controller: minutesController,
                        decoration: const InputDecoration(
                          labelText: '分鐘',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 秒
                    Expanded(
                      child: TextField(
                        controller: secondsController,
                        decoration: const InputDecoration(
                          labelText: '秒',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 毫秒
                    Expanded(
                      child: TextField(
                        controller: centisecondsController,
                        decoration: const InputDecoration(
                          labelText: '毫秒',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  // 解析時間數值
                  final newMinutes = int.tryParse(minutesController.text) ?? 0;
                  final newSeconds = int.tryParse(secondsController.text) ?? 0;
                  final newCentiseconds =
                      int.tryParse(centisecondsController.text) ?? 0;

                  // 計算新的時間總量
                  final newTime =
                      (newMinutes * 60 * 100) +
                      (newSeconds * 100) +
                      newCentiseconds;

                  // 更新選手時間
                  setState(() {
                    _rankedAthletes[index]['time'] = newTime;
                    _rankedAthletes[index]['timeFormatted'] =
                        '$newMinutes:$newSeconds';
                    _rankedAthletes[index]['timeFormattedWithMs'] =
                        '$newMinutes:${newSeconds.toString().padLeft(2, '0')}.${newCentiseconds.toString().padLeft(2, '0')}';
                  });

                  // 根據新時間重新排序
                  _sortAndRankAthletes();

                  // 顯示提示
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('成績已更新'),
                      backgroundColor: Colors.blue,
                    ),
                  );

                  // 更新Firebase數據
                  _updateResultInFirestore();
                },
                child: const Text('保存'),
              ),
            ],
          ),
    );
  }

  // 重新排序和排名選手
  void _sortAndRankAthletes() {
    // 按時間排序
    _rankedAthletes.sort((a, b) {
      final timeA = a['time'] as int? ?? 0;
      final timeB = b['time'] as int? ?? 0;
      return timeA.compareTo(timeB);
    });

    // 更新排名
    for (int i = 0; i < _rankedAthletes.length; i++) {
      _rankedAthletes[i]['rank'] = i + 1;
    }
  }

  // 更新Firestore數據
  Future<void> _updateResultInFirestore() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 更新結果文檔
      await _firestore
          .collection('competitions')
          .doc(widget.competitionId)
          .collection('final_results')
          .doc(widget.eventName.replaceAll(' ', '_').toLowerCase())
          .update({
            'results': _rankedAthletes,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      setState(() {
        _isLoading = false;
      });

      // 顯示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('成績更新已同步到雲端'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // 顯示錯誤提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失敗: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
