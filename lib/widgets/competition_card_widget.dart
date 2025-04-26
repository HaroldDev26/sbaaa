import 'package:flutter/material.dart';
import '../models/competition_model.dart';
import 'package:intl/intl.dart';
import '../utils/age_group_handler.dart'; // 導入年齡分組處理工具

class CompetitionCardWidget extends StatelessWidget {
  final CompetitionModel competition;
  final Function() onTap;
  final Function() onRegisterTap;
  final Function()? onViewRegistrationTap;
  final bool isLoadingRegistration;

  const CompetitionCardWidget({
    Key? key,
    required this.competition,
    required this.onTap,
    required this.onRegisterTap,
    this.onViewRegistrationTap,
    this.isLoadingRegistration = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 計算報名狀態
    bool hasRegistered = competition.alreadyRegistered == true;
    bool isDeadlinePassed = competition.isDeadlinePassed == true;
    bool hasRegistrationForm = competition.hasRegistrationForm == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 比賽頭部信息
            _buildHeader(),

            // 比賽基本信息
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 比賽名稱
                  Text(
                    competition.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // 比賽描述
                  Text(
                    competition.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // 比賽時間和地點
                  _buildInfoRow(
                    Icons.calendar_today,
                    _formatDate(competition.startDate),
                  ),
                  const SizedBox(height: 4),
                  _buildInfoRow(
                    Icons.location_on,
                    competition.venue ?? '未設置場地',
                  ),

                  // 顯示年齡組別
                  if (competition.metadata != null &&
                      competition.metadata!.containsKey('ageGroups')) ...[
                    const SizedBox(height: 4),
                    _buildAgeGroups(),
                  ],

                  // 報名按鈕
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: hasRegistered
                          ? onViewRegistrationTap
                          : (!isDeadlinePassed && hasRegistrationForm)
                              ? onRegisterTap
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasRegistered
                            ? Colors.green
                            : isDeadlinePassed
                                ? Colors.grey
                                : Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        hasRegistered
                            ? '查看報名'
                            : isDeadlinePassed
                                ? '已截止報名'
                                : !hasRegistrationForm
                                    ? '尚未開放報名'
                                    : '立即報名',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 構建頭部背景
  Widget _buildHeader() {
    Color statusColor;
    switch (competition.status) {
      case '計劃中':
        statusColor = Colors.blue;
        break;
      case '進行中':
        statusColor = Colors.green;
        break;
      case '已結束':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.7),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左側：狀態
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(competition.status),
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  competition.status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // 右側：報名狀態
          if (competition.registrationDeadline != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: competition.isDeadlinePassed
                    ? Colors.red.withOpacity(0.3)
                    : Colors.green.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                competition.isDeadlinePassed
                    ? '已截止'
                    : '截止: ${_formatDate(competition.registrationDeadline!.toString())}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 構建信息行
  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // 獲取狀態對應的圖標
  IconData _getStatusIcon(String status) {
    switch (status) {
      case '計劃中':
        return Icons.event_available;
      case '進行中':
        return Icons.play_circle_fill;
      case '已結束':
        return Icons.event_busy;
      default:
        return Icons.help_outline;
    }
  }

  // 格式化日期
  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // 構建年齡組別
  Widget _buildAgeGroups() {
    // 使用AgeGroupHandler加載年齡組別
    final ageGroups =
        AgeGroupHandler.loadAgeGroupsFromMetadata(competition.metadata);
    if (ageGroups.isEmpty) {
      return const SizedBox.shrink();
    }

    // 轉換為顯示文本
    final displayText = AgeGroupHandler.convertAgeGroupsToDisplay(ageGroups);

    return _buildInfoRow(
      Icons.people,
      '年齡組別: $displayText',
    );
  }
}
