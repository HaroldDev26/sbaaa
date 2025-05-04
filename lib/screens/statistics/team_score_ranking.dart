import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/colors.dart';

class TeamScoreRanking extends StatefulWidget {
  final String competitionId;
  final String competitionName;

  const TeamScoreRanking({
    Key? key,
    required this.competitionId,
    required this.competitionName,
  }) : super(key: key);

  @override
  State<TeamScoreRanking> createState() => _TeamScoreRankingState();
}

class _TeamScoreRankingState extends State<TeamScoreRanking> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String? _error;

  // 儲存隊伍分數資料
  Map<String, int> _teamScores = {};
  int _totalScore = 0;

  // 學校資料查詢相關
  final Map<String, String> _athleteSchools = {};
  bool _isLoadingSchools = false;

  @override
  void initState() {
    super.initState();
    _loadTeamScores();
  }

  // 載入隊伍分數資料
  Future<void> _loadTeamScores() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 從成績結果中計算隊伍得分
      final resultsSnapshot = await _firestore
          .collection('competitions')
          .doc(widget.competitionId)
          .collection('final_results')
          .get();

      // 收集需要查詢學校的選手
      List<Map<String, dynamic>> athletesNeedingSchool = [];

      // 重置資料
      _teamScores = {};

      // 計算積分
      for (var doc in resultsSnapshot.docs) {
        final data = doc.data();

        if (data.containsKey('results') && data['results'] is List) {
          List<dynamic> results = data['results'] as List;

          // 判斷是否為接力項目
          bool isRelay = false;
          String eventName = data['eventName']?.toString() ?? '';
          String eventType = data['eventType']?.toString() ?? '';
          if (eventType == '接力' || eventName.toLowerCase().contains('接力')) {
            isRelay = true;
          }

          for (var athlete in results) {
            if (athlete['rank'] == null) continue;

            // 獲取學校名稱
            String school = getAthleteSchool(athlete);

            // 如果沒有學校信息，收集起來以便後續查詢
            if (school.isEmpty) {
              athletesNeedingSchool.add({...athlete, 'isRelay': isRelay});
              continue;
            }

            // 根據名次計算積分
            int points =
                _calculatePointsForRank(athlete['rank'], isRelay: isRelay);
            _teamScores[school] = (_teamScores[school] ?? 0) + points;
          }
        }
      }

      // 如果有需要查詢學校的選手，先加載它們的學校信息
      if (athletesNeedingSchool.isNotEmpty) {
        await _loadAthleteSchools(athletesNeedingSchool);

        // 再次處理積分統計，包括新獲取的學校信息
        for (var athlete in athletesNeedingSchool) {
          String school = getAthleteSchool(athlete);
          if (school.isNotEmpty && athlete['rank'] != null) {
            bool isRelay = athlete['isRelay'] ?? false;
            int points =
                _calculatePointsForRank(athlete['rank'], isRelay: isRelay);
            _teamScores[school] = (_teamScores[school] ?? 0) + points;
          }
        }
      }

      // 計算總積分
      _totalScore = _teamScores.values.fold(0, (sum, score) => sum + score);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '載入隊伍分數失敗: $e';
      });
      debugPrint('載入隊伍分數失敗: $e');
    }
  }

  // 根據名次計算積分
  int _calculatePointsForRank(int rank, {bool isRelay = false}) {
    int baseScore = 0;
    switch (rank) {
      case 1:
        baseScore = 11; // 第一名 11分
        break;
      case 2:
        baseScore = 9; // 第二名 9分
        break;
      case 3:
        baseScore = 7; // 第三名 7分
        break;
      case 4:
        baseScore = 5; // 第四名 5分
        break;
      case 5:
        baseScore = 4; // 第五名 4分
        break;
      case 6:
        baseScore = 3; // 第六名 3分
        break;
      case 7:
        baseScore = 2; // 第七名 2分
        break;
      case 8:
        baseScore = 1; // 第八名 1分
        break;
      default:
        baseScore = 0; // 其他名次不得分
        break;
    }

    // 接力項目得分翻倍
    return isRelay ? baseScore * 2 : baseScore;
  }

  // 獲取運動員的學校
  String getAthleteSchool(Map<String, dynamic> athlete) {
    final String id = athlete['athleteId'] ?? athlete['id'] ?? '';
    final String originalSchool = athlete['school'] ?? '';

    // 如果原始數據已有學校，直接返回
    if (originalSchool.isNotEmpty) {
      return originalSchool;
    }

    // 嘗試從緩存中獲取
    if (id.isNotEmpty && _athleteSchools.containsKey(id)) {
      return _athleteSchools[id] ?? '';
    }

    return '';
  }

  // 批量加載運動員學校信息
  Future<void> _loadAthleteSchools(List<Map<String, dynamic>> athletes) async {
    if (athletes.isEmpty) return;

    setState(() {
      _isLoadingSchools = true;
    });

    try {
      // 收集需要查詢的運動員ID
      List<String> athleteIds = [];
      for (var athlete in athletes) {
        final String id = athlete['athleteId'] ?? athlete['id'] ?? '';
        if (id.isNotEmpty && !_athleteSchools.containsKey(id)) {
          athleteIds.add(id);
        }
      }

      if (athleteIds.isEmpty) {
        setState(() {
          _isLoadingSchools = false;
        });
        return;
      }

      // 分批查詢，每批最多25個ID（Firestore限制）
      const int maxBatchSize = 25;
      for (int i = 0; i < athleteIds.length; i += maxBatchSize) {
        final int end = (i + maxBatchSize < athleteIds.length)
            ? i + maxBatchSize
            : athleteIds.length;
        final batch = athleteIds.sublist(i, end);

        await _batchLoadSchools(batch);
      }
    } catch (e) {
      debugPrint('批量加載學校信息失敗: $e');
    } finally {
      setState(() {
        _isLoadingSchools = false;
      });
    }
  }

  // 批量獲取學校信息
  Future<void> _batchLoadSchools(List<String> athleteIds) async {
    if (athleteIds.isEmpty) return;

    try {
      final collectionName = 'competition_${widget.competitionId}';
      final List<Future<DocumentSnapshot>> futures = athleteIds
          .map((id) => _firestore.collection(collectionName).doc(id).get())
          .toList();

      final results = await Future.wait(futures);

      Map<String, String> newSchools = {};
      for (int i = 0; i < athleteIds.length; i++) {
        final doc = results[i];
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null && data['school'] != null) {
            final school = data['school'] as String;
            if (school.isNotEmpty) {
              newSchools[athleteIds[i]] = school;
            }
          }
        }
      }

      if (newSchools.isNotEmpty) {
        setState(() {
          _athleteSchools.addAll(newSchools);
        });
      }
    } catch (e) {
      debugPrint('獲取學校信息失敗: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.competitionName} - 隊伍積分Ranking'),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 0,
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadTeamScores,
                    child: const Text('重試'),
                  ),
                ],
              ),
            )
          : _isLoading || _isLoadingSchools
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('載入隊伍分數數據中...'),
                    ],
                  ),
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_teamScores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '沒有隊伍積分數據',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTeamScores,
              child: const Text('重新載入'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildSummaryCard(),
          _buildLeaderboard(),
        ],
      ),
    );
  }

  // 構建摘要卡片
  Widget _buildSummaryCard() {
    final totalSchools = _teamScores.length;

    // 獲取得分最高的學校
    String topSchool = '';
    int topScore = 0;

    if (_teamScores.isNotEmpty) {
      final topEntry =
          _teamScores.entries.reduce((a, b) => a.value > b.value ? a : b);
      topSchool = topEntry.key;
      topScore = topEntry.value;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '隊伍積分摘要',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    title: '參賽隊伍',
                    value: totalSchools.toString(),
                    icon: Icons.groups,
                  ),
                  _buildStatItem(
                    title: '總積分',
                    value: _totalScore.toString(),
                    icon: Icons.leaderboard,
                  ),
                  _buildStatItem(
                    title: '領先隊伍',
                    value: topSchool,
                    subtitle: '$topScore 分',
                    icon: Icons.emoji_events,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 構建統計項目
  Widget _buildStatItem({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
  }) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: primaryColor.withValues(alpha: 0.1),
          radius: 20,
          child: Icon(icon, color: primaryColor),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          subtitle ?? title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // 構建積分榜
  Widget _buildLeaderboard() {
    var sortedEntries = _teamScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.leaderboard, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                '隊伍積分排名',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // 標題欄
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: const [
                      SizedBox(width: 50),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '學校',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '積分',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                // 隊伍列表
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedEntries.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = sortedEntries[index];

                    // 特殊處理前三名
                    Color? medalColor;
                    IconData medalIcon = Icons.emoji_events;

                    if (index == 0) {
                      medalColor = Colors.amber; // 金牌
                    } else if (index == 1) {
                      medalColor = Colors.blueGrey; // 銀牌
                    } else if (index == 2) {
                      medalColor = Colors.brown.shade300; // 銅牌
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: medalColor != null
                            ? medalColor.withValues(alpha: 0.2)
                            : Colors.grey.shade200,
                        child: medalColor != null
                            ? Icon(medalIcon, color: medalColor, size: 20)
                            : Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      title: Text(
                        entry.key,
                        style: TextStyle(
                          fontWeight:
                              index < 3 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${entry.value} 分',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
