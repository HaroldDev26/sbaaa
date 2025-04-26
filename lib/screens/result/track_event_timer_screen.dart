import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/colors.dart';
import 'event_result_screen.dart';

class TrackEventTimerScreen extends StatefulWidget {
  final String competitionId;
  final String competitionName;
  final String eventName;
  final List<Map<String, dynamic>> athletes;

  const TrackEventTimerScreen({
    Key? key,
    required this.competitionId,
    required this.competitionName,
    required this.eventName,
    required this.athletes,
  }) : super(key: key);

  @override
  State<TrackEventTimerScreen> createState() => _TrackEventTimerScreenState();
}

class _TrackEventTimerScreenState extends State<TrackEventTimerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 計時器相關變數
  bool _isRunning = false;
  bool _isReset = true;
  DateTime? _startTime;
  DateTime? _currentTime;
  Duration _elapsedDuration = Duration.zero;
  Timer? _updateTimer;

  // 選手成績記錄
  final Map<String, int> _athleteTimes = {};

  // 新增：檢錄狀態
  final Map<String, bool> _checkedInStatus = {};

  // 計時狀態
  String _timerStatus = '準備';

  @override
  void initState() {
    super.initState();
    _setupAthletes();
    _loadCheckInStatus(); // 新增：加載檢錄狀態
  }

  @override
  void dispose() {
    debugPrint('TrackEventTimerScreen 即將銷毀');
    _updateTimer?.cancel();
    super.dispose();
  }

  // 初始化選手資料
  void _setupAthletes() {
    for (var athlete in widget.athletes) {
      _athleteTimes[athlete['id'] as String] = 0;
      _checkedInStatus[athlete['id'] as String] = false; // 初始化檢錄狀態
    }
  }

  // 新增：加載選手檢錄狀態
  Future<void> _loadCheckInStatus() async {
    try {
      final collectionName = 'competition_${widget.competitionId}';
      for (var athlete in widget.athletes) {
        final athleteId = athlete['id'] as String;
        final doc =
            await _firestore.collection(collectionName).doc(athleteId).get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _checkedInStatus[athleteId] = data['checkedIn'] == true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('載入檢錄狀態失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 新增：更新檢錄狀態
  Future<void> _toggleCheckedInStatus(
      String athleteId, bool currentStatus) async {
    final newStatus = !currentStatus;

    try {
      // 更新 Firestore
      final collectionName = 'competition_${widget.competitionId}';
      await _firestore.collection(collectionName).doc(athleteId).update({
        'checkedIn': newStatus,
      });

      // 更新本地狀態
      setState(() {
        _checkedInStatus[athleteId] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('選手${newStatus ? '已檢錄' : '取消檢錄'}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('更新檢錄狀態失敗: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 開始計時
  void _startTimer() {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _isReset = false;
      _timerStatus = '計時中';

      // 如果是從暫停恢復，保留之前的時間差
      _startTime ??= DateTime.now().subtract(_elapsedDuration);
    });

    // 使用Timer更新當前時間，實現計時功能
    _updateTimer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
          if (_startTime != null) {
            _elapsedDuration = _currentTime!.difference(_startTime!);
          }
        });
      }
    });
  }

  // 停止計時
  void _stopTimer() {
    if (!_isRunning) return;

    _updateTimer?.cancel();
    _updateTimer = null;

    setState(() {
      _isRunning = false;
      _timerStatus = '已停止';
      _currentTime = DateTime.now();
      _elapsedDuration = _startTime != null
          ? _currentTime!.difference(_startTime!)
          : _elapsedDuration;
    });
  }

  // 重置計時器
  void _resetTimer() {
    _updateTimer?.cancel();
    _updateTimer = null;

    setState(() {
      _isRunning = false;
      _isReset = true;
      _timerStatus = '準備';
      _startTime = null;
      _currentTime = null;
      _elapsedDuration = Duration.zero;

      // 重置選手成績
      for (var athlete in widget.athletes) {
        _athleteTimes[athlete['id'] as String] = 0;
      }
    });
  }

  // 獲取當前毫秒數
  int _getCurrentCentiseconds() {
    if (_isReset) return 0;
    final totalMilliseconds = _elapsedDuration.inMilliseconds;
    return (totalMilliseconds / 10).round(); // 換算為百分之一秒（更穩定的計算方式）
  }

  // 記錄選手成績
  void _recordAthleteTime(String athleteId) {
    if (_isReset) return; // 防止在重置狀態下記錄時間

    final currentCentiseconds = _getCurrentCentiseconds();

    // 確保時間大於0
    if (currentCentiseconds > 0) {
      setState(() {
        _athleteTimes[athleteId] = currentCentiseconds;
      });

      // 儲存到Firestore
      _saveAthleteResult(athleteId, currentCentiseconds);
    } else {
      // 如果時間為0，顯示警告
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('無法記錄：計時器未啟動或已重置'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // 儲存選手成績到Firestore
  Future<void> _saveAthleteResult(
      String athleteId, int timeInCentiseconds) async {
    try {
      // 使用批次操作確保數據一致性
      final batch = _firestore.batch();

      // 結果文檔參考
      final resultRef = _firestore
          .collection('competitions')
          .doc(widget.competitionId)
          .collection('results')
          .doc();

      // 時間戳
      final now = DateTime.now();

      // 選手資料
      final athlete = widget.athletes.firstWhere((a) => a['id'] == athleteId,
          orElse: () => {'id': athleteId, 'name': '未知選手', 'athleteNumber': ''});

      // 結果數據
      final resultData = {
        'athleteId': athleteId,
        'athleteName': athlete['name'] ?? '未知選手',
        'athleteNumber': athlete['athleteNumber'] ?? '',
        'time': timeInCentiseconds,
        'timeFormatted': _formatTime(timeInCentiseconds),
        'timeFormattedWithMs': _formatTimeWithMs(timeInCentiseconds),
        'eventName': widget.eventName,
        'eventType': '徑賽',
        'competitionId': widget.competitionId,
        'competitionName': widget.competitionName,
        'recordedAt': now,
      };

      // 加入批次
      batch.set(resultRef, resultData);

      // 更新賽事記錄摘要
      final summaryRef = _firestore
          .collection('competitions')
          .doc(widget.competitionId)
          .collection('event_summaries')
          .doc(widget.eventName.replaceAll(' ', '_').toLowerCase());

      batch.set(
          summaryRef,
          {
            'eventName': widget.eventName,
            'eventType': '徑賽',
            'lastUpdated': now,
            'competitionId': widget.competitionId,
            'competitionName': widget.competitionName,
            'hasResults': true,
          },
          SetOptions(merge: true));

      // 執行批次操作
      await batch.commit();

      // 顯示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已記錄 ${athlete['name']} 的成績'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存成績失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 產生排名
  List<Map<String, dynamic>> _getRankedAthletes() {
    try {
      // 先過濾出有成績的選手
      final athletesWithTimes = widget.athletes
          .where((athlete) =>
              athlete['id'] != null &&
              _athleteTimes.containsKey(athlete['id'] as String) &&
              _athleteTimes[athlete['id'] as String]! > 0)
          .map((athlete) => {
                ...athlete,
                'time': _athleteTimes[athlete['id'] as String] ?? 0,
              })
          .toList();

      // 按照時間排序
      athletesWithTimes
          .sort((a, b) => (a['time'] as int).compareTo(b['time'] as int));

      // 添加排名
      for (int i = 0; i < athletesWithTimes.length; i++) {
        athletesWithTimes[i]['rank'] = i + 1;
      }

      return athletesWithTimes;
    } catch (e) {
      debugPrint('生成排名時發生錯誤: $e');
      return [];
    }
  }

  // 產生最終結果頁面
  Future<void> _generateResults() async {
    // 取得排名後的選手名單
    final rankedAthletes = _getRankedAthletes();

    // 如果沒有足夠的選手有成績，顯示提示
    if (rankedAthletes.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('請至少記錄兩名選手的成績以產生排名'),
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
                          '${athlete['rank']}. ${athlete['name'] ?? '未知選手'} - ${_formatTimeWithMs(athlete['time'] as int)}',
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

      // 確保數據格式正確
      final List<Map<String, dynamic>> formattedResults =
          rankedAthletes.map((athlete) {
        // 確保時間為整數
        dynamic time = athlete['time'];
        if (time is! int) {
          time = 0; // 默認值
        }

        return {
          'athleteId': athlete['id'] ?? '',
          'athleteName': athlete['name'] ?? '未知選手',
          'athleteNumber': athlete['athleteNumber'] ?? '',
          'time': time,
          'timeFormatted': _formatTime(time),
          'timeFormattedWithMs': _formatTimeWithMs(time),
          'rank': athlete['rank'] ?? 0,
        };
      }).toList();

      // 最終結果數據
      final finalResultData = {
        'eventName': widget.eventName,
        'eventType': '徑賽',
        'competitionId': widget.competitionId,
        'competitionName': widget.competitionName,
        'results': formattedResults,
        'recordedAt': now, // 使用標準DateTime對象
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

      // 跳轉到成績排名頁面
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventResultScreen(
              competitionId: widget.competitionId,
              competitionName: widget.competitionName,
              eventName: widget.eventName,
              eventResults: finalResultData,
            ),
          ),
        );
      }
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

  // 格式化時間顯示 (標準格式)
  String _formatTime(int centiseconds) {
    try {
      // 安全處理時間
      if (centiseconds < 0) centiseconds = 0;

      final minutes = (centiseconds ~/ (100 * 60)).toString().padLeft(2, '0');
      final seconds = ((centiseconds ~/ 100) % 60).toString().padLeft(2, '0');
      final remainingCentiseconds =
          (centiseconds % 100).toString().padLeft(2, '0');

      // 返回標準格式 MM:SS.CC
      return '$minutes:$seconds.$remainingCentiseconds';
    } catch (e) {
      // Debugging
      debugPrint('格式化時間錯誤: $e');
      // 出錯時返回默認值
      return '00:00.00';
    }
  }

  // 完整格式化時間顯示（包含毫秒）
  String _formatTimeWithMs(int centiseconds) {
    try {
      // 安全處理時間
      if (centiseconds < 0) centiseconds = 0;

      final minutes =
          ((centiseconds ~/ (100 * 60)) % 60).toString().padLeft(2, '0');
      final seconds = ((centiseconds ~/ 100) % 60).toString().padLeft(2, '0');
      final remainingCentiseconds =
          (centiseconds % 100).toString().padLeft(2, '0');

      // 返回標準格式 MM:SS.CC
      return '$minutes:$seconds.$remainingCentiseconds';
    } catch (e) {
      // Debugging
      debugPrint('格式化帶毫秒的時間錯誤: $e，輸入值: $centiseconds');
      // 出錯時返回默認值
      return '00:00.00';
    }
  }

  // 格式化Duration為計時器顯示
  String _formatDuration(Duration duration) {
    try {
      // 安全處理持續時間
      if (duration.isNegative) duration = Duration.zero;

      final minutes =
          duration.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds =
          duration.inSeconds.remainder(60).toString().padLeft(2, '0');
      final milliseconds = (duration.inMilliseconds.remainder(1000) ~/ 10)
          .toString()
          .padLeft(2, '0');

      // 返回標準格式 MM:SS.CC
      return '$minutes:$seconds.$milliseconds';
    } catch (e) {
      // 出錯時返回默認值
      return '00:00.00';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.athletes.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${widget.eventName} - 計時'),
        ),
        body: const Center(
          child: Text('沒有選手參加此項目', style: TextStyle(fontSize: 18)),
        ),
      );
    }

    // 獲取螢幕尺寸，用於響應式佈局
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400 || screenSize.height < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.eventName} - 計時',
          style: TextStyle(
            fontSize: isSmallScreen ? 18 : 20,
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: _generateResults,
            icon: const Icon(Icons.save_alt, size: 18),
            label: Text(
              '成績保存',
              style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 8 : 12,
                vertical: isSmallScreen ? 4 : 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 計時器顯示區
          Container(
            padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 16),
            color: Colors.indigo.shade900,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 狀態顯示
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: _isRunning
                        ? Colors.green.withOpacity(0.3)
                        : _isReset
                            ? Colors.grey.withOpacity(0.3)
                            : Colors.red.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _timerStatus,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 計時顯示
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isRunning
                          ? Colors.green.withOpacity(0.5)
                          : Colors.white.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: _isReset
                      ? const Text(
                          "00:00.00",
                          style: TextStyle(
                            fontSize: 48,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        )
                      : Text(
                          _formatDuration(_elapsedDuration),
                          style: TextStyle(
                            fontSize: isSmallScreen ? 42 : 48,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                ),
              ],
            ),
          ),

          // 操作按鈕列
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  label: '開始',
                  icon: Icons.play_arrow,
                  color: Colors.green.shade600,
                  onPressed: _isRunning ? null : _startTimer,
                ),
                _buildActionButton(
                  label: '停止',
                  icon: Icons.stop,
                  color: Colors.red.shade600,
                  onPressed: _isRunning ? _stopTimer : null,
                ),
                _buildActionButton(
                  label: '重置',
                  icon: Icons.refresh,
                  color: Colors.blueGrey.shade600,
                  onPressed: _isReset ? null : _resetTimer,
                ),
                _buildActionButton(
                  label: '保存排名',
                  icon: Icons.save_alt,
                  color: Colors.deepPurple.shade600,
                  onPressed: _getRankedAthletes().length >= 2
                      ? _generateResults
                      : null,
                ),
              ],
            ),
          ),

          const Divider(),

          // 排名結果摘要面板
          if (_getRankedAthletes().isNotEmpty)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                    _formatTimeWithMs(athlete['time'] as int),
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

          // 選手列表標題
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text('排名',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 12 : 14)),
                ),
                Expanded(
                  flex: isSmallScreen ? 2 : 3,
                  child: Text('選手',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 12 : 14)),
                ),
                Expanded(
                  flex: isSmallScreen ? 1 : 2,
                  child: Text('時間',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 12 : 14),
                      textAlign: TextAlign.center),
                ),
                Expanded(
                  flex: isSmallScreen ? 1 : 2,
                  child: Text('操作',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 12 : 14),
                      textAlign: TextAlign.center),
                ),
              ],
            ),
          ),

          // 選手列表 - 使用更緊湊的排版
          Expanded(
            child: ListView.builder(
              itemCount: widget.athletes.length,
              itemBuilder: (context, index) {
                final athlete = widget.athletes[index];
                final athleteId = athlete['id'] as String;
                final hasTime = _athleteTimes.containsKey(athleteId) &&
                    _athleteTimes[athleteId]! > 0;
                final athleteTime = _athleteTimes[athleteId] ?? 0;
                final isCheckedIn = _checkedInStatus[athleteId] ?? false;

                // 使用卡片式設計顯示選手資料
                return Card(
                  elevation: 2,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isCheckedIn
                          ? Colors.green.shade200
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        // 選手基本資料
                        Row(
                          children: [
                            // 排名
                            Container(
                              width: isSmallScreen ? 32 : 40,
                              height: isSmallScreen ? 32 : 40,
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.8),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallScreen ? 12 : 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // 選手資料
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    athlete['name'] as String? ?? '未知選手',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          athlete['athleteNumber'] as String? ??
                                              '',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // 檢錄狀態標籤
                                      GestureDetector(
                                        onTap: () => _toggleCheckedInStatus(
                                          athleteId,
                                          isCheckedIn,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isCheckedIn
                                                ? Colors.green.shade100
                                                : Colors.orange.shade100,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isCheckedIn ? '已檢錄' : '未到',
                                            style: TextStyle(
                                              color: isCheckedIn
                                                  ? Colors.green.shade700
                                                  : Colors.orange.shade700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // 時間顯示
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: hasTime
                                    ? Colors.green.shade100
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: hasTime
                                      ? Colors.green.shade300
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '時間',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          hasTime ? Colors.green : Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    hasTime
                                        ? _formatTimeWithMs(athleteTime)
                                        : '--:--:--',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: hasTime
                                          ? Colors.green.shade800
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // 記錄按鈕
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isReset
                                    ? null
                                    : () => _recordAthleteTime(athleteId),
                                icon: Icon(
                                  hasTime ? Icons.update : Icons.timer,
                                  size: isSmallScreen ? 16 : 20,
                                ),
                                label: Text(
                                  hasTime ? '更新成績' : '記錄成績',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      hasTime ? Colors.orange : Colors.teal,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 構建操作按鈕
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 2,
        shadowColor: color.withOpacity(0.5),
        disabledBackgroundColor: color.withOpacity(0.3),
        disabledForegroundColor: Colors.white70,
      ),
    );
  }
}
