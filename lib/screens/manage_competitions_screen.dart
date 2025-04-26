import 'package:flutter/material.dart';
import '../models/competition.dart';
import '../utils/colors.dart';
import '../utils/sorting_function.dart';
import '../data/competition_data.dart'; // 導入數據管理類
import 'create_competition_screen.dart';
import 'competition_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageCompetitionsScreen extends StatefulWidget {
  const ManageCompetitionsScreen({Key? key}) : super(key: key);

  @override
  State<ManageCompetitionsScreen> createState() =>
      _ManageCompetitionsScreenState();
}

class _ManageCompetitionsScreenState extends State<ManageCompetitionsScreen> {
  // 數據管理實例
  final CompetitionData _competitionData = CompetitionData();
  final TextEditingController _searchController = TextEditingController();
  List<CompetitionModel> _competitions = [];
  List<CompetitionModel> _filteredCompetitions = [];
  bool _isLoading = true;
  String _selectedFilter = '全部'; // 預設過濾選項
  int _selectedIndex = 0; // 底部導航欄選中項

  @override
  void initState() {
    super.initState();
    _fetchCompetitions();
    _searchController.addListener(_filterCompetitions);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterCompetitions);
    _searchController.dispose();
    super.dispose();
  }

  // 過濾比賽列表
  void _filterCompetitions() async {
    final query = _searchController.text;

    setState(() {
      _isLoading = true;
    });

    try {
      // 使用數據管理類獲取過濾後的比賽列表
      final results = await _competitionData.getFilteredCompetitions(
          query, _selectedFilter);

      setState(() {
        _filteredCompetitions = insertionSort(results);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('過濾比賽列表出錯: $e')),
        );
      }
    }
  }

  // 根據選擇的篩選條件過濾比賽
  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _filterCompetitions();
    });
  }

  // 獲取比賽列表
  Future<void> _fetchCompetitions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 使用數據管理類加載比賽
      await _competitionData.loadCompetitions();

      setState(() {
        _competitions = _competitionData.competitions;
        _filteredCompetitions = insertionSort(_competitions);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('獲取比賽列表失敗: $e')),
        );
      }
    }
  }

  // 編輯比賽
  void _editCompetition(CompetitionModel competition) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompetitionDetailScreen(competition: competition),
      ),
    ).then((result) {
      if (result == true) {
        // 如果操作成功，刷新比賽列表
        _fetchCompetitions();
      }
    });
  }

  // 刪除比賽
  Future<void> _deleteCompetition(CompetitionModel competition) async {
    // 獲取當前用戶ID
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請先登錄才能執行此操作')),
        );
      }
      return;
    }

    // 檢查權限
    bool hasDeletePermission = false;

    // 檢查比賽創建者ID
    final creatorUid = competition.metadata?['createdByUid'] as String?;
    if (creatorUid != null && creatorUid == currentUserId) {
      hasDeletePermission = true;
    } else {
      // 檢查權限列表
      final permissions =
          competition.metadata?['permissions'] as Map<String, dynamic>?;
      if (permissions != null) {
        final canDelete = permissions['canDelete'] as List<dynamic>?;
        if (canDelete != null && canDelete.contains(currentUserId)) {
          hasDeletePermission = true;
        }
      }
    }

    // 如果沒有權限，顯示錯誤訊息
    if (!hasDeletePermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('只有比賽創建者才能刪除此比賽')),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除比賽 "${competition.name}" 嗎？此操作不可撤銷。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 使用數據管理類刪除比賽
        await _competitionData.deleteCompetition(competition.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('比賽已刪除')),
          );
        }

        // 刷新顯示
        _fetchCompetitions();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('刪除失敗: $e')),
          );
        }
      }
    }
  }

  // 創建新比賽
  void _createCompetition() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateCompetitionScreen(),
      ),
    ).then((result) {
      if (result == true) {
        // 如果操作成功，刷新比賽列表
        _fetchCompetitions();
      }
    });
  }

  // 底部導航欄切換
  void _onBottomNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // 根據選中的項目執行不同操作
    switch (index) {
      case 0: // 比賽列表
        break;
      case 1: // 創建比賽
        _createCompetition();
        break;
      case 2: // 返回
        Navigator.pop(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('管理比賽', style: TextStyle(color: Colors.white)),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // 搜索欄
          Container(
            padding: const EdgeInsets.all(16),
            color: Color.fromRGBO(
              primaryColor.red,
              primaryColor.green,
              primaryColor.blue,
              0.1,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: '搜索比賽名稱',
                    prefixIcon: Icon(Icons.search),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: Colors.black, width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: Colors.black, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                  onChanged: (value) {
                    // 每次輸入變更時執行搜索
                    _filterCompetitions();
                  },
                ),
                const SizedBox(height: 12),
                // 過濾選項
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('全部'),
                      _buildFilterChip('計劃中'),
                      _buildFilterChip('進行中'),
                      _buildFilterChip('已結束'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 比賽列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCompetitions.isEmpty
                    ? const Center(child: Text('沒有找到符合條件的比賽'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _filteredCompetitions.length,
                        itemBuilder: (context, index) {
                          final competition = _filteredCompetitions[index];
                          return _buildCompetitionCard(competition);
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTapped,
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.format_list_bulleted),
            label: '比賽列表',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: '創建比賽',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.arrow_back),
            label: '返回',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createCompetition,
        backgroundColor: primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  // 構建過濾選項
  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            _applyFilter(label);
          }
        },
        backgroundColor: Colors.white,
        selectedColor: primaryColor.withOpacity(0.2),
        checkmarkColor: primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? primaryColor : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  // 構建比賽卡片
  Widget _buildCompetitionCard(CompetitionModel competition) {
    // 根據狀態選擇顏色
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

    // 獲取當前用戶ID
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    // 檢查當前用戶是否為比賽創建者或有刪除權限
    final canDelete = competition.canUserDelete(currentUserId);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.black, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    competition.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    competition.status,
                    style: TextStyle(color: statusColor, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              competition.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  competition.venue ?? '未設置場地',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  competition.startDate,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (competition.createdByUid.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '創建者: ${competition.createdBy}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: () => _editCompetition(competition),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A0E53),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                    ),
                    child: const Text(
                      '管理',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 只有有權限刪除的用戶才能看到刪除按鈕
                if (canDelete)
                  TextButton.icon(
                    onPressed: () => _deleteCompetition(competition),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('刪除'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
