import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/statistics_service.dart';
import '../../models/event_result.dart';
import 'export_service.dart';

class PerformanceAnalysisScreen extends StatefulWidget {
  final String competitionId;
  final String competitionName;

  const PerformanceAnalysisScreen({
    Key? key,
    required this.competitionId,
    required this.competitionName,
  }) : super(key: key);

  @override
  State<PerformanceAnalysisScreen> createState() =>
      _PerformanceAnalysisScreenState();
}

class _PerformanceAnalysisScreenState extends State<PerformanceAnalysisScreen> {
  final StatisticsService _statisticsService = StatisticsService();
  bool _isLoading = true;
  String? _error;

  // 所有事件和結果
  List<String> _events = [];
  String? _selectedEvent;
  List<EventResult> _eventResults = [];
  Map<String, dynamic> _statistics = {};

  // 篩選條件
  String? _selectedGender;
  String? _selectedAgeGroup;
  final List<String> _genders = ['全部', '男', '女'];
  final List<String> _ageGroups = ['全部', '小學', '初中', '高中'];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  // 載入所有項目
  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final events =
          await _statisticsService.getCompetitionEvents(widget.competitionId);
      setState(() {
        _events = events;
        if (events.isNotEmpty) {
          _selectedEvent = events.first;
          _loadEventResults();
        } else {
          _isLoading = false;
        }
      });
    } catch (e) {
      setState(() {
        _error = '載入項目失敗: $e';
        _isLoading = false;
      });
    }
  }

  // 載入項目成績
  Future<void> _loadEventResults() async {
    if (_selectedEvent == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _statisticsService.getEventResults(
        widget.competitionId,
        _selectedEvent!,
        gender: _selectedGender != '全部' ? _selectedGender : null,
        ageGroup: _selectedAgeGroup != '全部' ? _selectedAgeGroup : null,
      );

      final stats = _statisticsService.calculateStatistics(results);

      setState(() {
        _eventResults = results;
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '載入成績失敗: $e';
        _isLoading = false;
      });
    }
  }

  // 應用篩選
  void _applyFilters() {
    _loadEventResults();
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
                    // 篩選區域
                    _buildFilterSection(),

                    // 統計數據卡片
                    if (_statistics.isNotEmpty) _buildStatisticsCard(),

                    // 圖表和表格
                    Expanded(
                      child: _eventResults.isEmpty
                          ? const Center(child: Text('無成績數據'))
                          : DefaultTabController(
                              length: 2,
                              child: Column(
                                children: [
                                  const TabBar(
                                    tabs: [
                                      Tab(text: '成績分佈'),
                                      Tab(text: '排名表'),
                                    ],
                                    labelColor: Colors.blue,
                                  ),
                                  Expanded(
                                    child: TabBarView(
                                      children: [
                                        // 成績分佈圖
                                        _buildDistributionChart(),

                                        // 排名表
                                        _buildRankingTable(),
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

  // 篩選區域
  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 項目選擇下拉選單
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: '選擇項目',
              border: OutlineInputBorder(),
            ),
            value: _selectedEvent,
            items: _events
                .map((event) => DropdownMenuItem(
                      value: event,
                      child: Text(event),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedEvent = value;
              });
              _loadEventResults();
            },
          ),

          const SizedBox(height: 16),

          // 篩選選項列
          Row(
            children: [
              // 性別篩選
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: '性別',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedGender ?? '全部',
                  items: _genders
                      .map((gender) => DropdownMenuItem(
                            value: gender,
                            child: Text(gender),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value;
                    });
                  },
                ),
              ),

              const SizedBox(width: 16),

              // 年齡組別篩選
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: '年齡組別',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedAgeGroup ?? '全部',
                  items: _ageGroups
                      .map((ageGroup) => DropdownMenuItem(
                            value: ageGroup,
                            child: Text(ageGroup),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedAgeGroup = value;
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 應用篩選按鈕
          Center(
            child: ElevatedButton.icon(
              onPressed: _applyFilters,
              icon: const Icon(Icons.filter_list),
              label: const Text('應用篩選'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 統計數據卡片
  Widget _buildStatisticsCard() {
    final min = _statistics['min'];
    final max = _statistics['max'];
    final avg = _statistics['average'];
    final median = _statistics['median'];

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
                '統計摘要 - $_selectedEvent',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // 添加導出按鈕
              TextButton.icon(
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('導出報告'),
                onPressed: _exportResults,
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
              _buildStatItem(
                  '最佳成績',
                  max is int
                      ? '${_formatTime(max)}'
                      : '${max?.toStringAsFixed(2) ?? "N/A"}'),
              _buildStatItem(
                  '平均成績',
                  avg is int
                      ? '${_formatTime(avg)}'
                      : '${avg?.toStringAsFixed(2) ?? "N/A"}'),
              _buildStatItem(
                  '中位數',
                  median is int
                      ? '${_formatTime(median)}'
                      : '${median?.toStringAsFixed(2) ?? "N/A"}'),
              _buildStatItem(
                  '最低成績',
                  min is int
                      ? '${_formatTime(min)}'
                      : '${min?.toStringAsFixed(2) ?? "N/A"}'),
            ],
          ),
        ],
      ),
    );
  }

  // 統計數據項
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

  // 成績分佈圖
  Widget _buildDistributionChart() {
    // 判斷項目類型
    final isTrackEvent =
        _eventResults.isNotEmpty && _eventResults.first.time != null;

    if (isTrackEvent) {
      return _buildTimeDistributionChart();
    } else {
      return _buildScoreDistributionChart();
    }
  }

  // 徑賽成績分佈圖 (時間)
  Widget _buildTimeDistributionChart() {
    // 按成績排序
    final sortedResults = [..._eventResults];
    sortedResults.sort((a, b) => a.time!.compareTo(b.time!));

    // 生成圖表數據
    final spots = sortedResults.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.time!.toDouble());
    }).toList();

    // 計算y軸範圍
    final maxY =
        (sortedResults.isNotEmpty ? sortedResults.last.time! * 1.1 : 1000)
            .toDouble();
    final minY =
        (sortedResults.isNotEmpty ? sortedResults.first.time! * 0.9 : 0)
            .toDouble();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value % 5 == 0 && value < sortedResults.length) {
                    return Text(
                      sortedResults[value.toInt()].athleteName.substring(0, 2),
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    _formatTime(value.toInt()),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          minX: 0,
          maxX: (sortedResults.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: Colors.blue,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  // 田賽成績分佈圖 (距離/高度)
  Widget _buildScoreDistributionChart() {
    // 按成績排序
    final sortedResults = [..._eventResults];
    sortedResults.sort((a, b) => b.score!.compareTo(a.score!)); // 田賽是越大越好

    // 生成圖表數據
    final spots = sortedResults.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.score!);
    }).toList();

    // 計算y軸範圍
    final maxY =
        (sortedResults.isNotEmpty ? sortedResults.first.score! * 1.1 : 10)
            .toDouble();
    final minY =
        (sortedResults.isNotEmpty ? sortedResults.last.score! * 0.9 : 0)
            .toDouble();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value % 5 == 0 && value < sortedResults.length) {
                    return Text(
                      sortedResults[value.toInt()].athleteName.substring(0, 2),
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          minX: 0,
          maxX: (sortedResults.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: Colors.green,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  // 排名表
  Widget _buildRankingTable() {
    // 確定是否是徑賽 (有時間記錄的)
    final isTrackEvent =
        _eventResults.isNotEmpty && _eventResults.first.time != null;

    // 排序結果
    final sortedResults = [..._eventResults];
    if (isTrackEvent) {
      // 徑賽 - 按時間升序排序 (越小越好)
      sortedResults.sort((a, b) => a.time!.compareTo(b.time!));
    } else {
      // 田賽 - 按分數降序排序 (越大越好)
      sortedResults.sort((a, b) => b.score!.compareTo(a.score!));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 標題
          Text(
            '$_selectedEvent 排名表',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // 數據表格
          DataTable(
            columns: [
              const DataColumn(label: Text('排名')),
              const DataColumn(label: Text('姓名')),
              const DataColumn(label: Text('學校')),
              DataColumn(label: Text(isTrackEvent ? '時間' : '成績')),
            ],
            rows: sortedResults.asMap().entries.map((entry) {
              final index = entry.key;
              final result = entry.value;

              return DataRow(cells: [
                DataCell(Text('${index + 1}')),
                DataCell(Text(result.athleteName)),
                DataCell(Text(result.school ?? '')),
                DataCell(Text(isTrackEvent
                    ? _formatTime(result.time!)
                    : '${result.score!.toStringAsFixed(2)}m')),
              ]);
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 格式化時間 (從百分之一秒轉換為分:秒.毫秒格式)
  String _formatTime(int centiseconds) {
    final totalSeconds = centiseconds ~/ 100;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final remainingCentiseconds = centiseconds % 100;

    return '${minutes > 0 ? '$minutes:' : ''}${seconds.toString().padLeft(2, '0')}.${remainingCentiseconds.toString().padLeft(2, '0')}';
  }

  // 添加導出報告方法
  void _exportResults() {
    if (_selectedEvent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先選擇一個項目')),
      );
      return;
    }

    if (_eventResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('沒有可導出的數據')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在生成報告...')),
    );

    // 使用導出服務
    final exportService = StatisticsExportService();
    exportService.exportEventResultsToPdf(
      context: context,
      competitionName: widget.competitionName,
      eventName: _selectedEvent!,
      results: _eventResults,
      statistics: _statistics,
    );
  }
}
