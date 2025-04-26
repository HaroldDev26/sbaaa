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
  Map<String, DateTime> _groupStartTimes = {};
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

      // 如果有預設的事件，則加載它
      if (_selectedEvent.isNotEmpty) {
        await _loadAthletesByEvent(_selectedEvent);
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
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
      print('加載學校列表出錯: $e');
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

      List<Map<String, dynamic>> athletes = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        // 不需要打印所有運動員資料，避免日誌過多
        // print('運動員資料: $data');

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
            print(
                '運動員: ${data['userName']}, 性別: $gender, 原始資料: ${data.containsKey('gender') ? '存在gender欄位' : '缺少gender欄位'}');

            // 從報名資料直接獲取所有資訊
            athletes.add({
              'id': doc.id,
              'name': data['userName'] ?? '未知',
              'ageGroup': athleteAgeGroup,
              'school': data['school'] ?? '',
              'gender': data['gender'] ?? '未知',
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

      // 為每組分配開始時間
      _assignGroupStartTimes();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('載入運動員出錯: $e');
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

    // 按性別和年齡組別分組
    Map<String, Map<String, List<Map<String, dynamic>>>> genderAgeGroupMap = {
      '男': {},
      '女': {},
    };

    for (var athlete in _athletes) {
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

  // 為每組分配開始時間
  void _assignGroupStartTimes() {
    _groupStartTimes = {};

    // 假設比賽從特定時間開始，每組間隔10分鐘
    DateTime baseTime = _competitionData['startDate'] != null
        ? (DateTime.tryParse(_competitionData['startDate']) ?? DateTime.now())
        : DateTime.now();

    // 添加時間為14:30
    baseTime = DateTime(baseTime.year, baseTime.month, baseTime.day, 14, 30);

    for (int i = 0; i < _groups.length; i++) {
      // 每組間隔10分鐘
      DateTime groupTime = baseTime.add(Duration(minutes: i * 10));
      _groupStartTimes['group_$i'] = groupTime;
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
          // 添加接力項目按鈕
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: _showAddRelayTeamDialog,
            tooltip: '添加接力隊伍',
          ),
          // 現有的刷新按鈕
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadAthletesByEvent(_selectedEvent),
            tooltip: '刷新數據',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
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
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16),
                                const SizedBox(width: 8),
                                Text(_competitionData['startDate'] != null
                                    ? '${_competitionData['startDate']} ${DateFormat('HH:mm').format(_groupStartTimes['group_0'] ?? DateTime.now())}'
                                    : '日期待定'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Text('選擇項目：'),
                                const SizedBox(width: 8),
                                DropdownButton<String>(
                                  value: _selectedEvent,
                                  onChanged: (String? newValue) {
                                    if (newValue != null &&
                                        newValue != _selectedEvent) {
                                      _loadAthletesByEvent(newValue);
                                    }
                                  },
                                  items: (_competitionData['metadata']
                                              ?['events'] as List<dynamic>?)
                                          ?.map((event) {
                                            if (event is Map<String, dynamic> &&
                                                event.containsKey('name')) {
                                              return DropdownMenuItem<String>(
                                                value: event['name'],
                                                child: Text(event['name']),
                                              );
                                            }
                                            return null;
                                          })
                                          .whereType<DropdownMenuItem<String>>()
                                          .toList() ??
                                      [],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 性別說明
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildColorLegend(const Color(0xFF0A4FB5), '男子組'),
                          const SizedBox(width: 20),
                          _buildColorLegend(const Color(0xFFB5306E), '女子組'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 分組列表
                    if (_groups.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            '沒有符合條件的選手',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                    else
                      ...List.generate(_groups.length, (groupIndex) {
                        final group = _groups[groupIndex];
                        final startTime = _groupStartTimes['group_$groupIndex'];
                        final timeStr = startTime != null
                            ? DateFormat('HH:mm').format(startTime)
                            : '--:--';

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
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$timeStr 開始',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: _getGroupHeaderColor(group),
                                        ),
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
                                    1: FixedColumnWidth(120),
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
                                          padding: EdgeInsets.all(8.0),
                                          child: Text('選次',
                                              textAlign: TextAlign.center),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text('選手資料',
                                              textAlign: TextAlign.center),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text('編號',
                                              textAlign: TextAlign.center),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text('學校',
                                              textAlign: TextAlign.center),
                                        ),
                                      ],
                                    ),

                                    // 選手資料
                                    ...group.asMap().entries.map((entry) {
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
    String selectedAgeGroup =
       availableAgeGroups.first ;
    String selectedGender = '男';
    String? selectedSchool;
    final List<Map<String, dynamic>> teamMembers = [];

    List<String> relayEvents = ['4x100米接力', '4x400米接力'];

    String selectedEvent = relayEvents.first;

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // 禁止點擊外部關閉
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                          const Text('隊員列表',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                teamMembers.add({
                                  'name': '',
                                  'number': generateAthleteNumber(
                                      teamMembers.length + 1),
                                });
                              });
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('添加隊員'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 隊員列表 - 修復這部分
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: teamMembers.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: selectedGender == '男'
                                      ? const Color(0xFF0A4FB5)
                                      : selectedGender == '女'
                                          ? const Color(0xFFB5306E)
                                          : Colors.purple,
                                  radius: 14,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      hintText: '隊員 ${index + 1} 姓名',
                                      border: const OutlineInputBorder(),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        teamMembers[index]['name'] = value;
                                      });
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      teamMembers.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      if (teamMembers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('請添加隊員',
                              style: TextStyle(color: Colors.grey)),
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

                    if (teamMembers.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('請至少添加一名隊員')),
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
            }
          ])
        });
      }

      // 為接力隊伍生成一個唯一ID
      final String teamId =
          '${eventName}_${teamName}_${DateTime.now().millisecondsSinceEpoch}';

      // 創建接力隊伍數據
      final Map<String, dynamic> teamData = {
        'id': teamId,
        'teamName': teamName,
        'school': school,
        'eventName': eventName,
        'ageGroup': ageGroup,
        'gender': gender,
        'events': [eventName],
        'members': members,
        'athleteNumber': 'R${_athletes.length + 1}'.padLeft(4, '0'),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 保存接力隊伍到競賽報名集合中
      await _firestore
          .collection('competition_${widget.competitionId}')
          .doc(teamId)
          .set(teamData);

      // 更新接力項目的配置信息
      await _firestore
          .collection('competitions')
          .doc(widget.competitionId)
          .collection('score_setup')
          .doc('event_types')
          .set({
        'eventTypes': {eventName: '接力'},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 重新加載數據
      if (eventName == _selectedEvent) {
        _loadAthletesByEvent(eventName);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已成功添加接力隊伍: $teamName'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('保存接力隊伍出錯: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('添加接力隊伍失敗: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                  Text(
                    isRelayTeam
                        ? '${athlete['teamName'] ?? athlete['name']} 🏁'
                        : athlete['name'] ?? '未知',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isRelayTeam ? Colors.blue.shade800 : null,
                    ),
                  ),
                ],
              ),

              // 如果是接力隊伍，顯示隊員列表
              if (isRelayTeam &&
                  athlete.containsKey('members') &&
                  athlete['members'] is List)
                Padding(
                  padding: const EdgeInsets.only(left: 24.0, top: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        (athlete['members'] as List).map<Widget>((member) {
                      return Text(
                        '• ${member['name'] ?? '隊員'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      );
                    }).toList(),
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
      ],
    );
  }
}
