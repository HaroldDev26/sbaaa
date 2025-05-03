import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/colors.dart';
import '../../services/scoring_service.dart';

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
  final ScoringService _scoringService = ScoringService();
  final bool _isLoading = false;
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
        _rankedAthletes = results
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

        // 確保排名和積分正確
        final eventType = widget.eventResults['eventType'] as String? ?? '';
        final isRelayEvent = widget.eventName.toLowerCase().contains('接力');

        // 根據比賽類型重新計算排名和積分
        if (eventType == '田賽') {
          _rankedAthletes = _scoringService.sortAndRankFieldEventAthletes(
              _rankedAthletes,
              isRelayEvent: isRelayEvent);
        } else {
          _rankedAthletes = _scoringService.sortAndRankTrackEventAthletes(
              _rankedAthletes,
              isRelayEvent: isRelayEvent);
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
    final bool isIPhone15 = screenSize.width >= 390 &&
        screenSize.width <= 430 &&
        screenSize.height >= 840 &&
        screenSize.height <= 932;

    // 根據設備調整尺寸
    final double cardPadding = isIPhone15 ? 10 : 12;
    final double fontSize = isIPhone15 ? 14 : 16;

    // 判斷是否為接力項目
    final bool isRelayEvent = widget.eventName.toLowerCase().contains('接力');

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.eventName} - 成績排名'),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 頂部卡片 - 比賽信息
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                                style: const TextStyle(
                                  fontSize: 20,
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
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '記錄時間: ${_formatDateTime(widget.eventResults['recordedAt'])}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 排名標題
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 1,
                        child: Text(
                          '排名',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '選手資料',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '成績',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // 新增積分列
                      Expanded(
                        flex: 1,
                        child: Text(
                          '積分',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                // 結果列表
                Expanded(
                  child: _rankedAthletes.isEmpty
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
                            final score = athlete['score'] ?? 0;

                            // 決定排名的背景顏色
                            Color rankColor = _getRankColor(rank);

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(10)),
                                side: BorderSide(
                                  color: rank <= 3
                                      ? rankColor.withValues(alpha: 0.5)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: cardPadding,
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
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            athlete['athleteName'] as String? ??
                                                athlete['teamName']
                                                    as String? ??
                                                '未知',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: fontSize,
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
                                                    fontSize: fontSize - 2,
                                                    color: Colors.grey,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          // 如果是接力隊伍，添加查看隊員詳情的按鈕
                                          if (athlete.containsKey('members') &&
                                              athlete['members'] is List &&
                                              (athlete['members'] as List)
                                                  .isNotEmpty)
                                            InkWell(
                                              onTap: () =>
                                                  _showTeamMembersDialog(
                                                      athlete),
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4.0),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: const [
                                                    Icon(
                                                      Icons.people,
                                                      size: 14,
                                                      color: primaryColor,
                                                    ),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      '查看隊員',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: primaryColor,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    // 成績
                                    Expanded(
                                      flex: 3,
                                      child: Center(
                                        child: InkWell(
                                          onTap: () =>
                                              _showAthleteDetailsDialog(
                                                  athlete),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 120,
                                            ),
                                            decoration: BoxDecoration(
                                              color: rank <= 3
                                                  ? Colors.green.shade100
                                                  : Colors.grey.shade100,
                                              borderRadius:
                                                  const BorderRadius.all(
                                                      Radius.circular(16)),
                                              border: Border.all(
                                                color: rank <= 3
                                                    ? Colors.green.shade700
                                                    : Colors.grey.shade400,
                                              ),
                                            ),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                _formatResultDisplay(athlete),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: fontSize,
                                                  color: rank <= 3
                                                      ? Colors.green.shade800
                                                      : Colors.grey.shade800,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // 積分
                                    Expanded(
                                      flex: 1,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: primaryColor.withValues(
                                                alpha: 0.15),
                                            borderRadius:
                                                const BorderRadius.all(
                                                    Radius.circular(12)),
                                          ),
                                          child: Text(
                                            '$score',
                                            style: TextStyle(
                                              color: primaryColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: fontSize - 2,
                                            ),
                                            textAlign: TextAlign.center,
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '本次比賽共有${_rankedAthletes.length}名選手參加，完成記錄',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _scoringService.getScoringDescription(
                            isRelayEvent: isRelayEvent),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      // 新增最後更新時間顯示
                      if (widget.eventResults.containsKey('lastUpdated'))
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '最後更新: ${_formatDateTime(widget.eventResults['lastUpdated'])}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
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
      return "${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} "
          "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      // 捕獲所有可能的錯誤並返回錯誤信息
      return '時間格式錯誤: $e';
    }
  }

  // 新增詳細資訊顯示對話框
  void _showAthleteDetailsDialog(Map<String, dynamic> athlete) {
    final eventType = widget.eventResults['eventType'] as String? ?? '';
    final bool isField = eventType == '田賽';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${athlete['athleteName'] ?? '未知選手'} 的成績詳情'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 選手/隊伍基本資訊
            Text(
              '姓名: ${athlete['athleteName'] ?? athlete['teamName'] ?? '未知'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              athlete.containsKey('athleteNumber')
                  ? '編號: ${athlete['athleteNumber']}'
                  : athlete.containsKey('school')
                      ? '學校: ${athlete['school']}'
                      : '',
            ),
            const SizedBox(height: 16),

            // 排名和積分
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _getRankColor(athlete['rank'] ?? 0),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${athlete['rank'] ?? 0}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '排名: 第${athlete['rank'] ?? 0}名',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '得分: ${athlete['score'] ?? 0}分',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 成績詳情
            Text(
              '成績: ${isField ? (athlete["bestResult"]?.toStringAsFixed(2) ?? "-") + "m" : (athlete["timeFormattedWithMs"] ?? athlete["timeFormatted"] ?? "--:--:--")}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),

            // 接力隊員資訊
            if (athlete.containsKey('members') &&
                athlete['members'] is List &&
                (athlete['members'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: OutlinedButton.icon(
                  onPressed: () => _showTeamMembersDialog(athlete),
                  icon: const Icon(Icons.people),
                  label: const Text('查看隊員詳情'),
                ),
              ),

            // 田賽嘗試記錄
            if (isField &&
                athlete.containsKey('attempts') &&
                athlete['attempts'] is List &&
                athlete['attempts'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: OutlinedButton.icon(
                  onPressed: () => _showAttemptsDialog(athlete),
                  icon: const Icon(Icons.list),
                  label: const Text('查看嘗試記錄'),
                ),
              ),
          ],
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

  // 獲取排名顏色
  Color _getRankColor(int rank) {
    if (rank == 1) {
      return Colors.amber.shade700; // 金牌
    } else if (rank == 2) {
      return Colors.blueGrey.shade300; // 銀牌
    } else if (rank == 3) {
      return Colors.brown.shade300; // 銅牌
    } else {
      return primaryColor; // 其他排名
    }
  }

  // 顯示接力隊伍隊員的對話框
  void _showTeamMembersDialog(Map<String, dynamic> team) {
    final List<dynamic> members = team['members'] ?? [];
    final String teamName = team['athleteName'] ?? team['teamName'] ?? '未知隊伍';
    final String teamSchool = team['school'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(teamName),
            if (teamSchool.isNotEmpty)
              Text(
                teamSchool,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 300),
          child: members.isEmpty
              ? const Center(child: Text('沒有隊員資料'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: primaryColor,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(member['name'] ?? '未知隊員'),
                      subtitle: Text(
                        member['school'] ?? member['athleteNumber'] ?? '',
                        style: const TextStyle(fontSize: 12),
                      ),
                      dense: true,
                    );
                  },
                ),
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

  // 顯示嘗試記錄對話框 (用於田賽)
  void _showAttemptsDialog(Map<String, dynamic> athlete) {
    final String athleteName = athlete['athleteName'] ?? '未知選手';
    final List<dynamic> attempts = athlete['attempts'] ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$athleteName - 嘗試記錄'),
            const Text(
              '所有嘗試的成績記錄',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 300),
          child: attempts.isEmpty
              ? const Center(child: Text('沒有嘗試記錄'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: attempts.length,
                  itemBuilder: (context, index) {
                    final attempt = attempts[index];
                    final bool isFoul = attempt['isFoul'] == true;
                    final dynamic value = attempt['value'];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isFoul
                            ? Colors.red.shade100
                            : Colors.green.shade100,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(
                        isFoul
                            ? '犯規'
                            : (value != null
                                ? '${value.toStringAsFixed(2)}m'
                                : '--'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isFoul ? Colors.red : Colors.green.shade800,
                        ),
                      ),
                      dense: true,
                    );
                  },
                ),
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

  // 格式化結果顯示 (針對不同比賽類型)
  String _formatResultDisplay(Map<String, dynamic> athlete) {
    // 檢查比賽類型
    final eventType = widget.eventResults['eventType'] as String? ?? '';

    // 田賽 - 顯示最佳成績（米）
    if (eventType == '田賽') {
      if (athlete.containsKey('bestResult')) {
        final bestResult = athlete['bestResult'];
        if (bestResult is double || bestResult is int) {
          return '${bestResult.toStringAsFixed(2)}m';
        }
      }
      return '--m';
    }
    // 徑賽/接力賽 - 顯示時間
    else {
      return athlete['timeFormattedWithMs'] ??
          athlete['timeFormatted'] ??
          '--:--:--';
    }
  }
}
