import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../utils/age_group_handler.dart';

class NameListScreen extends StatefulWidget {
  final String competitionId;
  final String competitionName;
  final String? eventName;
  final String? ageGroup;

  const NameListScreen({
    Key? key,
    required this.competitionId,
    required this.competitionName,
    this.eventName,
    this.ageGroup,
  }) : super(key: key);

  @override
  State<NameListScreen> createState() => _NameListScreenState();
}

class _NameListScreenState extends State<NameListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _athletes = [];
  List<List<Map<String, dynamic>>> _groups = [];
  Map<String, dynamic> _competitionData = {};
  String _selectedEvent = '';
  final List<String> _genders = ['男', '女'];
  List<String> _schools = [];

  @override
  void initState() {
    super.initState();
    _loadCompetitionData();
  }

  List<String> get availableAgeGroups {
    final metadata = _competitionData['metadata'];

    final ageGroups = AgeGroupHandler.loadAgeGroupsFromMetadata(metadata);

    final names = ageGroups.map((e) => e['name'].toString()).toList();

    return names;
  }

  // 加載比賽數據
  Future<void> _loadCompetitionData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 獲取比賽數據
      final competitionDoc = await _firestore
          .collection('competitions')
          .doc(widget.competitionId)
          .get();

      if (!mounted) return; // 添加 mounted 檢查

      if (!competitionDoc.exists) {
        setState(() {
          _isLoading = false;
        });
        _showError('找不到比賽數據');
        return;
      }

      _competitionData = competitionDoc.data() as Map<String, dynamic>;

      // 獲取項目列表
      List<String> events = [];
      if (widget.eventName != null && widget.eventName!.isNotEmpty) {
        events = [widget.eventName!];
        _selectedEvent = widget.eventName!;
      } else if (_competitionData.containsKey('metadata') &&
          _competitionData['metadata'] != null &&
          _competitionData['metadata']['events'] != null) {
        final eventsList =
            _competitionData['metadata']['events'] as List<dynamic>;
        for (var event in eventsList) {
          if (event is Map<String, dynamic> && event.containsKey('name')) {
            events.add(event['name'] as String);
          }
        }
        _selectedEvent = events.isNotEmpty ? events.first : '';
      }

      // 獲取所有學校/機構名稱
      await _loadSchools();

      if (!mounted) return; // 添加 mounted 檢查

      // 如果有預設的事件，則加載它
      if (_selectedEvent.isNotEmpty) {
        await _loadAthletesByEvent(_selectedEvent);
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return; // 添加 mounted 檢查

      setState(() {
        _isLoading = false;
      });
      _showError('載入比賽數據時出錯: $e');
    }
  }

  // 從Firebase加載所有已有的學校/機構
  Future<void> _loadSchools() async {
    try {
      Set<String> schoolsSet = {};

      // 從報名記錄中獲取所有學校
      final collectionName = 'competition_${widget.competitionId}';
      final snapshot = await _firestore.collection(collectionName).get();

      if (!mounted) return; // 添加 mounted 檢查

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('school') &&
            data['school'] != null &&
            data['school'].toString().isNotEmpty) {
          schoolsSet.add(data['school'] as String);
        }
      }

      _schools = schoolsSet.toList()..sort();
    } catch (e) {
      debugPrint('加載學校列表出錯: $e');
    }
  }

  // 根據項目加載運動員
  Future<void> _loadAthletesByEvent(String eventName) async {
    setState(() {
      _isLoading = true;
      _selectedEvent = eventName;
    });

    try {
      // 從比賽專屬集合中獲取已核准的運動員
      final collectionName = 'competition_${widget.competitionId}';
      final snapshot = await _firestore
          .collection(collectionName)
          .where('status', isEqualTo: 'approved')
          .get();

      if (!mounted) return; // 添加 mounted 檢查

      List<Map<String, dynamic>> athletes = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        // 不需要打印所有運動員資料，避免日誌過多
        // debugPrint('運動員資料: $data');

        final events = data['events'] as List<dynamic>? ?? [];

        // 篩選參加指定項目的運動員
        if (events.contains(eventName)) {
          // 檢查是否符合年齡組別篩選條件（如果有）
          final athleteAgeGroup = data['ageGroup'] as String? ?? '';
          if (widget.ageGroup == null ||
              widget.ageGroup!.isEmpty ||
              athleteAgeGroup == widget.ageGroup) {
            // 調試輸出 - 檢查性別資料
            String gender = data['gender'] ?? '未知';
            debugPrint(
                '運動員: ${data['userName'] ?? data['teamName']}, 性別: $gender, 原始資料: ${data.containsKey('gender') ? '存在gender欄位' : '缺少gender欄位'}');

            // 檢查是否為接力隊伍
            bool isRelayTeam = data['isRelayTeam'] == true;

            // 從報名資料直接獲取所有資訊
            athletes.add({
              'id': doc.id,
              'name': isRelayTeam
                  ? (data['teamName'] ?? '未命名隊伍')
                  : (data['userName'] ?? '未知'),
              'ageGroup': athleteAgeGroup,
              'school': data['school'] ?? '',
              'gender': data['gender'] ?? '未知',
              'isRelayTeam': isRelayTeam,
              'members': data['members'] ?? [],
              'teamName': data['teamName'], // 專門儲存隊伍名稱
              'athleteNumber': data['athleteNumber'] ??
                  generateAthleteNumber(athletes.length + 1),
            });
          }
        }
      }

      // 對運動員進行排序和分組
      athletes
          .sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
      _athletes = athletes;

      // 分組（每組最多8人）
      _groupAthletes();

      if (!mounted) return; // 添加 mounted 檢查

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('載入運動員出錯: $e');

      if (!mounted) return; // 添加 mounted 檢查

      setState(() {
        _isLoading = false;
      });
      _showError('載入運動員資料時出錯: $e');
    }
  }

  // 生成運動員編號
  String generateAthleteNumber(int index) {
    // 根據索引生成編號，例如A001、A002等
    return 'A${index.toString().padLeft(3, '0')}';
  }

  // 將運動員分組
  void _groupAthletes() {
    _groups = [];
    int groupSize = 8; // 每組最多8人

    // 篩選運動員
    List<Map<String, dynamic>> filteredAthletes = _athletes;

    // 按性別和年齡組別分組
    Map<String, Map<String, List<Map<String, dynamic>>>> genderAgeGroupMap = {
      '男': {},
      '女': {},
    };

    for (var athlete in filteredAthletes) {
      String gender = athlete['gender'];
      String ageGroup = athlete['ageGroup'] ?? '未分組';

      // 確保該性別的Map已初始化
      if (!genderAgeGroupMap.containsKey(gender)) {
        genderAgeGroupMap[gender] = {};
      }

      // 確保該性別下的年齡組別列表已初始化
      if (!genderAgeGroupMap[gender]!.containsKey(ageGroup)) {
        genderAgeGroupMap[gender]![ageGroup] = [];
      }

      // 添加運動員或隊伍到對應的性別和年齡組別
      genderAgeGroupMap[gender]![ageGroup]!.add(athlete);
    }

    // 按特定順序處理性別（先男後女)
    List<String> genderOrder = ['男', '女'];

    for (String gender in genderOrder) {
      if (!genderAgeGroupMap.containsKey(gender)) continue;

      // 處理這個性別的所有年齡組別
      Map<String, List<Map<String, dynamic>>> ageGroups =
          genderAgeGroupMap[gender]!;

      // 對年齡組別進行排序
      List<String> sortedAgeGroups = ageGroups.keys.toList()
        ..sort((a, b) {
          // 嘗試從字符串中提取數字以進行排序
          RegExp regExp = RegExp(r'U(\d+)');
          var matchA = regExp.firstMatch(a);
          var matchB = regExp.firstMatch(b);

          if (matchA != null && matchB != null) {
            return int.parse(matchA.group(1)!)
                .compareTo(int.parse(matchB.group(1)!));
          }
          return a.compareTo(b);
        });

      // 按排序後的順序處理年齡組別
      for (String ageGroup in sortedAgeGroups) {
        List<Map<String, dynamic>> athleteList = ageGroups[ageGroup]!;

        // 對接力隊伍和個人選手進行分開排序
        athleteList.sort((a, b) {
          // 首先按是否為接力隊伍排序
          bool isRelayA = a['isRelayTeam'] == true;
          bool isRelayB = b['isRelayTeam'] == true;

          if (isRelayA != isRelayB) {
            return isRelayA ? -1 : 1; // 接力隊伍排在前面
          }

          // 再按名稱排序
          return a['name'].toString().compareTo(b['name'].toString());
        });

        List<List<Map<String, dynamic>>> genderAgeGroups = [];

        for (int i = 0; i < athleteList.length; i += groupSize) {
          int end = (i + groupSize < athleteList.length)
              ? i + groupSize
              : athleteList.length;

          // 創建包含性別信息的組
          List<Map<String, dynamic>> group = athleteList.sublist(i, end);

          // 為每個運動員添加分組信息
          genderAgeGroups.add(group.map((athlete) {
            Map<String, dynamic> newAthlete = Map.from(athlete);
            newAthlete['groupInfo'] = '$gender $ageGroup';
            return newAthlete;
          }).toList());
        }

        _groups.addAll(genderAgeGroups);
      }
    }
  }

  // 顯示接力隊伍詳情對話框
  void _showRelayTeamDetails(Map<String, dynamic> team) {
    final List<dynamic> members = team['members'] ?? [];
    final String teamName = team['name'] ?? team['teamName'] ?? '未命名隊伍';
    final String teamSchool = team['school'] ?? '';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 標題部分
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: team['gender'] == '男'
                      ? const Color(0xFF0A4FB5)
                      : const Color(0xFFB5306E),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16.0),
                    topRight: Radius.circular(16.0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flag, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            teamName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (teamSchool.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0, left: 28.0),
                        child: Text(
                          teamSchool,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 隊員列表部分
              Flexible(
                child: members.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text(
                            '沒有隊員資料',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: team['gender'] == '男'
                                  ? const Color(0xFF0A4FB5)
                                  : const Color(0xFFB5306E),
                              child: Text('${index + 1}'),
                            ),
                            title: Text(
                              member['name'] ?? '未知隊員',
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              member['school'] ?? member['athleteNumber'] ?? '',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            dense: true,
                          );
                        },
                      ),
              ),

              // 按鈕部分
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('關閉'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditRelayTeamDialog(team);
                      },
                      child: const Text('編輯'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showDeleteRelayTeamDialog(team);
                      },
                      child: const Text('刪除'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 顯示刪除接力隊伍確認對話框
  void _showDeleteRelayTeamDialog(Map<String, dynamic> team) {
    if (!mounted) return; // 添加 mounted 檢查

    final String teamName = team['name'] ?? team['teamName'] ?? '未命名隊伍';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除接力隊伍「$teamName」嗎？此操作不可撤銷。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteRelayTeam(team['id']);
            },
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  // 刪除單個接力隊伍
  Future<void> _deleteRelayTeam(String teamId) async {
    if (teamId.isEmpty) {
      if (!mounted) return; // 添加 mounted 檢查

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無效的隊伍ID')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _firestore
          .collection('competition_${widget.competitionId}')
          .doc(teamId)
          .delete();

      if (!mounted) return; // 添加 mounted 檢查

      // 刪除成功
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('接力隊伍已成功刪除'),
          backgroundColor: Colors.green,
        ),
      );

      // 重新加載數據
      await _loadAthletesByEvent(_selectedEvent);
    } catch (e) {
      if (!mounted) return; // 添加 mounted 檢查

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('刪除失敗: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 編輯接力隊伍對話框
  void _showEditRelayTeamDialog(Map<String, dynamic> team) async {
    final TextEditingController teamNameController =
        TextEditingController(text: team['name'] ?? team['teamName'] ?? '');
    final TextEditingController schoolController =
        TextEditingController(text: team['school'] ?? '');
    List<Map<String, dynamic>> teamMembers =
        List<Map<String, dynamic>>.from(team['members'] ?? []);
    Set<String> selectedTeamMembers = Set<String>.from(teamMembers
        .map((member) => member['id'] as String? ?? '')
        .where((id) => id.isNotEmpty));

    // 獲取可選的隊員
    List<Map<String, dynamic>> availableAthletes = [];
    try {
      final collectionName = 'competition_${widget.competitionId}';
      final snapshot = await _firestore
          .collection(collectionName)
          .where('status', isEqualTo: 'approved')
          .get();

      if (!mounted) return; // 添加 mounted 檢查

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String athleteGender = data['gender'] ?? '未知';

        // 隊員會被篩選為與隊伍同性別的選手
        if (athleteGender == team['gender']) {
          availableAthletes.add({
            'id': doc.id,
            'name': data['userName'] ?? '未知',
            'athleteNumber': data['athleteNumber'] ?? '',
            'school': data['school'] ?? '',
            'gender': athleteGender,
            'ageGroup': data['ageGroup'] ?? '',
          });
        }
      }

      // 排序
      availableAthletes.sort((a, b) {
        int schoolCompare = (a['school'] ?? '').compareTo(b['school'] ?? '');
        if (schoolCompare != 0) return schoolCompare;
        return (a['name'] ?? '').compareTo(b['name'] ?? '');
      });
    } catch (e) {
      debugPrint('載入可選隊員時出錯: $e');
    }

    if (!mounted) return; // 添加 mounted 檢查

    bool confirm = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text('編輯接力隊伍'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 隊伍名稱
                          const Text('隊伍名稱:'),
                          TextField(
                            controller: teamNameController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: '例如: A隊、B隊或學校名稱',
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 學校/機構
                          const Text('學校/機構:'),
                          TextField(
                            controller: schoolController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: '例如: 香港中學',
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 已選隊員
                          Text('已選隊員 (${teamMembers.length}/8)',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),

                          if (teamMembers.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('尚未選擇隊員',
                                  style: TextStyle(color: Colors.grey)),
                            )
                          else
                            ReorderableListView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: teamMembers.map((member) {
                                return ListTile(
                                  key: ValueKey(member['id'] ?? member['name']),
                                  leading: CircleAvatar(
                                    backgroundColor: team['gender'] == '男'
                                        ? const Color(0xFF0A4FB5)
                                        : const Color(0xFFB5306E),
                                    child: Text(
                                        '${teamMembers.indexOf(member) + 1}'),
                                  ),
                                  title: Text(member['name'] ?? '未知隊員'),
                                  subtitle: Text(member['school'] ?? ''),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove_circle,
                                        color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        selectedTeamMembers
                                            .remove(member['id']);
                                        teamMembers.remove(member);
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                              onReorder: (oldIndex, newIndex) {
                                setState(() {
                                  if (oldIndex < newIndex) {
                                    newIndex -= 1;
                                  }
                                  final item = teamMembers.removeAt(oldIndex);
                                  teamMembers.insert(newIndex, item);
                                });
                              },
                            ),

                          const SizedBox(height: 16),

                          // 可選隊員列表
                          const Text('添加隊員',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: availableAthletes.length,
                              itemBuilder: (context, index) {
                                final athlete = availableAthletes[index];
                                final bool isSelected =
                                    selectedTeamMembers.contains(athlete['id']);

                                // 如果這個隊員已經在隊伍中，不顯示在可選列表
                                if (isSelected) return Container();

                                return ListTile(
                                  title: Text(athlete['name']),
                                  subtitle: Text(
                                      '${athlete['school']} (${athlete['ageGroup']})'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.add_circle,
                                        color: Colors.green),
                                    onPressed: teamMembers.length >= 8
                                        ? null
                                        : () {
                                            setState(() {
                                              if (teamMembers.length < 8) {
                                                selectedTeamMembers
                                                    .add(athlete['id']);
                                                teamMembers.add({
                                                  'id': athlete['id'],
                                                  'name': athlete['name'],
                                                  'school': athlete['school'],
                                                  'athleteNumber':
                                                      athlete['athleteNumber'],
                                                });
                                              }
                                            });
                                          },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (teamNameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('請輸入隊伍名稱')),
                          );
                          return;
                        }

                        if (schoolController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('請輸入學校/機構')),
                          );
                          return;
                        }

                        if (teamMembers.length < 4) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('接力隊伍至少需要4名隊員')),
                          );
                          return;
                        }

                        Navigator.pop(context, true);
                      },
                      child: const Text('保存'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;

    if (confirm) {
      // 更新接力隊伍資料
      try {
        setState(() {
          _isLoading = true;
        });

        final Map<String, dynamic> updatedTeam = {
          'teamName': teamNameController.text,
          'name': teamNameController.text,
          'school': schoolController.text,
          'members': teamMembers,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await _firestore
            .collection('competition_${widget.competitionId}')
            .doc(team['id'])
            .update(updatedTeam);

        if (!mounted) return; // 添加 mounted 檢查

        // 更新成功
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('接力隊伍更新成功'),
            backgroundColor: Colors.green,
          ),
        );

        // 重新加載數據
        await _loadAthletesByEvent(_selectedEvent);
      } catch (e) {
        if (!mounted) return; // 添加 mounted 檢查

        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 顯示錯誤信息
  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.competitionName} 分組名單'),
        actions: [
          // 只保留添加接力項目按鈕，並使其更加突出
          ElevatedButton.icon(
            icon: const Icon(Icons.group_add, size: 24),
            label: const Text(
              '添加接力隊伍',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            onPressed: _showAddRelayTeamDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 簡化的頂部控制區域
                Container(
                  color: Colors.grey.shade100,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 頂部項目信息
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_selectedEvent ${widget.ageGroup != null ? '- ${widget.ageGroup}' : ''}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16),
                                  const SizedBox(width: 8),
                                  Text(_competitionData['startDate'] != null
                                      ? '${_competitionData['startDate']}'
                                      : '日期待定'),
                                  const Spacer(),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Text('選擇項目：'),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButton<String>(
                                      value: _selectedEvent,
                                      isExpanded: true,
                                      onChanged: (String? newValue) {
                                        if (newValue != null &&
                                            newValue != _selectedEvent) {
                                          _loadAthletesByEvent(newValue);
                                        }
                                      },
                                      items: (_competitionData['metadata']
                                                  ?['events'] as List<dynamic>?)
                                              ?.map((event) {
                                                if (event is Map<String,
                                                        dynamic> &&
                                                    event.containsKey('name')) {
                                                  return DropdownMenuItem<
                                                      String>(
                                                    value: event['name'],
                                                    child: Text(event['name']),
                                                  );
                                                }
                                                return null;
                                              })
                                              .whereType<
                                                  DropdownMenuItem<String>>()
                                              .toList() ??
                                          [],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // 刷新按鈕
                                  IconButton(
                                    icon: const Icon(Icons.refresh),
                                    onPressed: () =>
                                        _loadAthletesByEvent(_selectedEvent),
                                    tooltip: '刷新數據',
                                    color: Colors.blue,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 性別說明
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildColorLegend(const Color(0xFF0A4FB5), '男子組'),
                      const SizedBox(width: 20),
                      _buildColorLegend(const Color(0xFFB5306E), '女子組'),
                    ],
                  ),
                ),

                Expanded(
                  child: _groups.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.group_off,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '沒有符合條件的選手',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('添加接力隊伍'),
                                onPressed: _showAddRelayTeamDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 分組列表
                                ...List.generate(_groups.length, (groupIndex) {
                                  final group = _groups[groupIndex];

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 24),
                                    elevation: 3,
                                    child: Column(
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          color: _getGroupHeaderColor(group),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '第${groupIndex + 1}組',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              // 顯示性別和年齡組別
                                              Text(
                                                _getGroupInfoText(group),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          child: Table(
                                            border: TableBorder.all(
                                              color: Colors.grey.shade300,
                                            ),
                                            columnWidths: const {
                                              0: FixedColumnWidth(40),
                                              1: FixedColumnWidth(
                                                  160), // 增加選手資料欄位寬度
                                              2: FixedColumnWidth(80),
                                              3: FlexColumnWidth(),
                                            },
                                            children: [
                                              // 表頭
                                              TableRow(
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                ),
                                                children: const [
                                                  Padding(
                                                    padding:
                                                        EdgeInsets.all(8.0),
                                                    child: Text('選次',
                                                        textAlign:
                                                            TextAlign.center),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        EdgeInsets.all(8.0),
                                                    child: Text('選手資料',
                                                        textAlign:
                                                            TextAlign.center),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        EdgeInsets.all(8.0),
                                                    child: Text('編號',
                                                        textAlign:
                                                            TextAlign.center),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        EdgeInsets.all(8.0),
                                                    child: Text('學校',
                                                        textAlign:
                                                            TextAlign.center),
                                                  ),
                                                ],
                                              ),

                                              // 選手資料
                                              ...group
                                                  .asMap()
                                                  .entries
                                                  .map((entry) {
                                                final index = entry.key;
                                                final athlete = entry.value;
                                                return _buildAthleteRow(
                                                    index, athlete, groupIndex);
                                              }).toList(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  // 獲取組別標題顏色
  Color _getGroupHeaderColor(List<Map<String, dynamic>> group) {
    if (group.isEmpty) return const Color(0xFF0A0E53); // 默認顏色

    // 檢查第一個運動員的性別
    String gender = group.first['gender'] ?? '未知';

    // 根據性別返回不同的顏色
    switch (gender) {
      case '男':
        return const Color(0xFF0A4FB5); // 藍色
      case '女':
        return const Color(0xFFB5306E); // 粉紅色
      default:
        return const Color(0xFF0A0E53); // 默認深藍色
    }
  }

  // 獲取組別信息文本
  String _getGroupInfoText(List<Map<String, dynamic>> group) {
    if (group.isEmpty) return '預賽';

    // 獲取第一個運動員的性別和年齡組別信息
    String gender = group.first['gender'] ?? '未知';
    String ageGroup = group.first['ageGroup'] ?? '未分組';

    return '$gender $ageGroup';
  }

  Widget _buildColorLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  // 顯示添加接力項目對話框
  Future<void> _showAddRelayTeamDialog() async {
    final TextEditingController teamNameController = TextEditingController();
    final TextEditingController schoolController = TextEditingController();
    String selectedAgeGroup = availableAgeGroups.first;
    String selectedGender = '男';
    String? selectedSchool;
    final List<Map<String, dynamic>> teamMembers = [];
    final Set<String> selectedTeamMembers = {}; // 記錄已選擇的隊員ID

    // 加載符合條件的現有選手列表
    List<Map<String, dynamic>> availableAthletes = [];

    List<String> relayEvents = ['4x100米接力', '4x400米接力'];
    String selectedEvent = relayEvents.first;

    // 加載符合條件的現有選手
    try {
      if (!mounted) return;

      final collectionName = 'competition_${widget.competitionId}';
      final snapshot = await _firestore
          .collection(collectionName)
          .where('status', isEqualTo: 'approved')
          .get();

      if (!mounted) return; // 添加 mounted 檢查

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String athleteGender = data['gender'] ?? '未知';

        // 隊員會被篩選為與隊伍同性別的選手
        availableAthletes.add({
          'id': doc.id,
          'name': data['userName'] ?? '未知',
          'athleteNumber': data['athleteNumber'] ?? '',
          'school': data['school'] ?? '',
          'gender': athleteGender,
          'ageGroup': data['ageGroup'] ?? '',
        });
      }

      // 按學校和姓名排序
      availableAthletes.sort((a, b) {
        int schoolCompare = (a['school'] ?? '').compareTo(b['school'] ?? '');
        if (schoolCompare != 0) return schoolCompare;
        return (a['name'] ?? '').compareTo(b['name'] ?? '');
      });
    } catch (e) {
      debugPrint('載入可選隊員時出錯: $e');
    }

    if (!mounted) return; // 添加 mounted 檢查

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // 禁止點擊外部關閉
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // 篩選與所選性別相符的選手
            List<Map<String, dynamic>> filteredAthletes = availableAthletes
                .where((athlete) => athlete['gender'] == selectedGender)
                .toList();

            return AlertDialog(
              title: const Text('添加接力隊伍'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 接力項目選擇
                      const Text('選擇接力項目:'),
                      DropdownButtonFormField<String>(
                        value: selectedEvent,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onChanged: (String? value) {
                          if (value != null) {
                            setState(() {
                              selectedEvent = value;
                            });
                          }
                        },
                        items: relayEvents.map((event) {
                          return DropdownMenuItem<String>(
                            value: event,
                            child: Text(event),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // 年齡組和性別選擇（並排顯示）
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('年齡組:'),
                                DropdownButtonFormField<String>(
                                  value: selectedAgeGroup,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding:
                                        EdgeInsets.symmetric(horizontal: 10),
                                  ),
                                  onChanged: (String? value) {
                                    if (value != null) {
                                      setState(() {
                                        selectedAgeGroup = value;
                                      });
                                    }
                                  },
                                  items: availableAgeGroups.map((age) {
                                    return DropdownMenuItem<String>(
                                      value: age,
                                      child: Text(age),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('性別:'),
                                DropdownButtonFormField<String>(
                                  value: selectedGender,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding:
                                        EdgeInsets.symmetric(horizontal: 10),
                                  ),
                                  onChanged: (String? value) {
                                    if (value != null) {
                                      setState(() {
                                        selectedGender = value;
                                        // 清空已選隊員，因為性別變了
                                        selectedTeamMembers.clear();
                                        teamMembers.clear();
                                      });
                                    }
                                  },
                                  items: _genders.map((gender) {
                                    String label =
                                        gender == '男' ? '男子組' : '女子組';
                                    return DropdownMenuItem<String>(
                                      value: gender,
                                      child: Text(label),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 隊伍名稱
                      const Text('隊伍名稱:'),
                      TextField(
                        controller: teamNameController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '例如: A隊、B隊或學校名稱',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 學校/機構選擇
                      if (_schools.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('學校/機構:'),
                            DropdownButtonFormField<String>(
                              value: selectedSchool,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 10),
                                hintText: '選擇現有學校',
                              ),
                              onChanged: (String? value) {
                                if (value != null) {
                                  setState(() {
                                    selectedSchool = value;
                                    schoolController.text = value;
                                  });
                                }
                              },
                              items: _schools.map((school) {
                                return DropdownMenuItem<String>(
                                  value: school,
                                  child: Text(school),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            const Text('或輸入新學校名稱:'),
                            TextField(
                              controller: schoolController,
                              decoration: const InputDecoration(
                                hintText: '例如: 香港中學',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('學校/機構:'),
                            TextField(
                              controller: schoolController,
                              decoration: const InputDecoration(
                                hintText: '例如: 香港中學',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),

                      // 隊員列表標題
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('已選隊員 (${teamMembers.length})',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: teamMembers.length < 4
                                    ? Colors.orange
                                    : Colors.green,
                              )),
                          Text(
                            teamMembers.length < 4 ? '至少需要4名隊員' : '可拖動排序',
                            style: TextStyle(
                              fontSize: 12,
                              color: teamMembers.length < 4
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 可拖動排序的已選隊員列表
                      if (teamMembers.isNotEmpty)
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ReorderableListView.builder(
                            shrinkWrap: true,
                            buildDefaultDragHandles: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: teamMembers.length,
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (oldIndex < newIndex) {
                                  newIndex -= 1;
                                }
                                final item = teamMembers.removeAt(oldIndex);
                                teamMembers.insert(newIndex, item);
                              });
                            },
                            itemBuilder: (context, index) {
                              final member = teamMembers[index];
                              return ListTile(
                                key: ValueKey(member['id']),
                                leading: CircleAvatar(
                                  backgroundColor: selectedGender == '男'
                                      ? const Color(0xFF0A4FB5)
                                      : const Color(0xFFB5306E),
                                  child: Text(
                                      '${teamMembers.indexOf(member) + 1}'),
                                ),
                                title: Text(member['name']),
                                subtitle: Text(member['school'] ?? ''),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      selectedTeamMembers.remove(member['id']);
                                      teamMembers.removeAt(index);
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('請從下方選擇隊員',
                              style: TextStyle(color: Colors.grey)),
                        ),

                      const SizedBox(height: 16),

                      // 可選隊員列表標題
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('可選隊員',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          // 可添加搜索或過濾功能
                          Text('共${filteredAthletes.length}名選手',
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 可選隊員列表，使用ListView而不是TextField方式
                      Container(
                        height: 200, // 固定高度，可滾動
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredAthletes.length,
                          itemBuilder: (context, index) {
                            final athlete = filteredAthletes[index];
                            final bool isSelected =
                                selectedTeamMembers.contains(athlete['id']);

                            return CheckboxListTile(
                              title: Text(athlete['name']),
                              subtitle: Text(
                                  '${athlete['school']} (${athlete['ageGroup']})'),
                              secondary: CircleAvatar(
                                backgroundColor: selectedGender == '男'
                                    ? const Color(0xFF0A4FB5)
                                    : const Color(0xFFB5306E),
                                child: Text(_getAthleteInitial(
                                    athlete['athleteNumber'])),
                              ),
                              value: isSelected,
                              onChanged: (selected) {
                                setState(() {
                                  if (selected == true) {
                                    if (teamMembers.length < 8) {
                                      // 限制最多8名隊員
                                      selectedTeamMembers.add(athlete['id']);
                                      teamMembers.add({
                                        'id': athlete['id'],
                                        'name': athlete['name'],
                                        'school': athlete['school'],
                                        'athleteNumber':
                                            athlete['athleteNumber'],
                                      });
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('最多選擇8名隊員')),
                                      );
                                    }
                                  } else {
                                    selectedTeamMembers.remove(athlete['id']);
                                    teamMembers.removeWhere(
                                        (m) => m['id'] == athlete['id']);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // 驗證輸入
                    if (teamNameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('請輸入隊伍名稱')),
                      );
                      return;
                    }

                    if (schoolController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('請輸入或選擇學校/機構')),
                      );
                      return;
                    }

                    if (teamMembers.isEmpty || teamMembers.length < 4) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('接力隊伍至少需要4名隊員')),
                      );
                      return;
                    }

                    // 保存接力隊伍
                    _saveRelayTeam(
                        selectedEvent,
                        selectedAgeGroup,
                        selectedGender,
                        teamNameController.text,
                        schoolController.text,
                        teamMembers);

                    Navigator.pop(context);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 保存接力隊伍到Firestore
  Future<void> _saveRelayTeam(
      String eventName,
      String ageGroup,
      String gender,
      String teamName,
      String school,
      List<Map<String, dynamic>> members) async {
    try {
      // 驗證接力隊伍資料
      if (!_validateRelayTeam(
          eventName, ageGroup, gender, teamName, school, members)) {
        return; // 驗證失敗，提前返回
      }

      setState(() {
        _isLoading = true;
      });

      if (!mounted) return; // 添加 mounted 檢查

      // 顯示加載指示器
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("保存中..."),
              ],
            ),
          );
        },
      );

      // 檢查該項目是否已經存在於metadata中
      bool eventExists = false;
      if (_competitionData.containsKey('metadata') &&
          _competitionData['metadata'] != null &&
          _competitionData['metadata']['events'] != null) {
        final eventsList =
            _competitionData['metadata']['events'] as List<dynamic>;
        for (var event in eventsList) {
          if (event is Map<String, dynamic> &&
              event.containsKey('name') &&
              event['name'] == eventName) {
            eventExists = true;
            break;
          }
        }
      }

      // 如果項目不存在，添加到metadata中
      if (!eventExists) {
        await _firestore
            .collection('competitions')
            .doc(widget.competitionId)
            .update({
          'metadata.events': FieldValue.arrayUnion([
            {
              'name': eventName,
              'type': '接力', // 添加類型標記，便於其他部分識別
            }
          ])
        });
      }

      // 為接力隊伍生成一個唯一ID
      final String teamId =
          'relay_${widget.competitionId}_${teamName}_${DateTime.now().millisecondsSinceEpoch}';

      // 處理隊員資料，確保每個隊員都有應有的資料
      List<Map<String, dynamic>> processedMembers = members.map((member) {
        // 確保每個隊員都有必要的字段
        return {
          'id': member['id'] ?? '',
          'name': member['name'] ?? '未知隊員',
          'athleteNumber': member['athleteNumber'] ?? '',
          'school': member['school'] ?? school, // 默認使用隊伍的學校
          'position': members.indexOf(member) + 1, // 記錄隊員位置
        };
      }).toList();

      // 創建接力隊伍數據
      final Map<String, dynamic> teamData = {
        'id': teamId,
        'teamName': teamName,
        'name': teamName, // 確保name字段也包含隊伍名稱
        'school': school,
        'eventName': eventName,
        'ageGroup': ageGroup,
        'gender': gender,
        'events': [eventName],
        'members': processedMembers,
        'athleteNumber': 'R${_athletes.length + 1}'.padLeft(4, '0'),
        'isRelayTeam': true, // 明確標記為接力隊伍
        'status': 'approved', // 自動設為已核准
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'userName': teamName, // 為了兼容性，添加userName字段
      };

      // 使用批次操作確保數據一致性
      WriteBatch batch = _firestore.batch();

      // 保存接力隊伍到競賽報名集合中
      DocumentReference teamRef = _firestore
          .collection('competition_${widget.competitionId}')
          .doc(teamId);
      batch.set(teamRef, teamData);

      // 更新接力項目的配置信息
      DocumentReference eventTypeRef = _firestore
          .collection('competitions')
          .doc(widget.competitionId)
          .collection('score_setup')
          .doc('event_types');
      batch.set(
          eventTypeRef,
          {
            'eventTypes': {eventName: '接力'},
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      // 執行批次操作
      await batch.commit();

      if (!mounted) return; // 添加 mounted 檢查

      // 關閉加載指示器
      Navigator.pop(context);

      setState(() {
        _isLoading = false;
      });

      // 重新加載數據
      if (eventName == _selectedEvent) {
        await _loadAthletesByEvent(eventName);
      }

      // 顯示成功訊息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('已成功添加接力隊伍: $teamName (${members.length}名隊員)'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '查看',
            textColor: Colors.white,
            onPressed: () {
              // 選擇該項目並捲動到該隊伍
              _loadAthletesByEvent(eventName);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return; // 添加 mounted 檢查

      // 關閉加載指示器
      Navigator.pop(context);

      setState(() {
        _isLoading = false;
      });

      debugPrint('保存接力隊伍出錯: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('添加接力隊伍失敗: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 驗證接力隊伍數據
  bool _validateRelayTeam(String eventName, String ageGroup, String gender,
      String teamName, String school, List<Map<String, dynamic>> members) {
    if (!mounted) return false; // 添加 mounted 檢查

    // 基本驗證
    if (teamName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('隊伍名稱不能為空')),
      );
      return false;
    }

    if (school.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('學校/機構不能為空')),
      );
      return false;
    }

    // 檢查隊員人數是否符合要求
    int minRequiredMembers = 4; // 接力至少需要4名隊員
    if (members.length < minRequiredMembers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$eventName 需要至少 $minRequiredMembers 名隊員')),
      );
      return false;
    }

    // 檢查隊員是否都有名字
    for (var member in members) {
      if (member['name'] == null || member['name'].toString().trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('所有隊員必須有姓名')),
        );
        return false;
      }
    }

    // 檢查隊伍名稱是否已存在
    for (var athlete in _athletes) {
      if (athlete['teamName'] == teamName || athlete['name'] == teamName) {
        // 如果發現同名隊伍，顯示確認對話框
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('隊伍名稱重複'),
            content: Text('已有名為「$teamName」的隊伍或選手。是否仍要使用此名稱？'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context, false); // 返回false表示取消
                },
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, true); // 返回true表示確認
                },
                child: const Text('繼續使用'),
              ),
            ],
          ),
        ).then((confirmed) {
          return confirmed ?? false;
        });
      }
    }

    return true;
  }

  TableRow _buildAthleteRow(
      int index, Map<String, dynamic> athlete, int groupIndex) {
    final gender = athlete['gender'] ?? '未知';
    final bool isRelayTeam = athlete['isRelayTeam'] == true;

    // 根據性別設定不同的顏色
    Color rowColor = Colors.white;
    if (index % 2 == 1) {
      rowColor = gender == '男'
          ? const Color(0xFFE6F0FF) // 淺藍色
          : gender == '女'
              ? const Color(0xFFFCE4EC) // 淺粉色
              // 淺紫色
              : Colors.grey.shade50;
    } else {
      rowColor = gender == '男'
          ? const Color(0xFFF0F8FF) // 更淺藍色
          : gender == '女'
              ? const Color(0xFFFFF0F5) // 更淺粉色

              : Colors.white;
    }

    // 為接力隊伍添加點擊事件查看詳情，不再需要選擇框
    if (isRelayTeam) {
      List<Widget> cells = [
        // 選手序號
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: gender == '男'
                  ? const Color(0xFF0A4FB5)
                  : gender == '女'
                      ? const Color(0xFFB5306E)
                      : const Color(0xFF0A0E53),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),

        // 選手/隊伍名稱
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 性別指示器
                  Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: gender == '男'
                          ? const Color(0xFF0A4FB5)
                          : gender == '女'
                              ? const Color(0xFFB5306E)
                              : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        gender == '男'
                            ? Icons.male
                            : gender == '女'
                                ? Icons.female
                                : Icons.question_mark,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),

                  // 名稱，如果是接力隊伍則添加標記
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            athlete['name'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isRelayTeam ? Colors.blue.shade800 : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isRelayTeam)
                          const Padding(
                            padding: EdgeInsets.only(left: 4.0),
                            child:
                                Icon(Icons.flag, size: 16, color: Colors.blue),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              // 接力隊伍查看隊員按鈕
              if (isRelayTeam &&
                  athlete.containsKey('members') &&
                  athlete['members'] is List &&
                  (athlete['members'] as List).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 24.0, top: 4.0),
                  child: InkWell(
                    onTap: () => _showRelayTeamDetails(athlete),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people,
                            size: 12, color: Colors.blue.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '查看 ${(athlete['members'] as List).length} 名隊員',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 運動員號碼
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            athlete['athleteNumber'] ?? '',
            style: TextStyle(
              color: isRelayTeam ? Colors.blue.shade700 : Colors.blue,
              fontWeight: isRelayTeam ? FontWeight.bold : null,
            ),
          ),
        ),

        // 學校
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(athlete['school'] ?? ''),
        ),
      ];

      // 為每個單元格包裝點擊事件
      return TableRow(
        decoration: BoxDecoration(
          color: rowColor,
        ),
        children: cells
            .map((cell) => InkWell(
                  onTap: () => _showRelayTeamDetails(athlete),
                  child: cell,
                ))
            .toList(),
      );
    }

    // 普通選手或非選擇模式下的標準行
    return TableRow(
      decoration: BoxDecoration(
        color: rowColor,
      ),
      children: [
        // 選手序號
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: gender == '男'
                  ? const Color(0xFF0A4FB5)
                  : gender == '女'
                      ? const Color(0xFFB5306E)
                      : const Color(0xFF0A0E53),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),

        // 選手/隊伍名稱 - 限制高度和寬度，避免溢出
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 80, // 限制最大高度
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // 性別指示器
                    Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: gender == '男'
                            ? const Color(0xFF0A4FB5)
                            : gender == '女'
                                ? const Color(0xFFB5306E)
                                : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          gender == '男'
                              ? Icons.male
                              : gender == '女'
                                  ? Icons.female
                                  : Icons.question_mark,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),

                    // 名稱，如果是接力隊伍則添加標記
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              athlete['name'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    isRelayTeam ? Colors.blue.shade800 : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (isRelayTeam)
                            const Padding(
                              padding: EdgeInsets.only(left: 4.0),
                              child: Icon(Icons.flag,
                                  size: 16, color: Colors.blue),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // 如果是接力隊伍且有隊員信息，顯示查看隊員按鈕
                if (isRelayTeam &&
                    athlete.containsKey('members') &&
                    athlete['members'] is List &&
                    (athlete['members'] as List).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 24.0, top: 4.0),
                    child: InkWell(
                      onTap: () => _showRelayTeamDetails(athlete),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people,
                                size: 12, color: Colors.blue.shade600),
                            const SizedBox(width: 4),
                            Text(
                              '查看隊員 (${(athlete['members'] as List).length})',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 運動員號碼
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            athlete['athleteNumber'] ?? '',
            style: TextStyle(
              color: isRelayTeam ? Colors.blue.shade700 : Colors.blue,
              fontWeight: isRelayTeam ? FontWeight.bold : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // 學校
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            athlete['school'] ?? '',
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  // 安全獲取選手編號的首字母
  String _getAthleteInitial(dynamic athleteNumber) {
    if (athleteNumber == null) return 'A';
    String numStr = athleteNumber.toString();
    return numStr.isNotEmpty ? numStr.substring(0, 1) : 'A';
  }
}
