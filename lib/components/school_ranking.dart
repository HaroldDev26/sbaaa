import 'package:flutter/material.dart';

class SchoolRanking extends StatelessWidget {
  final Map<String, Map<String, int>> schoolRankings; // 包含各組別的學校排名
  final Map<String, int> totalRanking; // 總排名

  const SchoolRanking({
    Key? key,
    required this.schoolRankings,
    required this.totalRanking,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.leaderboard, size: 24, color: Colors.indigo),
                const SizedBox(width: 8),
                const Text(
                  '學校排名',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const Spacer(),
                _buildInfoButton(context),
              ],
            ),
            const Divider(height: 24),
            _buildTotalRanking(),
            const SizedBox(height: 16),
            _buildGroupRankings(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline, size: 20, color: Colors.grey),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('排名計算方式'),
            content: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('一般項目:'),
                  Text('• 金牌：11分'),
                  Text('• 銀牌：9分'),
                  Text('• 銅牌：7分'),
                  Text('• 第四名：5分'),
                  Text('• 第五名：4分'),
                  Text('• 第六名：3分'),
                  Text('• 第七名：2分'),
                  Text('• 第八名：1分'),
                  SizedBox(height: 8),
                  Text('接力項目積分翻倍:'),
                  Text('• 金牌：22分'),
                  Text('• 銀牌：18分'),
                  Text('• 銅牌：14分'),
                  Text('• 第四名：10分'),
                  Text('• 第五名：8分'),
                  Text('• 第六名：6分'),
                  Text('• 第七名：4分'),
                  Text('• 第八名：2分'),
                  SizedBox(height: 8),
                  Text('總排名根據各組別積分總和計算'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('明白了'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTotalRanking() {
    final sortedSchools = totalRanking.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.indigo.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '總排名',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildRankingTable(sortedSchools),
      ],
    );
  }

  Widget _buildGroupRankings() {
    if (schoolRankings.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: schoolRankings.entries.map((entry) {
        final groupName = entry.key;
        final rankingData = entry.value.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$groupName 組別排名',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildRankingTable(rankingData),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildRankingTable(List<MapEntry<String, int>> rankings) {
    // 僅顯示前8名或全部（若少於8名）
    final displayedRankings =
        rankings.length > 8 ? rankings.sublist(0, 8) : rankings;

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(4),
        2: FlexColumnWidth(2),
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
          ),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '排名',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '學校',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '積分',
                style: TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        ...displayedRankings.asMap().entries.map((entry) {
          final index = entry.key;
          final ranking = entry.value;

          Color? medalColor;
          if (index == 0) {
            medalColor = Colors.amber;
          } else if (index == 1) {
            medalColor = Colors.blueGrey;
          } else if (index == 2) {
            medalColor = Colors.brown.shade300;
          }

          return TableRow(
            decoration: BoxDecoration(
              color: index % 2 == 0 ? Colors.grey.withOpacity(0.05) : null,
              border: const Border(
                bottom: BorderSide(color: Colors.grey, width: 0.2),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: medalColor != null
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.emoji_events,
                            color: medalColor,
                            size: 16,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: medalColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        '${index + 1}',
                        textAlign: TextAlign.center,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  ranking.key,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  ranking.value.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: medalColor != null ? FontWeight.bold : null,
                    color: medalColor,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
        if (rankings.length > 8)
          TableRow(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+ ${rankings.length - 8} 間學校',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
      ],
    );
  }
}
