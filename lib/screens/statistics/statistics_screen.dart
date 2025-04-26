import 'package:flutter/material.dart';
import 'performance_analysis.dart';
import 'team_performance.dart';
import 'development_roadmap.dart';

class StatisticsScreen extends StatefulWidget {
  final String competitionId;
  final String competitionName;
  final String? statisticType; // 可選參數，用於直接跳轉到特定的分析類型

  const StatisticsScreen({
    Key? key,
    required this.competitionId,
    required this.competitionName,
    this.statisticType,
  }) : super(key: key);

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['成績分析', '隊伍表現'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    // 如果有指定的統計類型，直接切換到對應的標籤
    if (widget.statisticType != null) {
      int index = -1;
      if (widget.statisticType == '成績排名與分析') {
        index = 0;
      } else if (widget.statisticType == '校際表現分析') {
        index = 1;
      }

      if (index >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _tabController.animateTo(index);
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.competitionName} - 數據分析'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((title) => Tab(text: title)).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '查看開發路線圖',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StatisticsDevelopmentRoadmap(),
                ),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 成績分析
          PerformanceAnalysisScreen(
            competitionId: widget.competitionId,
            competitionName: widget.competitionName,
          ),
          // 隊伍表現
          TeamPerformanceScreen(
            competitionId: widget.competitionId,
            competitionName: widget.competitionName,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showStatisticsOptions,
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.view_module),
        tooltip: '更多統計選項',
      ),
    );
  }

  // 顯示統計選項對話框
  void _showStatisticsOptions() {
    showDialog(
      context: context,
      builder: (context) => StatisticsOptionsDialog(
        competitionId: widget.competitionId,
        competitionName: widget.competitionName,
        onOptionSelected: (type) {
          if (type == '成績排名與分析') {
            _tabController.animateTo(0);
          } else if (type == '校際表現分析') {
            _tabController.animateTo(1);
          } else {
            // 其他尚未實現的功能
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$type 功能正在開發中，敬請期待')),
            );
          }
        },
      ),
    );
  }
}

// 統計選項對話框
class StatisticsOptionsDialog extends StatelessWidget {
  final String competitionId;
  final String competitionName;
  final Function(String) onOptionSelected;

  const StatisticsOptionsDialog({
    Key? key,
    required this.competitionId,
    required this.competitionName,
    required this.onOptionSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.bar_chart, color: Colors.indigo),
          SizedBox(width: 8),
          Text('賽事數據統計分析'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('選擇要查看的數據類型：'),
            SizedBox(height: 16),

            // 成績排名與分析
            _buildStatisticOption(
              context,
              icon: Icons.emoji_events,
              title: '成績排名與分析',
              subtitle: '查看各項目成績分佈、最佳表現等統計',
              isImplemented: true,
            ),
            Divider(),

            // 參與人數統計
            _buildStatisticOption(
              context,
              icon: Icons.people,
              title: '參與人數統計',
              subtitle: '各項目參與人數、男女比例、年齡分佈等',
              isImplemented: false,
            ),
            Divider(),

            // 校際表現分析
            _buildStatisticOption(
              context,
              icon: Icons.school,
              title: '校際表現分析',
              subtitle: '不同隊伍在各項目的總體表現比較',
              isImplemented: true,
            ),
            Divider(),

            // 歷史數據比較
            _buildStatisticOption(
              context,
              icon: Icons.history,
              title: '歷史數據比較',
              subtitle: '與往屆比賽數據的對比分析',
              isImplemented: false,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('關閉'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StatisticsDevelopmentRoadmap(),
              ),
            );
          },
          child: Text('查看開發計劃'),
        ),
      ],
    );
  }

  // 構建統計選項
  Widget _buildStatisticOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isImplemented,
  }) {
    return InkWell(
      onTap: isImplemented
          ? () {
              Navigator.pop(context); // 關閉對話框
              onOptionSelected(title);
            }
          : null,
      child: Opacity(
        opacity: isImplemented ? 1.0 : 0.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Icon(icon, color: Colors.indigo),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isImplemented) Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
