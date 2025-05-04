import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/searching_function.dart';
import 'event_result_screen.dart';
import '../../services/scoring_service.dart';
import '../../utils/sorting_function.dart';

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
  final ScoringService _scoringService = ScoringService();

  // 計時器相關變數
  bool _isRunning = false;
  bool _isReset = true;
  DateTime? _startTime;
  DateTime? _currentTime;
  Duration _elapsedDuration = Duration.zero;
  Timer? _updateTimer;

  // 選手成績記錄
  final Map<String, int> _athleteTimes = {};

  // 計時狀態
  String _timerStatus = '準備';

  // 新增狀態變數
  bool _isLoading = true;
  // 選手資料
  List<Map<String, dynamic>> _athletes = [];
  List<Map<String, dynamic>> _filteredAthletes = [];

  @override
  void initState() {
    super.initState();
    _loadAthletes();
  }

  // 修改：載入選手資料的 function
  Future<void> _loadAthletes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 從比賽的報名名單中載入選手資料
      final collectionName = 'competition_${widget.competitionId}';
      final snapshot = await _firestore
          .collection(collectionName)
          .where('status', isEqualTo: 'approved')
          .get();

      List<Map<String, dynamic>> athletes = [];
      int invalidCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final events = data['events'] as List<dynamic>? ?? [];

        // 篩選參加指定項目的選手
        if (events.contains(widget.eventName)) {
          // 檢查選手數據的完整性
          if (doc.id.isEmpty) {
            debugPrint('警告: 發現沒有ID的選手記錄，已跳過');
            invalidCount++;
            continue;
          }

          // 確保選手姓名有效
          String name = '未知選手';
          if (data['userName'] != null &&
              data['userName'].toString().trim().isNotEmpty) {
            name = data['userName'].toString().trim();
          } else if (data['name'] != null &&
              data['name'].toString().trim().isNotEmpty) {
            name = data['name'].toString().trim();
          } else {
            name = '選手#${athletes.length + 1}';
            debugPrint('警告: 選手 ${doc.id} 無姓名，使用默認名稱: $name');
          }

          // 確保選手編號有效
          String athleteNumber = '';
          if (data['athleteNumber'] != null &&
              data['athleteNumber'].toString().trim().isNotEmpty) {
            athleteNumber = data['athleteNumber'].toString().trim();
          } else {
            athleteNumber = 'A${athletes.length + 1}'.padLeft(4, '0');
            debugPrint('選手 $name 無編號，使用生成編號: $athleteNumber');
          }

          // 獲取更多選手資訊
          String school = data['school'] ?? '未知學校';
          String gender = data['gender'] ?? '未知';
          String ageGroup = data['ageGroup'] ?? '未知';

          athletes.add({
            'id': doc.id,
            'name': name,
            'athleteNumber': athleteNumber,
            'school': school,
            'gender': gender,
            'ageGroup': ageGroup,
            'events': events,
            'checkedIn': data['checkedIn'] ?? false,
          });
        }
      }

      // 排序：已檢錄的排前面，然後按選手號碼排序
      athletes = sortByAlphabet(athletes, 'athleteNumber');

      // 按照檢錄狀態再次排序（已檢錄的排前面）
      athletes = athletes.where((a) => a['checkedIn'] == true).toList() +
          athletes.where((a) => a['checkedIn'] != true).toList();

      // 如果沒有找到選手，使用widget.athletes作為備選
      if (athletes.isEmpty && widget.athletes.isNotEmpty) {
        debugPrint(
            '在Firebase中未找到選手，使用widget.athletes (${widget.athletes.length}個選手)');
        athletes = List<Map<String, dynamic>>.from(widget.athletes);
      }

      // 加載選手之前記錄的成績
      await _loadSavedResults();

      setState(() {
        _athletes = athletes;
        _filteredAthletes = athletes;
        _isLoading = false;
      });

      // 提供加載結果的反饋
      debugPrint('成功載入${_athletes.length}名選手，跳過$invalidCount個無效記錄');

      // 初始化選手成績記錄
      for (var athlete in _athletes) {
        final id = athlete['id'] as String;
        if (!_athleteTimes.containsKey(id)) {
          _athleteTimes[id] = 0;
        }
      }
    } catch (e) {
      debugPrint('載入選手資料失敗: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('載入選手資料失敗: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: '重試',
              onPressed: _loadAthletes,
            ),
          ),
        );
      }
    }
  }

  // 新增：載入已儲存的成績
  Future<void> _loadSavedResults() async {
    try {
      // 檢查是否有已儲存的成績記錄
      final docRef = _firestore
          .collection('competitions')
          .doc(widget.competitionId)
          .collection('track_results')
          .doc(widget.eventName.replaceAll(' ', '_').toLowerCase());

      final doc = await docRef.get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;

        if (data.containsKey('results')) {
          final results = data['results'] as Map<String, dynamic>;

          results.forEach((athleteId, result) {
            if (result is int || result is double) {
              _athleteTimes[athleteId] = (result as num).toInt();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('載入已儲存成績時發生錯誤: $e');
    }
  }

  @override
  void dispose() {
    debugPrint('TrackEventTimerScreen 即將銷毀');
    _updateTimer?.cancel();
    super.dispose();
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

    // 使用Timer更新當前時間，實現計時功能（降低更新頻率以節省資源）
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

    // 顯示通知
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('計時開始'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
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

    // 顯示通知和當前時間
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('計時停止: ${_formatDuration(_elapsedDuration)}'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
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

      // 重置成績 - 使用_athletes而不是widget.athletes
      for (var athlete in _athletes) {
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
      // 直接更新成績
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
    if (timeInCentiseconds <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('無法記錄：計時器未啟動或已重置'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

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
      final athlete =
          _athletes.firstWhere((a) => a['id'] == athleteId, orElse: () {
        final defaultName = widget.athletes.firstWhere(
            (a) => a['id'] == athleteId,
            orElse: () => {'name': '未知選手'})['name'];
        return {'id': athleteId, 'name': defaultName, 'athleteNumber': ''};
      });

      // 結果數據
      final resultData = {
        'athleteId': athleteId,
        'athleteName': athlete['name'],
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
      debugPrint('儲存成績時發生錯誤: $e');
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
    // 過濾掉沒有時間記錄的選手
    List<Map<String, dynamic>> rankedAthletes = _athletes
        .where((athlete) =>
            _athleteTimes.containsKey(athlete['id']) &&
            _athleteTimes[athlete['id']]! > 0)
        .map((athlete) {
      final int time = _athleteTimes[athlete['id']]!;
      return {
        ...athlete,
        'time': time,
        'timeFormatted': _formatTime(time, includeMs: false),
        'timeFormattedWithMs': _formatTimeWithMs(time),
      };
    }).toList();

    // 使用ScoringService進行排序和積分計算
    final isRelayEvent = widget.eventName.toLowerCase().contains('接力');
    rankedAthletes = _scoringService.sortAndRankTrackEventAthletes(
        rankedAthletes,
        isRelayEvent: isRelayEvent);

    return rankedAthletes;
  }

  // 產生最終結果頁面
  Future<void> _generateResults() async {
    // 取得排名後的選手名單
    final rankedAthletes = _getRankedAthletes();

    // 添加調試信息
    debugPrint('_athletes數量: ${_athletes.length}');
    debugPrint('排名選手數量: ${rankedAthletes.length}');
    debugPrint('_athleteTimes記錄數: ${_athleteTimes.length}');
    _athleteTimes.forEach((id, time) {
      debugPrint('ID: $id, 時間: $time');
    });

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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      // 儲存最終排名到Firestore
      final batch = _firestore.batch();

      // 結果文檔參考 - 使用事件名稱作為文檔ID
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
          debugPrint('警告：選手 ${athlete['name']} 的時間格式不正確，已設為默認值0');
          time = 0; // 默認值
        }

        // 確保選手ID為字符串
        String athleteId = (athlete['id'] ?? '').toString();

        // 確保選手名稱為字符串
        String athleteName = (athlete['name'] ?? '未知選手').toString();

        // 確保選手編號為字符串
        String athleteNumber = (athlete['athleteNumber'] ?? '').toString();

        // 確保排名為整數
        int rank = athlete['rank'] is int ? athlete['rank'] : 0;

        // 確保得分為整數
        int score = athlete['score'] is int ? athlete['score'] : 0;

        return {
          'athleteId': athleteId,
          'athleteName': athleteName,
          'athleteNumber': athleteNumber,
          'time': time,
          'timeFormatted': _formatTime(time),
          'timeFormattedWithMs': _formatTimeWithMs(time),
          'rank': rank,
          'score': score
        };
      }).toList();

      // 最終結果數據
      final finalResultData = {
        'eventName': widget.eventName,
        'eventType': '徑賽',
        'competitionId': widget.competitionId,
        'competitionName': widget.competitionName,
        'results': formattedResults,
        'recordedAt': now,
        'lastUpdated': FieldValue.serverTimestamp()
      };

      // 加入批次
      batch.set(finalResultRef, finalResultData);

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
            'lastUpdated': FieldValue.serverTimestamp(),
            'competitionId': widget.competitionId,
            'competitionName': widget.competitionName,
            'hasResults': true,
          },
          SetOptions(merge: true));

      // 執行批次操作
      await batch.commit();

      if (!mounted) return;

      // 關閉加載指示器
      Navigator.pop(context);

      // 顯示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('成績排名已成功保存'),
          backgroundColor: Colors.green,
        ),
      );

      // 跳轉到成績排名頁面
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
    } catch (e) {
      if (!mounted) return;

      // 關閉加載指示器
      Navigator.pop(context);

      // 顯示錯誤訊息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存成績時出錯: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 格式化時間顯示 (標準格式)
  String _formatTime(int centiseconds, {bool includeMs = false}) {
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
    // 獲取螢幕尺寸
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.eventName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.competitionName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // 添加操作選單
          PopupMenuButton<String>(
            tooltip: '操作選單',
            onSelected: (value) {
              if (value == 'save') {
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
                    Icon(Icons.save_alt, size: 18),
                    SizedBox(width: 8),
                    Text('保存成績排名'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'reload',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 8),
                    Text('重新載入選手'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    '載入選手資料中...',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // 計時器顯示區
                Container(
                  padding:
                      EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 16),
                  color: Colors.indigo.shade900,
                  width: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 狀態顯示
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: _isRunning
                              ? Colors.green.withValues(alpha: 0.3)
                              : _isReset
                                  ? Colors.grey.withValues(alpha: 0.3)
                                  : Colors.red.withValues(alpha: 0.3),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isRunning
                                ? Colors.green.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.2),
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.2),
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
                    ],
                  ),
                ),

                const Divider(height: 1),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'search for athlete...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        if (value.isEmpty) {
                          _filteredAthletes = _athletes;
                        } else {
                          _filteredAthletes = searchAthletes(
                              _athletes, value, {},
                              isSorted: true, sortField: 'name');
                        }
                      });
                    },
                  ),
                ),

                // 排名結果摘要面板
                if (_getRankedAthletes().isNotEmpty)
                  Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.green.shade50,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.green.shade200),
                    ),
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
                                          _formatTimeWithMs(
                                              athlete['time'] as int),
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
                      ? Center(
                          child: Text(
                            '沒有找到符合條件的選手',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredAthletes.length,
                          itemBuilder: (context, index) {
                            final athlete = _filteredAthletes[index];
                            final athleteId = athlete['id'] as String;
                            final hasTime =
                                _athleteTimes.containsKey(athleteId) &&
                                    _athleteTimes[athleteId]! > 0;
                            final athleteTime = _athleteTimes[athleteId] ?? 0;

                            // 使用卡片式設計顯示選手資料
                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: hasTime
                                      ? Colors.green.shade200
                                      : Colors.grey.shade300,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  // 選手基本資料
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        topRight: Radius.circular(12),
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // 選手資料
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                athlete['name'] as String? ??
                                                    '未知選手',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
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
                                                              as String? ??
                                                          '',
                                                      style: TextStyle(
                                                        color: Colors
                                                            .grey.shade700,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    athlete['school'] ?? '',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        // 時間顯示
                                        if (hasTime)
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.green.shade300,
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                const Text(
                                                  '完成時間',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                                Text(
                                                  _formatTimeWithMs(
                                                      athleteTime),
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

                                  // 記錄按鈕
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: _isReset
                                              ? null
                                              : () =>
                                                  _recordAthleteTime(athleteId),
                                          icon: Icon(
                                            hasTime
                                                ? Icons.update
                                                : Icons.timer,
                                            size: 20,
                                          ),
                                          label: Text(
                                            hasTime ? '更新成績' : '記錄成績',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: hasTime
                                                ? Colors.orange
                                                : Colors.teal,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                          ),
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
        shadowColor: color.withValues(alpha: 0.5),
        disabledBackgroundColor: color.withValues(alpha: 0.3),
        disabledForegroundColor: Colors.white70,
      ),
    );
  }
}
