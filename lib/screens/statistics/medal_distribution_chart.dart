import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MedalDistributionChart extends StatefulWidget {
  final String competitionId;
  final String competitionName;

  const MedalDistributionChart({
    Key? key,
    required this.competitionId,
    required this.competitionName,
  }) : super(key: key);

  @override
  State<MedalDistributionChart> createState() => _MedalDistributionChartState();
}

class _MedalDistributionChartState extends State<MedalDistributionChart> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String? _error;

  // 獎牌統計數據
  Map<String, int> _schoolGoldMedals = {};
  Map<String, int> _schoolSilverMedals = {};
  Map<String, int> _schoolBronzeMedals = {};
  Map<String, int> _schoolTotalMedals = {};

  // 用於存儲選手ID和學校的映射
  final Map<String, String> _athleteSchools = {};

  // 篩選條件
  String _selectedMedalType = '總獎牌';
  final List<String> _medalTypes = ['總獎牌', '金牌', '銀牌', '銅牌'];

  // 圖表顯示相關設定
  int _maxDisplayedSchools = 8; // 最多顯示幾個學校
  bool _isLoadingSchools = false;

  @override
  void initState() {
    super.initState();
    _loadMedalData();
  }

  // 載入獎牌數據
  Future<void> _loadMedalData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 獲取比賽所有結果
      final snapshot = await _firestore
          .collection('competitions')
          .doc(widget.competitionId)
          .collection('final_results')
          .get();

      // 重置數據
      _schoolGoldMedals = {};
      _schoolSilverMedals = {};
      _schoolBronzeMedals = {};
      _schoolTotalMedals = {};

      // 收集需要查詢學校的運動員ID
      List<Map<String, dynamic>> athletesNeedingSchool = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // 確保有結果資料
        if (data.containsKey('results') && data['results'] is List) {
          List<dynamic> results = data['results'] as List;

          for (var athlete in results) {
            // 嘗試從現有數據獲取學校名稱
            String? school = getAthleteSchool(athlete);

            // 確保每個運動員都有學校信息
            if (school.isEmpty) {
              // 收集運動員信息以便後續查詢
              athletesNeedingSchool.add(athlete);
            }

            // 根據排名累計獎牌
            if (athlete['rank'] == 1) {
              if (school.isNotEmpty) {
                _schoolGoldMedals[school] =
                    (_schoolGoldMedals[school] ?? 0) + 1;
                _schoolTotalMedals[school] =
                    (_schoolTotalMedals[school] ?? 0) + 1;
              }
            } else if (athlete['rank'] == 2) {
              if (school.isNotEmpty) {
                _schoolSilverMedals[school] =
                    (_schoolSilverMedals[school] ?? 0) + 1;
                _schoolTotalMedals[school] =
                    (_schoolTotalMedals[school] ?? 0) + 1;
              }
            } else if (athlete['rank'] == 3) {
              if (school.isNotEmpty) {
                _schoolBronzeMedals[school] =
                    (_schoolBronzeMedals[school] ?? 0) + 1;
                _schoolTotalMedals[school] =
                    (_schoolTotalMedals[school] ?? 0) + 1;
              }
            }
          }
        }
      }

      // 如果有需要查詢學校的運動員，先加載它們的學校信息
      if (athletesNeedingSchool.isNotEmpty) {
        await _loadAthleteSchools(athletesNeedingSchool);

        // 再次處理獎牌統計，這次包括新獲得的學校信息
        for (var athlete in athletesNeedingSchool) {
          String school = getAthleteSchool(athlete);
          if (school.isNotEmpty) {
            if (athlete['rank'] == 1) {
              _schoolGoldMedals[school] = (_schoolGoldMedals[school] ?? 0) + 1;
              _schoolTotalMedals[school] =
                  (_schoolTotalMedals[school] ?? 0) + 1;
            } else if (athlete['rank'] == 2) {
              _schoolSilverMedals[school] =
                  (_schoolSilverMedals[school] ?? 0) + 1;
              _schoolTotalMedals[school] =
                  (_schoolTotalMedals[school] ?? 0) + 1;
            } else if (athlete['rank'] == 3) {
              _schoolBronzeMedals[school] =
                  (_schoolBronzeMedals[school] ?? 0) + 1;
              _schoolTotalMedals[school] =
                  (_schoolTotalMedals[school] ?? 0) + 1;
            }
          }
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '載入獎牌數據失敗: $e';
      });
    }
  }

  // 獲取運動員的學校，優先使用已有數據
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

  // 獲取當前選擇的獎牌類型的數據
  Map<String, int> get _selectedMedalData {
    switch (_selectedMedalType) {
      case '金牌':
        return _schoolGoldMedals;
      case '銀牌':
        return _schoolSilverMedals;
      case '銅牌':
        return _schoolBronzeMedals;
      case '總獎牌':
      default:
        return _schoolTotalMedals;
    }
  }

  // 獲取獎牌顏色
  Color getMedalColor(String medalType) {
    switch (medalType) {
      case '金牌':
        return const Color(0xFFFFD700); // 金色
      case '銀牌':
        return const Color(0xFFC0C0C0); // 銀色
      case '銅牌':
        return const Color(0xFFCD7F32); // 銅色
      case '總獎牌':
      default:
        return const Color(0xFF5E35B1); // 紫色
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.competitionName} - 獎牌分布Pie Chart'),
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
                    onPressed: _loadMedalData,
                    child: const Text('重試'),
                  ),
                ],
              ),
            )
          : _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('載入數據中...'),
                    ],
                  ),
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildFilterSection(),
        _buildMedalSummary(),
        Expanded(
          child: _isLoadingSchools
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        '正在查詢學校資料...',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : _buildPieChart(),
        ),
      ],
    );
  }

  // 構建過濾選項區域
  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '獎牌類型:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: SegmentedButton<String>(
              segments: _medalTypes.map((type) {
                return ButtonSegment<String>(
                  value: type,
                  label: Text(type),
                  icon: Icon(
                    type == '金牌'
                        ? Icons.looks_one
                        : type == '銀牌'
                            ? Icons.looks_two
                            : type == '銅牌'
                                ? Icons.looks_3
                                : Icons.emoji_events,
                  ),
                );
              }).toList(),
              selected: {_selectedMedalType},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedMedalType = newSelection.first;
                });
              },
              style: ButtonStyle(
                backgroundColor: MaterialStatePropertyAll(
                  getMedalColor(_selectedMedalType).withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 構建獎牌摘要區域
  Widget _buildMedalSummary() {
    final medalData = _selectedMedalData;
    final totalMedals = medalData.values.fold(0, (a, b) => a + b);
    final schoolCount = medalData.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('參與學校', '$schoolCount'),
          _buildSummaryItem('獎牌總數', '$totalMedals'),
          _buildSummaryItem(
            '領先學校',
            medalData.isEmpty
                ? '-'
                : medalData.entries
                    .reduce((a, b) => a.value > b.value ? a : b)
                    .key,
          ),
        ],
      ),
    );
  }

  // 構建摘要項目
  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // 構建圓餅圖
  Widget _buildPieChart() {
    final medalData = _selectedMedalData;

    if (medalData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '沒有${_selectedMedalType}數據',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    // 排序並限制顯示學校數量
    var sortedEntries = medalData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 如果學校數量超過上限，將剩餘的合併為"其他學校"
    List<MapEntry<String, int>> displayedEntries = [];
    int otherMedals = 0;

    for (int i = 0; i < sortedEntries.length; i++) {
      if (i < _maxDisplayedSchools) {
        displayedEntries.add(sortedEntries[i]);
      } else {
        otherMedals += sortedEntries[i].value;
      }
    }

    // 如果有"其他學校"，添加到顯示列表
    if (otherMedals > 0) {
      displayedEntries.add(MapEntry('其他學校', otherMedals));
    }

    // 計算總數，用於百分比
    final totalCount =
        displayedEntries.fold(0, (sum, entry) => sum + entry.value);

    // 準備圓餅圖數據
    List<PieChartSectionData> sections = [];
    List<Widget> legends = [];

    for (int i = 0; i < displayedEntries.length; i++) {
      final entry = displayedEntries[i];
      final percent = totalCount > 0 ? (entry.value / totalCount * 100) : 0;

      // 為每個學校選擇一個顏色
      final color = Colors.primaries[i % Colors.primaries.length];

      // 處理學校名稱過長的情況
      String schoolName = entry.key;
      if (schoolName.length > 8) {
        schoolName = '${schoolName.substring(0, 6)}...';
      }

      // 添加圓餅圖區塊
      sections.add(
        PieChartSectionData(
          value: entry.value.toDouble(),
          title: '${percent.toStringAsFixed(1)}%',
          color: color,
          radius: 80,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );

      // 添加圖例
      legends.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${entry.key} (${entry.value})',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            '${_selectedMedalType}分布',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: getMedalColor(_selectedMedalType),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                // 圓餅圖
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    ),
                  ),
                ),

                // 圖例
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: legends,
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
}
