import 'package:flutter/material.dart';

class StatisticsDevelopmentRoadmap extends StatelessWidget {
  const StatisticsDevelopmentRoadmap({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('數據統計功能開發計劃'),
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildCurrentStatus(),
            const SizedBox(height: 24),
            _buildRoadmap(),
            const SizedBox(height: 24),
            _buildImplementationDetails(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '數據統計功能開發路線圖',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '本文檔說明目前已實現的數據統計功能以及未來的發展計劃',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('目前已實現功能'),
        const SizedBox(height: 16),
        _buildFeatureCard(
          title: '成績分析',
          icon: Icons.emoji_events,
          color: Colors.amber,
          features: [
            '項目成績列表和排名',
            '成績分佈圖表（最高、最低、平均）',
            '按性別和年齡組別篩選',
            '徑賽和田賽不同的數據顯示',
          ],
        ),
        const SizedBox(height: 16),
        _buildFeatureCard(
          title: '隊伍表現分析',
          icon: Icons.school,
          color: Colors.indigo,
          features: [
            '學校/隊伍總分排行榜',
            '獎牌數量統計和圖表',
            '按項目篩選隊伍表現',
            '隊伍得分比較圖表',
          ],
        ),
      ],
    );
  }

  Widget _buildRoadmap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('開發路線圖'),
        const SizedBox(height: 16),
        _buildTimelineItem(
          phase: '第一階段 (當前)',
          title: '基礎統計功能',
          description: '完善成績排名與隊伍表現的基本統計功能',
          isCompleted: true,
        ),
        _buildTimelineItem(
          phase: '第二階段',
          title: '參與人數統計',
          description: '添加參與人數分析，包括各項目參與人數、男女比例、年齡分佈等統計',
          isCompleted: false,
        ),
        _buildTimelineItem(
          phase: '第三階段',
          title: '數據匯出與分享',
          description: '實現數據匯出為PDF/Excel格式，以及社交媒體分享功能',
          isCompleted: false,
        ),
        _buildTimelineItem(
          phase: '第四階段',
          title: '歷史數據比較',
          description: '實現與往屆比賽的數據對比，分析進步情況和趨勢',
          isCompleted: false,
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildImplementationDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('技術實現計劃'),
        const SizedBox(height: 16),
        _buildImplementationCard(
          title: '數據處理優化',
          description: '計劃在後端預處理統計數據，減輕客戶端運算負擔。實現數據快取機制，定期計算並存儲統計結果',
        ),
        const SizedBox(height: 16),
        _buildImplementationCard(
          title: '圖表視覺化增強',
          description: '升級 fl_chart 圖表庫，添加更多互動功能，如點擊查看詳情、縮放和平移等',
        ),
        const SizedBox(height: 16),
        _buildImplementationCard(
          title: '實時數據更新',
          description: '實現成績錄入後統計數據的實時更新，提高數據分析的時效性',
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights, color: Colors.indigo),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> features,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(feature)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem({
    required String phase,
    required String title,
    required String description,
    required bool isCompleted,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green : Colors.grey[400],
                shape: BoxShape.circle,
              ),
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 50,
                color: isCompleted ? Colors.green : Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                phase,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? Colors.green : Colors.indigo,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImplementationCard({
    required String title,
    required String description,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
