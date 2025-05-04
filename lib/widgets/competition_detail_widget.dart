import 'package:flutter/material.dart';
import '../models/competition_model.dart';
import 'package:intl/intl.dart';
import '../utils/age_group_handler.dart'; // 導入年齡分組處理工具

// 定義比賽報名狀態枚舉
enum RegistrationStatus {
  registered, // 已報名
  open, // 開放報名
  closed, // 已截止
  notAvailable // 尚未開放
}

class CompetitionDetailWidget extends StatelessWidget {
  final CompetitionModel competition;
  final Function() onRegisterTap;
  final Function()? onViewRegistrationTap;
  final bool isLoadingRegistration;

  const CompetitionDetailWidget({
    Key? key,
    required this.competition,
    required this.onRegisterTap,
    this.onViewRegistrationTap,
    this.isLoadingRegistration = false,
  }) : super(key: key);

  // 獲取報名狀態
  RegistrationStatus get registrationStatus {
    if (competition.alreadyRegistered == true) {
      return RegistrationStatus.registered;
    }
    if (competition.isDeadlinePassed == true) return RegistrationStatus.closed;
    if (competition.hasRegistrationForm != true) {
      return RegistrationStatus.notAvailable;
    }
    return RegistrationStatus.open;
  }

  // 獲取報名狀態顏色
  Color getRegistrationStatusColor() {
    switch (registrationStatus) {
      case RegistrationStatus.registered:
        return Colors.green;
      case RegistrationStatus.open:
        return Colors.blue;
      case RegistrationStatus.closed:
        return Colors.red;
      case RegistrationStatus.notAvailable:
        return Colors.orange;
    }
  }

  // 獲取報名狀態文字
  String getRegistrationStatusText() {
    switch (registrationStatus) {
      case RegistrationStatus.registered:
        return '已報名';
      case RegistrationStatus.open:
        return '開放報名中';
      case RegistrationStatus.closed:
        return '報名已截止';
      case RegistrationStatus.notAvailable:
        return '尚未開放報名';
    }
  }

  // 獲取報名狀態圖標
  IconData getRegistrationStatusIcon() {
    switch (registrationStatus) {
      case RegistrationStatus.registered:
        return Icons.check_circle;
      case RegistrationStatus.open:
        return Icons.sports;
      case RegistrationStatus.closed:
        return Icons.warning_amber;
      case RegistrationStatus.notAvailable:
        return Icons.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 簡化事件列表獲取
    List<String> events =
        competition.events?.map((event) => event.toString()).toList() ?? [];

    // 確保錯誤處理
    if (events.isEmpty) {
      debugPrint('沒有可用的比賽項目');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderBanner(),
        const SizedBox(height: 24),
        _buildRegistrationStatusIndicator(getRegistrationStatusColor()),
        const SizedBox(height: 20),
        _buildInfoSection(_formatDeadlineText()),
        const SizedBox(height: 24),
        _buildActionButtons(),
      ],
    );
  }

  // 頂部橫幅區域
  Widget _buildHeaderBanner() {
    Color defaultColor = Colors.blue; // 使用默認顏色

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            defaultColor.withValues(alpha: 0.7),
            defaultColor.withValues(alpha: 0.2),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 比賽名稱
          Text(
            competition.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          // 比賽描述
          Text(
            competition.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 報名狀態指示器
  Widget _buildRegistrationStatusIndicator(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            getRegistrationStatusIcon(),
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  getRegistrationStatusText(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (competition.registrationDeadline != null &&
                    registrationStatus == RegistrationStatus.open)
                  Text(
                    '截止日期: ${DateFormat('yyyy-MM-dd').format(competition.registrationDeadline!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
          if (registrationStatus == RegistrationStatus.open)
            _buildRemainingDaysIndicator(),
        ],
      ),
    );
  }

  // 剩餘天數指示器
  Widget _buildRemainingDaysIndicator() {
    if (competition.registrationDeadline == null) {
      return const SizedBox.shrink();
    }

    final daysRemaining =
        competition.registrationDeadline!.difference(DateTime.now()).inDays;

    if (daysRemaining < 0) return const SizedBox.shrink();

    Color color = daysRemaining <= 2
        ? Colors.red
        : daysRemaining <= 7
            ? Colors.orange
            : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        daysRemaining == 0 ? '今天截止!' : '剩$daysRemaining天',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }

  // 信息區域
  Widget _buildInfoSection(String? deadlineText) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.indigo.shade700),
              const SizedBox(width: 8),
              const Text(
                '比賽信息',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // 基本信息卡片
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '基本資料',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1A237E),
                  ),
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                    Icons.location_on, '比賽場地', competition.venue ?? '未設置'),
                const SizedBox(height: 8),
                _buildDetailRow(Icons.calendar_today, '開始日期',
                    _formatDate(competition.startDate)),
                const SizedBox(height: 8),
                _buildDetailRow(
                    Icons.event_note, '結束日期', _formatDate(competition.endDate)),
                const SizedBox(height: 8),
                _buildDetailRow(Icons.person, '組織者', competition.createdBy),

                // 直接在基本資料卡片中顯示可報名項目
                if (competition.events != null &&
                    competition.events!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.sports, size: 18, color: Colors.blue.shade800),
                      const SizedBox(width: 8),
                      Text(
                        '可報名項目',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: competition.events!.map<Widget>((dynamic event) {
                      String eventName = event.toString();
                      return Chip(
                        label: Text(eventName),
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 13,
                        ),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.blue.shade100),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 報名信息卡片
          if (deadlineText != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: competition.isDeadlinePassed
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '報名資訊',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: competition.isDeadlinePassed
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.timer, '報名截止日期', deadlineText,
                      competition.isDeadlinePassed ? Colors.red : Colors.green),
                  if (!competition.isDeadlinePassed) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '報名仍在進行中，請盡快完成報名!',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 16),

          // 額外信息（如果有）
          if (competition.metadata != null) ...[
            const SizedBox(height: 16),
            _buildExtraInfo(),
          ],
        ],
      ),
    );
  }

  // 詳細信息行
  Widget _buildDetailRow(IconData icon, String label, String value,
      [Color? valueColor]) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        SizedBox(
          width: 75,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor ?? const Color(0xFF333333),
            ),
          ),
        ),
      ],
    );
  }

  // 將ISO日期格式化為更易讀的形式
  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  // 額外信息區域
  Widget _buildExtraInfo() {
    List<Widget> extraInfoWidgets = [];

    // 提取並顯示年齡組別信息
    if (competition.metadata != null &&
        competition.metadata!.containsKey('ageGroups')) {
      // 使用AgeGroupHandler提取年齡組別數據
      final ageGroups =
          AgeGroupHandler.loadAgeGroupsFromMetadata(competition.metadata);

      if (ageGroups.isNotEmpty) {
        extraInfoWidgets.add(
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.people, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Text(
                      '年齡分組',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ageGroups.map((group) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        '${group['name']} (${group['startAge']}-${group['endAge']}歲)',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      }
    }

    // 檢查是否有備註信息
    if (competition.metadata!.containsKey('notes')) {
      final notes = competition.metadata!['notes'];
      if (notes != null && notes.toString().isNotEmpty) {
        extraInfoWidgets.add(
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sticky_note_2, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    Text(
                      '重要備註',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  notes.toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // 添加其他重要的元數據
    final importantKeys = ['category', 'organizer', 'contact_info'];
    Map<String, IconData> keyIcons = {
      'category': Icons.category,
      'organizer': Icons.business,
      'contact_info': Icons.contact_phone,
    };

    for (var key in importantKeys) {
      if (competition.metadata!.containsKey(key) &&
          competition.metadata![key] != null &&
          competition.metadata![key].toString().isNotEmpty) {
        final value = competition.metadata![key].toString();
        final icon = keyIcons[key] ?? Icons.info_outline;
        final label = key == 'category'
            ? '比賽類別'
            : key == 'organizer'
                ? '主辦單位'
                : key == 'contact_info'
                    ? '聯絡資訊'
                    : key;

        if (extraInfoWidgets.isNotEmpty) {
          extraInfoWidgets.add(const SizedBox(height: 12));
        }

        extraInfoWidgets.add(_buildMetadataItem(icon, label, value));
      }
    }

    if (extraInfoWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: extraInfoWidgets,
    );
  }

  // 元數據項目
  Widget _buildMetadataItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 底部按鈕區域
  Widget _buildActionButtons() {
    // 根據報名狀態顯示不同按鈕
    switch (registrationStatus) {
      case RegistrationStatus.registered:
        return _buildRegisteredAction();
      case RegistrationStatus.closed:
        return _buildClosedAction();
      case RegistrationStatus.notAvailable:
        return _buildNotAvailableAction();
      case RegistrationStatus.open:
        return _buildOpenAction();
    }
  }

  // 已報名狀態的操作區
  Widget _buildRegisteredAction() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text(
                '您已成功報名此比賽',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onViewRegistrationTap,
              icon: const Icon(Icons.visibility),
              label: const Text('查看已提交報名表'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 已截止狀態的操作區
  Widget _buildClosedAction() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber, color: Colors.red),
              SizedBox(width: 8),
              Text(
                '報名已截止',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: null, // 禁用按鈕
              icon: const Icon(Icons.block),
              label: const Text('無法報名'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 未開放狀態的操作區
  Widget _buildNotAvailableAction() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pending, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                '報名表尚未開放',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: null, // 禁用按鈕
              icon: const Icon(Icons.timelapse),
              label: const Text('稍後開放報名'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 開放報名狀態的操作區
  Widget _buildOpenAction() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sports, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                '立即報名參賽',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: isLoadingRegistration ? null : onRegisterTap,
              icon: isLoadingRegistration
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.app_registration),
              label: Text(isLoadingRegistration ? '處理中...' : '開始報名'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1446),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 格式化截止日期文本
  String? _formatDeadlineText() {
    if (competition.registrationDeadline == null) return null;
    return DateFormat('yyyy-MM-dd').format(competition.registrationDeadline!);
  }
}
