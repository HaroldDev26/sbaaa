import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // 新增導入
import '../utils/colors.dart';
import '../utils/utils.dart'; // 導入工具函數
import '../resources/auth_methods.dart';
import 'athlete_competition_view.dart';
import 'login_screen.dart';

/// 運動員首頁屏幕
///
/// 顯示運動員已加入的比賽和可報名的比賽
///
/// 優化項目：
/// 1. 批量加載數據 - 使用分批加載處理大量數據，避免Firebase查詢限制
/// 2. 錯誤處理 - 添加更好的錯誤提示和重試機制
/// 3. 狀態管理 - 改進狀態處理，防止內存泄漏和崩潰
/// 4. 程式碼結構 - 提取共用組件和方法，減少重複代碼
/// 5. UI性能 - 使用ListView.builder替代固定列表，提高大列表效能
/// 6. 用戶體驗 - 添加下拉刷新、震動反饋等功能
/// 7. 緩存機制 - 使用key和ValueKey添加緩存機制，減少不必要的重建
///
/// 作者：高級Flutter開發團隊

class AthleteHomeScreen extends StatefulWidget {
  final String userId;

  const AthleteHomeScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<AthleteHomeScreen> createState() => _AthleteHomeScreenState();
}

class _AthleteHomeScreenState extends State<AthleteHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthMethods _authMethods = AuthMethods();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _userCompetitions = [];
  List<Map<String, dynamic>> _availableCompetitions = [];
  List<Map<String, dynamic>> _filteredUserCompetitions = [];
  List<Map<String, dynamic>> _filteredAvailableCompetitions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserCompetitions();
    _loadAvailableCompetitions();
    _searchController.addListener(_filterCompetitions);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterCompetitions);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 更改：優化數據加載方法，使用異步批處理
  Future<void> _loadUserCompetitions() async {
    if (!mounted) return;

    try {
      setState(() => _isLoading = true);

      final userDoc =
          await _firestore.collection('users').doc(widget.userId).get();

      if (!userDoc.exists) {
        setState(() {
          _userCompetitions = [];
          _filteredUserCompetitions = [];
          _isLoading = false;
        });
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final List<dynamic> competitionIds = userData['competitions'] ?? [];

      if (competitionIds.isEmpty) {
        setState(() {
          _userCompetitions = [];
          _filteredUserCompetitions = [];
          _isLoading = false;
        });
        return;
      }

      // 優化：使用分批獲取，因為whereIn最多支持10個值
      final List<Map<String, dynamic>> allUserCompetitions = [];

      // 按每批10個ID分批處理
      for (int i = 0; i < competitionIds.length; i += 10) {
        final int end =
            (i + 10 < competitionIds.length) ? i + 10 : competitionIds.length;
        final batch = competitionIds.sublist(i, end);

        final batchSnapshot = await _firestore
            .collection('competitions')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        final batchCompetitions = batchSnapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList();

        allUserCompetitions.addAll(batchCompetitions);
      }

      if (mounted) {
        setState(() {
          _userCompetitions = allUserCompetitions;
          _filteredUserCompetitions = List.from(_userCompetitions);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加載用戶比賽失敗: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('無法加載您的比賽: $e');
      }
    }
  }

  // 加載可報名的比賽
  Future<void> _loadAvailableCompetitions() async {
    if (!mounted) return;

    try {
      setState(() => _isLoading = true);

      // 並行獲取用戶和比賽數據以提高效能
      final userDoc =
          await _firestore.collection('users').doc(widget.userId).get();
      final competitionsSnapshot =
          await _firestore.collection('competitions').get();

      if (!userDoc.exists) {
        setState(() {
          _availableCompetitions = [];
          _filteredAvailableCompetitions = [];
          _isLoading = false;
        });
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final List<dynamic> userCompetitionIds = userData['competitions'] ?? [];

      final allCompetitions = competitionsSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      final availableComps = allCompetitions
          .where((comp) => !userCompetitionIds.contains(comp['id']))
          .toList();

      if (mounted) {
        setState(() {
          _availableCompetitions = availableComps;
          _filteredAvailableCompetitions = List.from(_availableCompetitions);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加載可用比賽失敗: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('無法加載可用比賽: $e');
      }
    }
  }

  // 新增：顯示錯誤提示
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '重試',
          textColor: Colors.white,
          onPressed: () {
            _loadUserCompetitions();
            _loadAvailableCompetitions();
          },
        ),
      ),
    );
  }

  // 優化：改進過濾比賽功能，使其更高效
  void _filterCompetitions() {
    if (!mounted) return;

    final searchQuery = _searchController.text.toLowerCase();

    setState(() {
      // 使用單個過濾方法減少代碼重複
      _filteredUserCompetitions =
          _filterCompetitionList(_userCompetitions, searchQuery);
      _filteredAvailableCompetitions =
          _filterCompetitionList(_availableCompetitions, searchQuery);
    });
  }

  // 新增：共用的過濾邏輯
  List<Map<String, dynamic>> _filterCompetitionList(
      List<Map<String, dynamic>> competitions, String searchQuery) {
    if (searchQuery.isEmpty) {
      return List.from(competitions); // 無過濾條件，返回原始列表
    }

    return competitions.where((competition) {
      // 進行文本搜索
      final name = competition['name']?.toString().toLowerCase() ?? '';
      final venue = competition['venue']?.toString().toLowerCase() ?? '';
      final startDate =
          competition['startDate']?.toString().toLowerCase() ?? '';
      final endDate = competition['endDate']?.toString().toLowerCase() ?? '';
      final description =
          competition['description']?.toString().toLowerCase() ?? '';

      // 改進搜索，同時在多個字段中搜索
      return name.contains(searchQuery) ||
          venue.contains(searchQuery) ||
          startDate.contains(searchQuery) ||
          endDate.contains(searchQuery) ||
          description.contains(searchQuery);
    }).toList();
  }

  // 加入比賽
  Future<void> _joinCompetition(String competitionId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請先登錄才能加入比賽')),
        );
        return;
      }

      // 更新用戶的比賽列表
      await _firestore.collection('users').doc(currentUserId).update({
        'competitions': FieldValue.arrayUnion([competitionId])
      });

      // 更新比賽的參與者列表
      await _firestore.collection('competitions').doc(competitionId).update({
        'participants': FieldValue.arrayUnion([currentUserId])
      });

      // 重新加載比賽列表
      await _loadUserCompetitions();
      await _loadAvailableCompetitions();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('成功加入比賽')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入比賽失敗: $e')),
      );
    }
  }

  // 查看比賽詳情
  void _viewCompetitionDetails(String competitionId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AthleteCompetitionViewScreen(
          competitionId: competitionId,
        ),
      ),
    ).then((_) {
      // 返回時刷新數據
      _loadUserCompetitions();
      _loadAvailableCompetitions();
    });
  }

  // 登出
  Future<void> _signOut() async {
    try {
      await _authMethods.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/welcome');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登出失敗: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // 因為有兩個標籤頁：'我的比賽'和'可報名比賽'
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: primaryColor,
          title: const Text('運動員主頁'),
          elevation: 0, // 移除陰影
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _loadUserCompetitions();
                _loadAvailableCompetitions();
                HapticFeedback.mediumImpact(); // 添加震動反饋
              },
            ),
            // 添加SQLite測試按鈕
            IconButton(
              icon: const Icon(Icons.storage),
              tooltip: 'SQLite測試',
              onPressed: () {
                Navigator.pushNamed(context, '/sqlite_test');
              },
            ),
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: () async {
                // 登出並返回登入頁
                await _authMethods.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                }
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: '我的比賽'),
              Tab(text: '可報名比賽'),
            ],
          ),
        ),
        body: Column(
          children: [
            // 添加運動員資料卡片
            _buildAthleteProfileCard(),

            // 搜索和過濾
            _buildSearchBar(),

            // 標籤欄
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const TabBar(
                tabs: [
                  Tab(
                    icon: Icon(Icons.sports),
                    text: '已追蹤比賽',
                  ),
                  Tab(
                    icon: Icon(Icons.add_circle_outline),
                    text: '可報名比賽',
                  ),
                ],
                labelColor: primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: primaryColor,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),

            // 標籤頁內容
            Expanded(
              child: TabBarView(
                children: [
                  _buildTrackedCompetitionsTab(),
                  _buildAvailableCompetitionsTab(),
                ],
              ),
            ),
          ],
        ),
        // 添加浮動按鈕進入SQLite測試頁面
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.pushNamed(context, '/sqlite_test');
          },
          backgroundColor: Colors.orange,
          icon: const Icon(Icons.storage),
          label: const Text('測試SQLite'),
        ),
      ),
    );
  }

  // 建立運動員資料卡片
  Widget _buildAthleteProfileCard() {
    // 使用唯一key確保在setState時重新構建FutureBuilder
    return FutureBuilder(
      // 添加key以確保在setState時重新構建
      key: ValueKey<DateTime>(DateTime.now()),
      future: _firestore.collection('users').doc(widget.userId).get(),
      builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        Map<String, dynamic> userData =
            snapshot.data!.data() as Map<String, dynamic>;
        String username = userData['username'] ?? '用戶';
        String email = userData['email'] ?? '';
        String gender = userData['gender'] ?? '未設置';
        String profileImageUrl = userData['profileImage'] ?? '';
        String birthday = userData['birthday'] ?? '';

        // 使用工具函數計算年齡
        final age = calculateAge(birthday);
        final ageText = age != null ? age.toString() : '未知';

        // 從Firebase獲取適合的年齡組別
        return FutureBuilder<String>(
            future: age != null ? Future.value('') : Future.value(''),
            builder: (context, ageGroupSnapshot) {
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor.withValues(alpha: 0.7),
                        primaryColor
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // 頭像區域
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.white,
                                backgroundImage: profileImageUrl.isNotEmpty
                                    ? NetworkImage(profileImageUrl)
                                    : null,
                                child: profileImageUrl.isEmpty
                                    ? const Icon(Icons.person,
                                        size: 40, color: Colors.grey)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: primaryColor, width: 1.5),
                                  ),
                                  child: Icon(
                                    gender == '男'
                                        ? Icons.male
                                        : (gender == '女'
                                            ? Icons.female
                                            : Icons.person),
                                    size: 12,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // 用戶信息區域
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '歡迎回來，$username',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 添加運動員統計信息
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                              '已追蹤的比賽',
                              _userCompetitions.length.toString(),
                              Icons.emoji_events),
                          GestureDetector(
                            onTap: () =>
                                _showAgeDetails(context, age, birthday),
                            child:
                                _buildStatItem('年齡', '$ageText 歲', Icons.cake),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(
                                    context, '/athlete-edit-profile')
                                .then((result) {
                              if (result == true) {
                                // 如果編輯頁面返回true，表示資料已更新，需要刷新頁面
                                setState(() {});
                                _loadUserCompetitions();
                                _loadAvailableCompetitions();
                              }
                            }),
                            child: _buildStatItem(
                                '個人資料', '編輯', Icons.account_circle),
                          ),
                          GestureDetector(
                            onTap: _signOut,
                            child: _buildStatItem('登出', '點擊', Icons.logout),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            });
      },
    );
  }

  // 顯示年齡詳細信息
  void _showAgeDetails(BuildContext context, int? age, String birthday) {
    if (age == null || birthday.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未設置出生日期，無法計算年齡')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('運動員年齡信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('當前年齡: $age 歲'),
            const SizedBox(height: 8),
            Text('出生日期: $birthday'),
            const SizedBox(height: 16),
            const Text(
              '年齡計算基於當前日期，用於確定比賽組別和資格。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  // 構建統計項目
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // 構建搜索欄 - 優化版
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: '搜索比賽名稱、地點或日期',
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  // 構建底部選項菜單
  Widget _buildOptionsBottomSheet() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '更多操作',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.blue),
              title: const Text('刷新比賽列表'),
              onTap: () {
                Navigator.pop(context);
                _loadUserCompetitions();
                _loadAvailableCompetitions();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已刷新比賽列表')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.green),
              title: const Text('查看個人資料'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/athlete-edit-profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.orange),
              title: const Text('常見問題'),
              onTap: () {
                Navigator.pop(context);
                // 顯示常見問題對話框
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('常見問題'),
                    content: const SingleChildScrollView(
                      child: ListBody(
                        children: [
                          Text('Q: 如何報名比賽？',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('A: 在「可報名比賽」標籤頁中，點擊相應比賽卡片上的「加入比賽」按鈕即可。'),
                          SizedBox(height: 8),
                          Text('Q: 如何查看我的比賽詳情？',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('A: 在「已追蹤比賽」標籤頁中，點擊相應比賽卡片上的「查看詳情」按鈕。'),
                          SizedBox(height: 8),
                          Text('Q: 如何搜索特定比賽？',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('A: 使用頁面頂部的搜索欄輸入比賽名稱、地點或日期關鍵詞進行搜索。'),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('關閉'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 優化：提取構建比賽卡片為更高效的方法
  Widget _buildCompetitionItem(
      Map<String, dynamic> competition, bool isRegistered) {
    final String competitionId = competition['id'] ?? '';
    final String competitionName = competition['name'] ?? '未命名比賽';
    final String venue = competition['venue'] ?? '未設置場地';
    final String startDate =
        competition['startDate'] ?? competition['date'] ?? '未設置日期';
    final String endDate = competition['endDate'] ?? startDate;
    final String description = competition['description'] ?? '';

    // 獲取參與者數量
    final List<dynamic>? participants =
        competition['participants'] as List<dynamic>?;
    final int participantsCount = participants?.length ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2, // 降低陰影以提高性能
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _viewCompetitionDetails(competitionId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 標題和狀態徽章
              Row(
                children: [
                  Expanded(
                    child: Text(
                      competitionName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 描述（如果有）
              if (description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    description,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              const Divider(),

              // 比賽信息
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    // 場地和日期行
                    Row(
                      children: [
                        _buildInfoItem(Icons.location_on, venue),
                        const SizedBox(width: 12),
                        _buildInfoItem(Icons.calendar_today, startDate),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 參與者和結束日期行
                    Row(
                      children: [
                        _buildInfoItem(Icons.people, '$participantsCount 名參與者'),
                        const SizedBox(width: 12),
                        if (endDate != startDate)
                          _buildInfoItem(Icons.event_available, '結束: $endDate'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 主操作按鈕
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isRegistered)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _viewCompetitionDetails(competitionId),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('查看詳情'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 1,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _joinCompetition(competitionId),
                        icon: const Icon(Icons.add_circle, size: 18),
                        label: const Text('加入比賽'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 1,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 構建信息項目
  Widget _buildInfoItem(IconData icon, String text) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // 優化：構建已追蹤比賽標籤頁
  Widget _buildTrackedCompetitionsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredUserCompetitions.isEmpty) {
      return Center(
        child: _buildEmptyState(
          icon: Icons.sports_outlined,
          title: '您尚未追蹤任何比賽',
          message: _searchController.text.isNotEmpty
              ? '嘗試使用不同的搜索關鍵詞'
              : '點擊"可報名比賽"標籤查看可用比賽',
        ),
      );
    }

    // 使用RefreshIndicator支持下拉刷新
    return RefreshIndicator(
      onRefresh: () async {
        // 加入輕度震動反饋
        HapticFeedback.lightImpact();
        await _loadUserCompetitions();
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _scrollController,
        itemCount: _filteredUserCompetitions.length, // 移除+1，不再顯示統計信息頭部
        itemBuilder: (context, index) {
          // 直接顯示比賽卡片，不再需要額外條件檢查
          final competition = _filteredUserCompetitions[index];
          return _buildCompetitionItem(competition, true);
        },
      ),
    );
  }

  // 優化：構建可報名比賽標籤頁 - 使用ListView.builder
  Widget _buildAvailableCompetitionsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredAvailableCompetitions.isEmpty) {
      return Center(
        child: _buildEmptyState(
          icon: Icons.search_off,
          title:
              _searchController.text.isNotEmpty ? '找不到符合條件的比賽' : '目前沒有可報名的比賽',
          message: _searchController.text.isNotEmpty ? '嘗試修改搜索條件' : '稍後再來查看',
        ),
      );
    }

    // 使用延遲加載設計模式
    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
        await _loadAvailableCompetitions();
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _scrollController,
        itemCount:
            2 + _filteredAvailableCompetitions.length, // 1個推薦區塊 + 1個標題 + 列表
        itemBuilder: (context, index) {
          // 推薦區塊
          if (index == 0) {
            return _buildRecommendedSection();
          }

          // "全部比賽"標題
          if (index == 1) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '全部比賽',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A0E53),
                ),
              ),
            );
          }

          // 比賽卡片
          final competition =
              _filteredAvailableCompetitions[index - 2]; // -2 因為前面有推薦和標題
          return _buildCompetitionItem(competition, false);
        },
      ),
    );
  }

  // 新增：構建推薦部分
  Widget _buildRecommendedSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      // 加入緩存：使用key確保每次刷新時重建
      key: ValueKey(_searchController.text),
      future: _getRecommendedCompetitions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '🌟 為您推薦',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A0E53),
                ),
              ),
            ),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: snapshot.data!.length,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemBuilder: (context, index) {
                  final competition = snapshot.data![index];
                  return _buildRecommendedCompetitionCard(competition);
                },
              ),
            ),
            const Divider(height: 24, indent: 16, endIndent: 16),
          ],
        );
      },
    );
  }

  // 為運動員推薦適合的比賽
  Future<List<Map<String, dynamic>>> _getRecommendedCompetitions() async {
    try {
      // 獲取用戶生日
      final userDoc =
          await _firestore.collection('users').doc(widget.userId).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data() as Map<String, dynamic>;
      final birthday = userData['birthday'] as String?;
      if (birthday == null || birthday.isEmpty) return [];

      final age = calculateAge(birthday);
      if (age == null) return [];

      // 根據年齡篩選適合的比賽
      return _filteredAvailableCompetitions
          .where((comp) {
            // 如果比賽有metadata
            if (comp['metadata'] != null) {
              // 嘗試從年齡組別中篩選
              if (comp['metadata']['age_groups'] != null) {
                List<dynamic> ageGroups = comp['metadata']['age_groups'];

                for (var group in ageGroups) {
                  if (group is Map<String, dynamic> &&
                      group.containsKey('minAge') &&
                      group.containsKey('maxAge')) {
                    int minAge = group['minAge'];
                    int maxAge = group['maxAge'];

                    if (age >= minAge && age <= maxAge) {
                      return true;
                    }
                  }
                }
              }

              // 嘗試從報名表單中篩選
              if (comp['metadata']['registration_form'] != null) {
                final form = comp['metadata']['registration_form']
                    as Map<String, dynamic>?;
                if (form != null) {
                  // 檢查年齡限制
                  final minAge = form['min_age'];
                  final maxAge = form['max_age'];

                  if (minAge != null && maxAge != null) {
                    return age >= minAge && age <= maxAge;
                  }
                }
              }
            }

            // 如果沒有年齡限制，默認返回false（不推薦）
            return false;
          })
          .take(5)
          .toList();
    } catch (e) {
      debugPrint('獲取推薦比賽出錯: $e');
      return [];
    }
  }

  // 構建推薦比賽卡片
  Widget _buildRecommendedCompetitionCard(Map<String, dynamic> competition) {
    final name = competition['name'] as String? ?? '未命名比賽';
    final venue = competition['venue'] as String? ?? '未知場地';
    final startDate = competition['startDate'] as String? ?? '未知日期';

    // 計算報名截止日期剩餘天數
    String? deadlineText;
    if (competition['metadata'] != null &&
        competition['metadata']['registration_form'] != null &&
        competition['metadata']['registration_form']['deadline'] != null) {
      try {
        final deadline =
            competition['metadata']['registration_form']['deadline'];
        DateTime deadlineDate;

        if (deadline is String) {
          deadlineDate = DateTime.parse(deadline);
        } else if (deadline is Timestamp) {
          deadlineDate = deadline.toDate();
        } else {
          throw Exception('不支援的日期格式');
        }

        final now = DateTime.now();
        final daysRemaining = deadlineDate.difference(now).inDays;

        if (daysRemaining > 0) {
          deadlineText = '剩餘 $daysRemaining 天';
        } else if (daysRemaining == 0) {
          deadlineText = '今天截止!';
        } else {
          deadlineText = '已截止報名';
        }
      } catch (e) {
        debugPrint('計算報名截止日期出錯: $e');
      }
    }

    return Container(
      width: 250,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.star, size: 14, color: Colors.amber[700]),
                const SizedBox(width: 4),
                const Text(
                  '適合您的年齡',
                  style: TextStyle(
                    fontSize: 12,
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        venue,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      startDate.split('T')[0],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                if (deadlineText != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 14,
                          color: deadlineText.contains('已截止')
                              ? Colors.red
                              : (deadlineText.contains('今天')
                                  ? Colors.orange
                                  : Colors.green)),
                      const SizedBox(width: 4),
                      Text(
                        deadlineText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: deadlineText.contains('已截止')
                              ? Colors.red
                              : (deadlineText.contains('今天')
                                  ? Colors.orange
                                  : Colors.green),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _viewCompetitionDetails(competition['id']),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: const BorderSide(color: primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('查看詳情'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _joinCompetition(competition['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('立即報名'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 構建空狀態
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 72,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _filterCompetitions();
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('重置搜索條件'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
