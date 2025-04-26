import 'package:flutter/material.dart';

/// 處理比賽項目的工具類
/// 提供統一的比賽項目處理邏輯，確保數據一致性
class EventsHandler {
  /// 從競賽元數據中加載比賽項目
  static List<Map<String, dynamic>> loadEventsFromMetadata(
      Map<String, dynamic>? metadata) {
    List<Map<String, dynamic>> events = [];
    try {
      if (metadata != null && metadata['events'] != null) {
        final dynamic eventsData = metadata['events'];

        if (eventsData is List) {
          for (var item in eventsData) {
            if (item is Map<String, dynamic>) {
              events.add({
                'name': item['name'] ?? '未命名',
              });
            }
          }
        } else if (eventsData is Map<String, dynamic>) {
          eventsData.forEach((key, value) {
            if (value is Map<String, dynamic>) {
              events.add({
                'name': value['name'] ?? '未命名',
              });
            }
          });
        }
      }
    } catch (e) {
      debugPrint('處理比賽項目時出錯: $e');
    }

    return events;
  }

  /// 將比賽項目轉換為顯示用字符串
  static String convertEventsToDisplay(List<Map<String, dynamic>> events) {
    if (events.isEmpty) return '未設置';
    return events.map((e) => e['name'].toString()).join(', ');
  }

  /// 從顯示字符串轉換為比賽項目列表
  static List<Map<String, dynamic>> convertDisplayToEvents(String display) {
    if (display.trim().isEmpty) return [];

    return display
        .split(',')
        .where((e) => e.trim().isNotEmpty)
        .map((e) => {
              'name': e.trim(),
            })
        .toList();
  }

  /// 顯示比賽項目編輯對話框
  static Future<String?> showEventsDialog(
      BuildContext context, String initialEvents) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => _buildEventsDialog(context, initialEvents),
    );
  }

  /// 構建比賽項目編輯對話框
  static Widget _buildEventsDialog(BuildContext context, String initialValue) {
    final controller = TextEditingController(text: initialValue);

    return AlertDialog(
      title: const Text('輸入比賽項目'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '請輸入比賽項目，多個項目請用「,」分隔',
              helperText: '例如：100米短跑,400米接力,跨欄,鉛球',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('確定'),
        ),
      ],
    );
  }

  /// 根據事件名稱獲取事件詳細信息
  static Map<String, dynamic>? getEventByName(
      String eventName, List<Map<String, dynamic>> events) {
    for (var event in events) {
      if (event['name'] == eventName) {
        return event;
      }
    }
    return null;
  }
}
