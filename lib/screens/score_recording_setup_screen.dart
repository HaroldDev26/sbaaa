import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScoreRecordingSetupScreen extends StatefulWidget {
  final String competitionId;
  final String competitionName;

  const ScoreRecordingSetupScreen({
    Key? key,
    required this.competitionId,
    required this.competitionName,
  }) : super(key: key);

  @override
  State<ScoreRecordingSetupScreen> createState() =>
      _ScoreRecordingSetupScreenState();
}

class _ScoreRecordingSetupScreenState extends State<ScoreRecordingSetupScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _events = [];

  // 儲存事件類型選擇
  final Map<String, String> _eventTypeSelections = {};

  // 定義事件類型
  final List<String> _eventTypes = [
    '徑賽',
    '田賽',
    '接力',
  ];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  // 顯示提示訊息
  void showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 從Firebase讀取比賽定義的項目
      final competitionDoc = await FirebaseFirestore.instance
          .collection('competitions')
          .doc(widget.competitionId)
          .get();

      if (!competitionDoc.exists) {
        setState(() {
          _isLoading = false;
          _events = [];
        });
        return;
      }

      final competitionData = competitionDoc.data() as Map<String, dynamic>;
      final List<Map<String, dynamic>> eventsList = [];

      // 嘗試從metadata或events欄位獲取項目列表
      if (competitionData.containsKey('metadata') &&
          competitionData['metadata'] != null &&
          competitionData['metadata']['events'] != null) {
        // 從metadata.events讀取
        final events = competitionData['metadata']['events'] as List<dynamic>;
        for (var event in events) {
          if (event is Map<String, dynamic> && event.containsKey('name')) {
            final eventData = {
              'id': event['name'],
              'name': event['name'],
              'ageGroup': event['ageGroup'] ?? '',
              'description': event['description'] ?? '',
            };
            eventsList.add(eventData);

            // 檢查是否已有類型設定
            if (event.containsKey('eventType') && event['eventType'] != null) {
              _eventTypeSelections[event['name']] = event['eventType'];
            }
          }
        }
      } else if (competitionData.containsKey('events')) {
        // 直接從events字段讀取
        final events = competitionData['events'];
        if (events is List) {
          for (var event in events) {
            Map<String, dynamic> eventData = {};
            if (event is Map<String, dynamic>) {
              eventData = {
                'id': event['name'] ?? '未命名項目',
                'name': event['name'] ?? '未命名項目',
                'ageGroup': event['ageGroup'] ?? '',
                'description': event['description'] ?? '',
              };
            } else if (event is String) {
              eventData = {
                'id': event,
                'name': event,
              };
            }

            if (eventData.isNotEmpty) {
              eventsList.add(eventData);
            }
          }
        }
      }

      // 如果仍然沒有找到項目，嘗試從events子集合讀取
      if (eventsList.isEmpty) {
        final eventsSnapshot = await FirebaseFirestore.instance
            .collection('competitions')
            .doc(widget.competitionId)
            .collection('events')
            .get();

        if (eventsSnapshot.docs.isNotEmpty) {
          for (var doc in eventsSnapshot.docs) {
            final eventData = doc.data();
            eventData['id'] = doc.id;
            eventsList.add(eventData);

            // 檢查是否已有類型設定
            if (eventData.containsKey('eventType') &&
                eventData['eventType'] != null) {
              _eventTypeSelections[doc.id] = eventData['eventType'];
            }
          }
        }
      }

      // 加載已保存的事件類型
      final setupSnapshot = await FirebaseFirestore.instance
          .collection('competitions')
          .doc(widget.competitionId)
          .collection('score_setup')
          .doc('event_types')
          .get();

      if (setupSnapshot.exists) {
        final data = setupSnapshot.data();
        if (data != null && data.containsKey('eventTypes')) {
          final Map<String, dynamic> savedTypes = data['eventTypes'];
          savedTypes.forEach((key, value) {
            _eventTypeSelections[key] = value;
          });
        }
      }

      setState(() {
        _events = eventsList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveEventTypes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('competitions')
          .doc(widget.competitionId)
          .collection('score_setup')
          .doc('event_types')
          .set({
        'eventTypes': _eventTypeSelections,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      showSnackBar(context, '項目類型設定已保存');
    } catch (e) {
      showSnackBar(context, '保存項目類型時發生錯誤: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('成績紀錄設定 - ${widget.competitionName}'),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? const Center(child: Text('此比賽尚未定義任何項目'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '為每個比賽項目選擇類型，以便正確記錄成績',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '徑賽：短跑、長跑等計時項目\n田賽：跳高、跳遠、等計量項目\n接力：團體接力項目',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const Divider(height: 32),
                      ..._buildEventTypeSelectors(),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveEventTypes,
                          icon: const Icon(Icons.save),
                          label: const Text('保存設定'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _buildEventTypeSelectors() {
    final List<Widget> widgets = [];

    // 簡單列表顯示所有項目
    for (var event in _events) {
      widgets.add(
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
          child: ListTile(
            title: Text(
              event['name'] ?? '未命名項目',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: event['ageGroup'] != null && event['gender'] != null
                ? Text('${event['ageGroup']} ${event['gender']}組')
                : null,
            trailing: DropdownButton<String>(
              value: _eventTypeSelections[event['id']],
              hint: const Text('選擇類型'),
              underline: Container(height: 1, color: Colors.grey),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _eventTypeSelections[event['id'] as String] = newValue;
                  });
                }
              },
              items: _eventTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
            ),
          ),
        ),
      );
    }

    return widgets;
  }
}
