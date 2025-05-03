import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../utils/colors.dart';
import 'package:flutter/foundation.dart'; // 添加這一行以使用 debugPrint

class AwardListScreen extends StatefulWidget {
  final String competitionId;
  final String competitionName;

  const AwardListScreen({
    Key? key,
    required this.competitionId,
    required this.competitionName,
  }) : super(key: key);

  @override
  State<AwardListScreen> createState() => _AwardListScreenState();
}

class _AwardListScreenState extends State<AwardListScreen>
    with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  final bool _isGenerating = false;
  String? _error;
  List<Map<String, dynamic>> _allResults = [];
  List<Map<String, dynamic>> _filteredResults = [];
  String _searchText = '';
  String _selectedType = '全部';
  final List<String> _eventTypes = ['全部', '徑賽', '田賽', '接力'];
  String? _selectedSchool;
  List<String> _schools = [];

  // 檢查網絡連接
  Future<bool> _checkConnectivity() async {
    try {
      await _firestore.runTransaction((transaction) async {});
      return true;
    } catch (e) {
      return false;
    }
  }

  // 防抖控制器
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAllResults();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAllResults(); // 當應用程序恢復時重新加載數據
    }
  }

  // 載入所有比賽結果
  Future<void> _loadAllResults() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 使用 Firebase 自身的網絡狀態檢查
      if (!await _checkConnectivity()) {
        throw Exception('無網絡連接');
      }

      // 獲取比賽所有結果
      final snapshot = await _firestore
          .collection('competitions')
          .doc(widget.competitionId)
          .collection('final_results')
          .get(const GetOptions(source: Source.serverAndCache)) // 允許離線緩存
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('連接超時，請檢查網絡'),
          );

      if (!mounted) return;

      final results = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // 按項目類型排序
      results.sort((a, b) => (a['eventType'].toString() +
              a['eventName'].toString())
          .compareTo(b['eventType'].toString() + b['eventName'].toString()));

      // 提取所有學校
      Set<String> schoolsSet = {};
      for (var result in results) {
        if (result['results'] is List) {
          for (var athlete in result['results']) {
            if (athlete['school'] != null &&
                athlete['school'].toString().isNotEmpty) {
              schoolsSet.add(athlete['school'].toString());
            }
          }
        }
      }
      _schools = schoolsSet.toList()..sort();

      setState(() {
        _allResults = results;
        _filteredResults = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = e.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('載入成績失敗: ${e.toString()}'),
          action: SnackBarAction(
            label: '重試',
            onPressed: _loadAllResults,
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // 過濾結果
  void _filterResults() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      setState(() {
        _filteredResults = _allResults.where((result) {
          // 檢查項目名稱是否包含搜索文字
          final nameMatch = (result['eventName'] ?? '')
              .toString()
              .toLowerCase()
              .contains(_searchText.toLowerCase());

          // 檢查項目類型是否匹配選擇的類型
          final typeMatch = _selectedType == '全部' ||
              (result['eventType'] ?? '').toString() == _selectedType;

          // 如果選擇了學校，檢查結果中是否包含該學校的運動員
          bool schoolMatch = true;
          if (_selectedSchool != null && _selectedSchool!.isNotEmpty) {
            schoolMatch = false;
            if (result['results'] is List) {
              for (var athlete in result['results']) {
                if (athlete['school'] == _selectedSchool) {
                  schoolMatch = true;
                  break;
                }
              }
            }
          }

          return nameMatch && typeMatch && schoolMatch;
        }).toList();
      });
    });
  }

  // 導航到獎項表格頁面
  void _navigateToAwardTable(Map<String, dynamic> eventData) {
    if (!eventData.containsKey('results') ||
        eventData['results'] is! List ||
        (eventData['results'] as List).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此項目暫無成績數據')),
      );
      return;
    }

    // 確保添加比賽ID
    final Map<String, dynamic> enhancedEventData = Map.from(eventData);
    enhancedEventData['competitionId'] = widget.competitionId;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AwardTableScreen(
          eventData: enhancedEventData,
          competitionName: widget.competitionName,
        ),
      ),
    );
  }

  // 構建頂部卡片
  Widget _buildCard(
      BuildContext context, List<Map<String, dynamic>> filteredWithResults) {
    // 計算獎牌統計
    Map<String, int> medalCounts = {'金牌': 0, '銀牌': 0, '銅牌': 0};
    Set<String> uniqueEvents = {};

    for (var result in filteredWithResults) {
      uniqueEvents.add(result['eventName'] ?? '');

      if (result['results'] is List) {
        List results = result['results'] as List;
        for (var athlete in results) {
          if (athlete['rank'] == 1)
            medalCounts['金牌'] = (medalCounts['金牌'] ?? 0) + 1;
          if (athlete['rank'] == 2)
            medalCounts['銀牌'] = (medalCounts['銀牌'] ?? 0) + 1;
          if (athlete['rank'] == 3)
            medalCounts['銅牌'] = (medalCounts['銅牌'] ?? 0) + 1;
        }
      }
    }

    return Card(
      elevation: 2,
      shadowColor: primaryColor.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              primaryColor.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    color: Colors.amber,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.competitionName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '共${filteredWithResults.length}個項目的頒獎表格',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${uniqueEvents.length}個項目',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 獎牌統計
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMedalCount(
                      '金牌', medalCounts['金牌'] ?? 0, Colors.amber.shade700),
                  _buildMedalCount(
                      '銀牌', medalCounts['銀牌'] ?? 0, Colors.blueGrey.shade400),
                  _buildMedalCount(
                      '銅牌', medalCounts['銅牌'] ?? 0, Colors.brown.shade400),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events_outlined,
                      color: Colors.deepPurple,
                      size: 20,
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

  // 構建獎牌數量顯示
  Widget _buildMedalCount(String type, int count, Color color) {
    IconData icon = Icons.workspace_premium;
    if (type == '金牌')
      icon = Icons.workspace_premium;
    else if (type == '銀牌')
      icon = Icons.workspace_premium;
    else if (type == '銅牌') icon = Icons.workspace_premium;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
        Text(
          type,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 篩選有結果的項目
    final filteredWithResults = _filteredResults.where((result) {
      return result.containsKey('results') &&
          result['results'] is List &&
          (result['results'] as List).isNotEmpty;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('頒獎表格一覽'),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 0,
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadAllResults,
                    child: const Text('重新載入'),
                  ),
                ],
              ),
            )
          : _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('載入比賽數據中...'),
                    ],
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        primaryColor.withValues(alpha: 0.05),
                        Colors.white,
                      ],
                    ),
                  ),
                  child: RefreshIndicator(
                    onRefresh: _loadAllResults,
                    child: Column(
                      children: [
                        // 頂部資訊卡片
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          width: double.infinity,
                          child: _buildCard(context, filteredWithResults),
                        ),

                        // 搜索過濾部分
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  // 第一行：搜索框和項目類型過濾
                                  Row(
                                    children: [
                                      // 搜索框
                                      Expanded(
                                        child: TextField(
                                          decoration: InputDecoration(
                                            hintText: '搜尋項目名稱...',
                                            prefixIcon: const Icon(Icons.search,
                                                size: 20),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                width: 0.5,
                                                color: Colors.grey.shade300,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                width: 0.5,
                                                color: Colors.grey.shade300,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                width: 1.0,
                                                color: primaryColor.withValues(
                                                    alpha: 0.5),
                                              ),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 8),
                                            filled: true,
                                            fillColor: Colors.grey.shade50,
                                          ),
                                          onChanged: (value) {
                                            _searchText = value;
                                            _filterResults();
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // 過濾下拉選單
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 0.5,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _selectedType,
                                            icon: const Icon(Icons.filter_list),
                                            style: TextStyle(
                                              color: Colors.grey.shade800,
                                              fontSize: 14,
                                            ),
                                            items: _eventTypes
                                                .map((type) => DropdownMenuItem(
                                                      value: type,
                                                      child: Text(type),
                                                    ))
                                                .toList(),
                                            onChanged: (value) {
                                              if (value != null) {
                                                setState(() {
                                                  _selectedType = value;
                                                  _filterResults();
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // 第二行：學校過濾
                                  if (_schools.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12.0),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.school,
                                            size: 18,
                                            color: Colors.blueGrey,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('按學校過濾: '),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.grey.shade300,
                                                  width: 0.5,
                                                ),
                                              ),
                                              child:
                                                  DropdownButtonHideUnderline(
                                                child: DropdownButton<String?>(
                                                  value: _selectedSchool,
                                                  hint: const Text('選擇學校'),
                                                  isExpanded: true,
                                                  items: [
                                                    const DropdownMenuItem<
                                                        String?>(
                                                      value: null,
                                                      child: Text('所有學校'),
                                                    ),
                                                    ..._schools
                                                        .map((school) =>
                                                            DropdownMenuItem<
                                                                String?>(
                                                              value: school,
                                                              child:
                                                                  Text(school),
                                                            ))
                                                        .toList(),
                                                  ],
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _selectedSchool = value;
                                                      _filterResults();
                                                    });
                                                  },
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
                          ),
                        ),

                        // 頁面說明
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 16.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectedSchool != null &&
                                            _selectedSchool!.isNotEmpty
                                        ? '正在顯示 $_selectedSchool 學校的成績'
                                        : '點擊任意項目查看頒獎表格',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 項目列表
                        Expanded(
                          child: filteredWithResults.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search_off_rounded,
                                        size: 60,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        '沒有找到任何項目的成績數據',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16.0),
                                  itemCount: filteredWithResults.length,
                                  itemBuilder: (context, index) {
                                    final result = filteredWithResults[index];
                                    final eventName =
                                        result['eventName'] ?? '未知項目';
                                    final eventType = result['eventType'] ?? '';

                                    // 確定項目類型和顏色
                                    Color typeColor;
                                    IconData typeIcon;
                                    Color bgColor;

                                    switch (eventType) {
                                      case '徑賽':
                                        typeColor = Colors.blue.shade700;
                                        bgColor = Colors.blue.shade50;
                                        typeIcon = Icons.directions_run;
                                        break;
                                      case '田賽':
                                        typeColor = Colors.green.shade700;
                                        bgColor = Colors.green.shade50;
                                        typeIcon = Icons.sports_volleyball;
                                        break;
                                      case '接力':
                                        typeColor = Colors.purple.shade700;
                                        bgColor = Colors.purple.shade50;
                                        typeIcon = Icons.people;
                                        break;
                                      default:
                                        typeColor = Colors.grey.shade700;
                                        bgColor = Colors.grey.shade50;
                                        typeIcon = Icons.sports;
                                    }

                                    return Card(
                                      margin:
                                          const EdgeInsets.only(bottom: 10.0),
                                      elevation: 1,
                                      shadowColor:
                                          typeColor.withValues(alpha: 0.3),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color:
                                              typeColor.withValues(alpha: 0.3),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: InkWell(
                                        onTap: () =>
                                            _navigateToAwardTable(result),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: bgColor,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(typeIcon,
                                                    color: typeColor, size: 24),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      eventName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: typeColor
                                                            .withValues(
                                                                alpha: 0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                      ),
                                                      child: Text(
                                                        eventType,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: typeColor,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: typeColor.withValues(
                                                      alpha: 0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.chevron_right,
                                                  color: typeColor,
                                                  size: 20,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
      // 加載指示器
      bottomSheet: _isGenerating
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, -2),
                    blurRadius: 4,
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '正在處理數據...',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

// 獎項表格頁面
class AwardTableScreen extends StatefulWidget {
  final Map<String, dynamic> eventData;
  final String competitionName;

  const AwardTableScreen({
    Key? key,
    required this.eventData,
    required this.competitionName,
  }) : super(key: key);

  @override
  State<AwardTableScreen> createState() => _AwardTableScreenState();
}

class _AwardTableScreenState extends State<AwardTableScreen> {
  bool _isLoadingSchools = false;
  final Map<String, String> _athleteSchools = {};
  bool _disposed = false; // 添加標記以追蹤元件是否已被銷毀

  @override
  void initState() {
    super.initState();
    _loadAthleteSchools();
  }

  @override
  void dispose() {
    _disposed = true; // 標記元件為已銷毀
    super.dispose();
  }

  // 安全設置狀態的方法
  void _safeSetState(VoidCallback fn) {
    if (!_disposed && mounted) {
      setState(fn);
    }
  }

  // 加載運動員的學校信息
  Future<void> _loadAthleteSchools() async {
    if (!mounted) return; // 初始檢查

    _safeSetState(() {
      _isLoadingSchools = true;
    });

    try {
      final String competitionId = widget.eventData['competitionId'] ?? '';
      if (competitionId.isEmpty) {
        if (!mounted) return;
        _safeSetState(() {
          _isLoadingSchools = false;
        });
        return;
      }

      final List<dynamic> results = widget.eventData['results'] ?? [];
      if (results.isEmpty) {
        if (!mounted) return;
        _safeSetState(() {
          _isLoadingSchools = false;
        });
        return;
      }

      // 收集所有需要查詢學校信息的選手ID
      final List<String> athleteIds = [];
      final Map<String, String> immediateSchools = {};

      for (final athlete in results) {
        final String id = athlete['athleteId'] ?? athlete['id'] ?? '';
        final String existingSchool = athlete['school'] ?? '';

        // 只有在沒有學校信息的情況下才查詢
        if (id.isNotEmpty && existingSchool.isEmpty) {
          athleteIds.add(id);
        } else if (existingSchool.isNotEmpty) {
          immediateSchools[id] = existingSchool;
        }
      }

      // 立即更新已有的學校數據
      if (immediateSchools.isNotEmpty && mounted) {
        _safeSetState(() {
          _athleteSchools.addAll(immediateSchools);
        });
      }

      if (athleteIds.isEmpty) {
        if (!mounted) return;
        _safeSetState(() {
          _isLoadingSchools = false;
        });
        return;
      }

      // 使用批量加載功能更高效地查詢學校
      // 將運動員分批處理，每批次最多25個（符合 Firestore 限制）
      const int maxBatchSize = 25;
      for (int i = 0; i < athleteIds.length; i += maxBatchSize) {
        if (!mounted) break;

        final int end = (i + maxBatchSize < athleteIds.length)
            ? i + maxBatchSize
            : athleteIds.length;
        final batch = athleteIds.sublist(i, end);

        await _batchLoadSchools(batch, competitionId);
      }
    } catch (e) {
      debugPrint('獲取選手學校信息失敗: $e');
    } finally {
      if (mounted) {
        _safeSetState(() {
          _isLoadingSchools = false;
        });
      }
    }
  }

  // 獲取選手的學校，優先使用已加載的數據
  String getAthleteSchool(Map<String, dynamic> athlete) {
    final String id = athlete['athleteId'] ?? athlete['id'] ?? '';
    final String originalSchool = athlete['school'] ?? '';

    // 如果原始數據已有學校，或ID為空，則直接返回
    if (originalSchool.isNotEmpty || id.isEmpty) {
      return originalSchool;
    }

    // 否則嘗試從加載的數據中獲取
    return _athleteSchools[id] ?? ((_isLoadingSchools) ? '查詢中...' : '');
  }

  // 批量獲取運動員學校，提高效率
  Future<void> _batchLoadSchools(
      List<String> athleteIds, String competitionId) async {
    if (athleteIds.isEmpty || !mounted) return;

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final String collectionName = 'competition_$competitionId';

      // 使用一個批處理方式，直接獲取多個文檔的引用
      final List<Future<DocumentSnapshot>> futures = athleteIds
          .map((id) => firestore.collection(collectionName).doc(id).get())
          .toList();

      // 並行執行所有查詢，大大提高效率
      final results = await Future.wait(futures);

      // 處理結果
      if (!mounted) return;

      final Map<String, String> newSchools = {};
      for (int i = 0; i < athleteIds.length; i++) {
        final doc = results[i];
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null && data['school'] != null) {
            final school = data['school'] as String;
            if (school.isNotEmpty) {
              newSchools[athleteIds[i]] = school;
            }
          }
        }
      }

      if (newSchools.isNotEmpty) {
        _safeSetState(() {
          _athleteSchools.addAll(newSchools);
        });
      }
    } catch (e) {
      debugPrint('批量獲取學校信息失敗: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 獲取項目名稱
    final String eventName = widget.eventData['eventName'] ?? '未知項目';
    final String eventType = widget.eventData['eventType'] ?? '';

    // 確定項目類型和顏色
    Color typeColor;
    Color bgColor;
    IconData typeIcon;

    switch (eventType) {
      case '徑賽':
        typeColor = Colors.blue.shade700;
        bgColor = Colors.blue.shade50;
        typeIcon = Icons.directions_run;
        break;
      case '田賽':
        typeColor = Colors.green.shade700;
        bgColor = Colors.green.shade50;
        typeIcon = Icons.sports_volleyball;
        break;
      case '接力':
        typeColor = Colors.purple.shade700;
        bgColor = Colors.purple.shade50;
        typeIcon = Icons.people;
        break;
      default:
        typeColor = Colors.grey.shade700;
        bgColor = Colors.grey.shade50;
        typeIcon = Icons.sports;
    }

    // 獲取結果列表並排序
    List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(
        widget.eventData['results'] as List<dynamic>);

    results.sort((a, b) {
      final rankA = a['rank'] ?? 999;
      final rankB = b['rank'] ?? 999;
      return rankA.compareTo(rankB);
    });

    // 只取前8名
    if (results.length > 8) {
      results = results.sublist(0, 8);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(eventName),
        backgroundColor: typeColor,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              typeColor.withValues(alpha: 0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 標題
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 2,
                  shadowColor: typeColor.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          bgColor.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: bgColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(typeIcon, color: typeColor, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                eventName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: typeColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      eventType,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: typeColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '頒獎名單',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 表格標題
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14.0, horizontal: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.emoji_events_outlined,
                                  size: 16, color: typeColor),
                              const SizedBox(width: 4),
                              Text(
                                '排名',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: typeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_outline,
                                  size: 16, color: typeColor),
                              const SizedBox(width: 4),
                              Text(
                                '選手/成績',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: typeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.school_outlined,
                                  size: 16, color: typeColor),
                              const SizedBox(width: 4),
                              Text(
                                '代表學校',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: typeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // 運動員列表
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final athlete = results[index];
                    final int rank = athlete['rank'] ?? 0;
                    final String name =
                        athlete['athleteName'] ?? athlete['teamName'] ?? '未知';
                    final String school = getAthleteSchool(athlete);
                    final String result = _formatResult(athlete, eventType);

                    // 獎牌顏色和背景
                    Color? medalColor;
                    Color? backgroundColor;
                    String medal = '';
                    IconData medalIcon = Icons.emoji_events;

                    if (rank == 1) {
                      medalColor = Colors.amber.shade700;
                      backgroundColor = Colors.amber.shade50;
                      medal = '金牌';
                      medalIcon = Icons.workspace_premium;
                    } else if (rank == 2) {
                      medalColor = Colors.blueGrey.shade600;
                      backgroundColor = Colors.blueGrey.shade50;
                      medal = '銀牌';
                      medalIcon = Icons.workspace_premium;
                    } else if (rank == 3) {
                      medalColor = Colors.brown.shade600;
                      backgroundColor = Colors.orange.shade50;
                      medal = '銅牌';
                      medalIcon = Icons.workspace_premium;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10.0),
                      decoration: BoxDecoration(
                        color: backgroundColor ?? Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: rank <= 3
                            ? [
                                BoxShadow(
                                  color: (medalColor ?? Colors.grey)
                                      .withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                        border: Border.all(
                          color: rank <= 3
                              ? (medalColor?.withValues(alpha: 0.5) ??
                                  Colors.transparent)
                              : Colors.grey.shade200,
                          width: rank <= 3 ? 1 : 0.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16.0, horizontal: 16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // 排名
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      height: 44,
                                      width: 44,
                                      decoration: BoxDecoration(
                                        color: medalColor?.withValues(
                                                alpha: 0.1) ??
                                            Colors.grey.shade100,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: medalColor?.withValues(
                                                  alpha: 0.5) ??
                                              Colors.transparent,
                                          width: medalColor != null ? 1.5 : 0,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        rank.toString(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: medalColor ??
                                              Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                    if (rank <= 3)
                                      Positioned(
                                        right: -2,
                                        top: -4,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: medalColor!
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            medalIcon,
                                            color: medalColor,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),

                                const SizedBox(width: 16),

                                // 姓名和獎牌信息
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: rank <= 3
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          fontSize: 17,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (rank <= 3)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: medalColor?.withValues(
                                                alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            medal,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: medalColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      if (result.isNotEmpty)
                                        Text(
                                          result,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // 學校信息
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.school,
                                              size: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: _isLoadingSchools &&
                                                      school.isEmpty
                                                  ? Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        SizedBox(
                                                          width: 10,
                                                          height: 10,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                    Color>(
                                                              Colors.grey
                                                                  .shade400,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 6),
                                                        Text(
                                                          '查詢學校中...',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                            color: Colors
                                                                .grey.shade400,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ],
                                                    )
                                                  : Text(
                                                      school.isNotEmpty
                                                          ? school
                                                          : '無法獲取學校資訊',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: school.isNotEmpty
                                                            ? Colors
                                                                .grey.shade700
                                                            : Colors
                                                                .red.shade300,
                                                        fontStyle: school
                                                                .isNotEmpty
                                                            ? FontStyle.normal
                                                            : FontStyle.italic,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
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
                          // 第二部分：詳細資訊（只有排名前3的才顯示）
                          if (rank <= 3 && athlete['gender'] != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  if (athlete['gender'] != null)
                                    _buildInfoChip(
                                      athlete['gender'] == '男' ? '男子組' : '女子組',
                                      athlete['gender'] == '男'
                                          ? Colors.blue
                                          : Colors.pink,
                                    ),
                                  if (athlete['ageGroup'] != null)
                                    _buildInfoChip(
                                      athlete['ageGroup'],
                                      Colors.purple,
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // 頁腳說明
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300, width: 0.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '頒獎名單僅顯示前8名選手',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
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
}

// 添加這個方法，格式化運動員成績
String _formatResult(Map<String, dynamic> athlete, String eventType) {
  if (eventType == '徑賽' && athlete['time'] != null) {
    final time = athlete['time'];
    if (time is int) {
      // 將厘秒轉換為時間格式 (例如: 100厘秒 -> 1.00秒)
      final seconds = (time / 100).floor();
      final centiseconds = time % 100;
      return '$seconds.${centiseconds.toString().padLeft(2, '0')} 秒';
    } else if (time is String) {
      return time;
    }
  } else if (eventType == '田賽' && athlete['score'] != null) {
    final score = athlete['score'];
    if (score is num) {
      // 田賽成績可能是距離（米）或高度（米）
      return '${score.toStringAsFixed(2)} 米';
    } else if (score is String) {
      return score;
    }
  }
  return '';
}

// 添加這個方法，創建資訊標籤
Widget _buildInfoChip(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        color: color.withValues(alpha: 0.8),
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
