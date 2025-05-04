import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// 處理年齡組別的工具類
/// 提供統一的年齡組別處理邏輯，確保數據一致性
class AgeGroupHandler {
  /// 從競賽元數據中加載年齡組別
  static List<Map<String, dynamic>> loadAgeGroupsFromMetadata(
      Map<String, dynamic>? metadata) {
    List<Map<String, dynamic>> ageGroups = [];
    bool hasFoundData = false;

    try {
      if (metadata != null) {
        // 先檢查標準位置 metadata['age_groups']
        if (metadata['age_groups'] != null) {
          final dynamic ageGroupsData = metadata['age_groups'];
          hasFoundData = true;
          debugPrint('📋 找到age_groups數據: $ageGroupsData');

          if (ageGroupsData is List) {
            for (var item in ageGroupsData) {
              if (item is Map<String, dynamic>) {
                // 兼容不同的字段名稱
                final startAge = item['startAge'] ?? item['minAge'] ?? 0;
                final endAge = item['endAge'] ?? item['maxAge'] ?? 0;

                ageGroups.add({
                  'name': item['name'] ?? '未命名',
                  'startAge': startAge,
                  'endAge': endAge,
                });
              }
            }
          } else if (ageGroupsData is Map<String, dynamic>) {
            ageGroupsData.forEach((key, value) {
              if (value is Map<String, dynamic>) {
                // 兼容不同的字段名稱
                final startAge = value['startAge'] ?? value['minAge'] ?? 0;
                final endAge = value['endAge'] ?? value['maxAge'] ?? 0;

                ageGroups.add({
                  'name': value['name'] ?? '未命名',
                  'startAge': startAge,
                  'endAge': endAge,
                });
              }
            });
          }
        }
        // 備用位置 metadata['ageGroups'] (camelCase)
        else if (metadata['ageGroups'] != null) {
          final dynamic ageGroupsData = metadata['ageGroups'];
          hasFoundData = true;
          debugPrint('📋 找到ageGroups數據 (camelCase): $ageGroupsData');

          if (ageGroupsData is List) {
            for (var item in ageGroupsData) {
              if (item is Map<String, dynamic>) {
                // 兼容不同的字段名稱
                final startAge = item['startAge'] ?? item['minAge'] ?? 0;
                final endAge = item['endAge'] ?? item['maxAge'] ?? 0;

                ageGroups.add({
                  'name': item['name'] ?? '未命名',
                  'startAge': startAge,
                  'endAge': endAge,
                });
              }
            }
          } else if (ageGroupsData is Map<String, dynamic>) {
            ageGroupsData.forEach((key, value) {
              if (value is Map<String, dynamic>) {
                // 兼容不同的字段名稱
                final startAge = value['startAge'] ?? value['minAge'] ?? 0;
                final endAge = value['endAge'] ?? value['maxAge'] ?? 0;

                ageGroups.add({
                  'name': value['name'] ?? '未命名',
                  'startAge': startAge,
                  'endAge': endAge,
                });
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('處理年齡組別時出錯: $e');
    }

    // 調試輸出
    if (ageGroups.isNotEmpty) {
      debugPrint('✅ 已成功解析年齡組別: $ageGroups');
    } else if (hasFoundData) {
      debugPrint('⚠️ 找到年齡組別數據，但無法解析有效內容');
    } else {
      debugPrint('⚠️ 未找到年齡組別數據，將使用默認值');
    }

    // 如果沒有數據，添加默認組別
    if (ageGroups.isEmpty && !hasFoundData) {
      ageGroups = getDefaultAgeGroups();
      debugPrint('📋 使用默認年齡組別: $ageGroups');
    }

    return ageGroups;
  }

  /// 獲取默認的年齡組別
  static List<Map<String, dynamic>> getDefaultAgeGroups() {
    return [
      {
        'name': '少年組',
        'startAge': 7,
        'endAge': 9,
      },
      {
        'name': '兒童組',
        'startAge': 10,
        'endAge': 12,
      },
      {
        'name': '青少年組',
        'startAge': 13,
        'endAge': 15,
      },
      {
        'name': '青年組',
        'startAge': 16,
        'endAge': 18,
      }
    ];
  }

  /// 將年齡組別轉換為顯示用字符串
  static String convertAgeGroupsToDisplay(
      List<Map<String, dynamic>> ageGroups) {
    if (ageGroups.isEmpty) return '未設置';
    return ageGroups.map((g) => g['name'].toString()).join(', ');
  }

  /// 顯示年齡組別編輯對話框
  static Future<List<Map<String, dynamic>>?> showAgeGroupsDialog(
      BuildContext context, List<Map<String, dynamic>> currentAgeGroups) async {
    return await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => _buildAgeGroupsDialog(context, currentAgeGroups),
    );
  }

  /// 構建年齡組別編輯對話框
  static Widget _buildAgeGroupsDialog(
      BuildContext context, List<Map<String, dynamic>> initialAgeGroups) {
    // 初始化年齡分組數據
    List<Map<String, dynamic>> ageGroups = List.from(initialAgeGroups);
    if (ageGroups.isEmpty) {
      ageGroups = getDefaultAgeGroups();
    }

    // 為每個組別創建控制器
    List<TextEditingController> nameControllers = [];
    List<TextEditingController> startAgeControllers = [];
    List<TextEditingController> endAgeControllers = [];

    for (var group in ageGroups) {
      String name = group['name'] ?? "未命名組";
      int startAge = group['startAge'] ?? 7;
      int endAge = group['endAge'] ?? 18;

      nameControllers.add(TextEditingController(text: name));
      startAgeControllers.add(TextEditingController(text: startAge.toString()));
      endAgeControllers.add(TextEditingController(text: endAge.toString()));
    }

    return StatefulBuilder(
      builder: (context, setState) {
        // 添加組別函數
        void addAgeGroup() {
          setState(() {
            ageGroups.add({'name': '未命名組', 'startAge': null, 'endAge': null});
            nameControllers.add(TextEditingController(text: '未命名組'));
            startAgeControllers.add(TextEditingController());
            endAgeControllers.add(TextEditingController());
          });
        }

        // 刪除組別函數
        void removeAgeGroup(int index) {
          if (ageGroups.length > 1) {
            setState(() {
              ageGroups.removeAt(index);
              nameControllers.removeAt(index);
              startAgeControllers.removeAt(index);
              endAgeControllers.removeAt(index);
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('至少需要保留一個年齡組別'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }

        return AlertDialog(
          title: const Text('設置年齡分組'),
          scrollable: true,
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('請為每個年齡組設置名稱、起始和結束年齡'),
                const SizedBox(height: 16),
                ...ageGroups.asMap().entries.map((entry) {
                  final index = entry.key;
                  final group = entry.value;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '組別 ${index + 1}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => removeAgeGroup(index),
                                tooltip:
                                    ageGroups.length > 1 ? '刪除此組別' : '至少需要一個組別',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: '組別名稱',
                              border: OutlineInputBorder(),
                              helperText: '例如: 少年組、青年組',
                            ),
                            controller: nameControllers[index],
                            onChanged: (value) {
                              setState(() {
                                ageGroups[index]['name'] = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: '起始年齡',
                                    border: OutlineInputBorder(),
                                    helperText: '例如: 7',
                                  ),
                                  keyboardType: TextInputType.number,
                                  controller: startAgeControllers[index],
                                  onChanged: (value) {
                                    if (value.isNotEmpty) {
                                      try {
                                        setState(() {
                                          ageGroups[index]['startAge'] =
                                              int.parse(value);
                                        });
                                      } catch (_) {}
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text('至', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: '結束年齡',
                                    border: OutlineInputBorder(),
                                    helperText: '例如: 9',
                                  ),
                                  keyboardType: TextInputType.number,
                                  controller: endAgeControllers[index],
                                  onChanged: (value) {
                                    if (value.isNotEmpty) {
                                      try {
                                        setState(() {
                                          ageGroups[index]['endAge'] =
                                              int.parse(value);
                                        });
                                      } catch (_) {}
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (group['name'] != null &&
                              group['startAge'] != null &&
                              group['endAge'] != null)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '預覽: ${group['name']} (${group['startAge']}-${group['endAge']}歲)',
                                style: const TextStyle(color: Colors.blue),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('添加年齡組別'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 24),
                  ),
                  onPressed: addAgeGroup,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                // 驗證並轉換年齡分組
                final List<Map<String, dynamic>> validGroups = [];

                for (int i = 0; i < ageGroups.length; i++) {
                  final name = nameControllers[i].text.trim();
                  final startAgeText = startAgeControllers[i].text.trim();
                  final endAgeText = endAgeControllers[i].text.trim();

                  final startAge = int.tryParse(startAgeText);
                  final endAge = int.tryParse(endAgeText);

                  if (name.isNotEmpty && startAge != null && endAge != null) {
                    validGroups.add({
                      'name': name,
                      'startAge': startAge,
                      'endAge': endAge,
                    });
                  }
                }

                // 檢查是否至少有一個有效組別
                if (validGroups.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('請至少設置一個有效的年齡分組'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }

                Navigator.pop(context, validGroups);
              },
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }

  /// 根據年齡獲取適合的年齡組別
  static String? getAgeGroup(int age, List<Map<String, dynamic>> ageGroups) {
    for (var group in ageGroups) {
      int? startAge = group['startAge'] as int?;
      int? endAge = group['endAge'] as int?;

      if (startAge != null && endAge != null) {
        if (age >= startAge && age <= endAge) {
          return group['name'] as String?;
        }
      }
    }
    return null;
  }

  /// 計算年齡
  static int calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }
}
