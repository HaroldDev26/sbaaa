import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/statistics_service.dart';
import '../../models/team_score.dart';
import 'export_service.dart';

class TeamPerformanceScreen extends StatefulWidget {
  final String competitionId;
  final String competitionName;

  const TeamPerformanceScreen({
    Key? key,
    required this.competitionId,
    required this.competitionName,
  }) : super(key: key);

  @override
  State<TeamPerformanceScreen> createState() => _TeamPerformanceScreenState();
}

class _TeamPerformanceScreenState extends State<TeamPerformanceScreen> {
  final StatisticsService _statisticsService = StatisticsService();
  bool _isLoading = true;
  String? _error;

  // 隊伍成績數據
  List<TeamScore> _teamScores = [];
  List<String> _allEvents = [];

  // 篩選條件
  String? _searchQuery;
  String? _selectedEvent;

  @override
  void initState() {
    super.initState();
    _loadTeamScores();
  }

  // 載入隊伍成績數據
  Future<void> _loadTeamScores() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 從服務獲取數據
      final data = await _statisticsService.getTeamScores(
        widget.competitionId,
        event: _selectedEvent,
      );

      final events =
          await _statisticsService.getCompetitionEvents(widget.competitionId);

      setState(() {
        _teamScores = data;
        _allEvents = ['全部項目'] + events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '載入隊伍成績失敗: $e';
        _isLoading = false;
      });
    }
  }

  // 篩選隊伍
  List<TeamScore> get _filteredTeams {
    if (_searchQuery == null || _searchQuery!.isEmpty) {
      return _teamScores;
    }

    final query = _searchQuery!.toLowerCase();
    return _teamScores
        .where((team) =>
            team.teamName.toLowerCase().contains(query) ||
            team.school?.toLowerCase().contains(query) == true)
        .toList();
  }

  // 搜索處理
  void _handleSearch(String? query) {
    setState(() {
      _searchQuery = query;
    });
  }

  // 項目選擇處理
  void _handleEventSelection(String? event) {
    setState(() {
      _selectedEvent = event == '全部項目' ? null : event;
    });
    _loadTeamScores();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    // 搜索和篩選區域
                    _buildFilterSection(),

                    // 統計數據摘要
                    if (_teamScores.isNotEmpty) _buildStatsSection(),

                    // 圖表和表格
                    Expanded(
                      child: _teamScores.isEmpty
                          ? const Center(child: Text('無隊伍數據'))
                          : DefaultTabController(
                              length: 3,
                              child: Column(
                                children: [
                                  const TabBar(
                                    tabs: [
                                      Tab(text: '排行榜'),
                                      Tab(text: '獎牌數量'),
                                      Tab(text: '隊伍比較'),
                                    ],
                                    labelColor: Colors.deepPurple,
                                  ),
                                  Expanded(
                                    child: TabBarView(
                                      children: [
                                        // 排行榜
                                        _buildRankingTable(),

                                        // 獎牌柱狀圖
                                        _buildMedalsChart(),

                                        // 隊伍比較圖
                                        _buildTeamComparisonChart(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  // 搜索和篩選區域
  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          // 搜索欄
          TextField(
            decoration: const InputDecoration(
              hintText: '搜索隊伍...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: _handleSearch,
          ),

          const SizedBox(height: 12),

          // 項目選擇
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: '選擇項目',
              border: OutlineInputBorder(),
            ),
            value: _selectedEvent ?? '全部項目',
            items: _allEvents
                .map((event) => DropdownMenuItem(
                      value: event,
                      child: Text(event),
                    ))
                .toList(),
            onChanged: _handleEventSelection,
          ),
        ],
      ),
    );
  }

  // 統計摘要區域
  Widget _buildStatsSection() {
    // 計算各個統計數據
    final totalTeams = _teamScores.length;
    final totalMedals = _teamScores.fold(
        0,
        (sum, team) =>
            sum + team.goldMedals + team.silverMedals + team.bronzeMedals);
    final topTeam = _teamScores.isNotEmpty ? _teamScores.first.teamName : 'N/A';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '隊伍統計摘要',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // 添加導出按鈕
              TextButton.icon(
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('導出報告'),
                onPressed: _exportTeamScores,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.indigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('參賽隊伍', '$totalTeams'),
              _buildStatItem('總獎牌數', '$totalMedals'),
              _buildStatItem('領先隊伍', topTeam),
            ],
          ),
        ],
      ),
    );
  }

  // 統計數字項
  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
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

  // 排行榜表格
  Widget _buildRankingTable() {
    // 篩選和排序隊伍
    final teams = _filteredTeams;
    teams.sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 標題
          Text(
            '隊伍總分排行榜',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // 數據表格
          DataTable(
            columnSpacing: 16,
            columns: const [
              DataColumn(label: Text('排名')),
              DataColumn(label: Text('隊伍名稱')),
              DataColumn(label: Text('學校')),
              DataColumn(label: Text('總分')),
              DataColumn(label: Text('金/銀/銅')),
            ],
            rows: teams.asMap().entries.map((entry) {
              final index = entry.key;
              final team = entry.value;

              return DataRow(cells: [
                DataCell(Text('${index + 1}')),
                DataCell(Text(team.teamName)),
                DataCell(Text(team.school ?? '-')),
                DataCell(Text('${team.totalScore}')),
                DataCell(Text(
                    '${team.goldMedals}/${team.silverMedals}/${team.bronzeMedals}')),
              ]);
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 獎牌數量圖表
  Widget _buildMedalsChart() {
    // 只顯示前10名
    final teamData = _filteredTeams.take(10).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            '獎牌數量分佈 (前10名)',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value >= 0 && value < teamData.length) {
                          final team = teamData[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              team.teamName.substring(
                                  0,
                                  team.teamName.length > 3
                                      ? 3
                                      : team.teamName.length),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: teamData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final team = entry.value;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: team.goldMedals.toDouble(),
                        color: Colors.amber,
                        width: 16,
                      ),
                      BarChartRodData(
                        toY: team.silverMedals.toDouble(),
                        color: Colors.grey.shade400,
                        width: 16,
                      ),
                      BarChartRodData(
                        toY: team.bronzeMedals.toDouble(),
                        color: Colors.brown.shade300,
                        width: 16,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          // 圖例
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('金牌', Colors.amber),
                const SizedBox(width: 24),
                _buildLegendItem('銀牌', Colors.grey.shade400),
                const SizedBox(width: 24),
                _buildLegendItem('銅牌', Colors.brown.shade300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 圖例項
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  // 隊伍比較圖表
  Widget _buildTeamComparisonChart() {
    // 只顯示前5名
    final teamData = _filteredTeams.take(5).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            '隊伍總分對比 (前5名)',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value >= 0 && value < teamData.length) {
                          final team = teamData[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              team.teamName,
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: teamData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final team = entry.value;

                  // 使用不同顏色區分隊伍
                  final colors = [
                    Colors.blue,
                    Colors.red,
                    Colors.green,
                    Colors.purple,
                    Colors.orange,
                  ];

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: team.totalScore.toDouble(),
                        color: colors[index % colors.length],
                        width: 20,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 添加導出隊伍成績方法
  void _exportTeamScores() {
    if (_teamScores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('沒有可導出的數據')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在生成隊伍報告...')),
    );

    // 使用導出服務
    final exportService = StatisticsExportService();
    exportService.exportTeamScoresToPdf(
      context: context,
      competitionName: widget.competitionName,
      teamScores: _teamScores,
    );
  }
}
