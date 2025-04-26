import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/competition.dart';
import '../utils/colors.dart';
import '../models/user.dart';
import '../resources/auth_methods.dart';
import 'edit_competition_basic_info_screen.dart';
import 'character_management.dart';
import 'create_registration_form_screen.dart';
import 'registrations_list_screen.dart';
import '../utils/utils.dart';
import 'name_list.dart';
import 'score_recording_setup_screen.dart';
import 'result/result_record.dart';
import 'statistics/statistics_screen.dart';

class CompetitionDetailScreen extends StatefulWidget {
  final CompetitionModel competition;

  const CompetitionDetailScreen({
    Key? key,
    required this.competition,
  }) : super(key: key);

  @override
  State<CompetitionDetailScreen> createState() =>
      _CompetitionDetailScreenState();
}

class _CompetitionDetailScreenState extends State<CompetitionDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthMethods _authMethods = AuthMethods();

  // 創建者/管理員數據
  UserModel? _adminUser;
  bool _isLoadingAdmin = true;
  String _adminError = '';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  // 載入管理員/創建者數據
  Future<void> _loadAdminData() async {
    setState(() {
      _isLoadingAdmin = true;
    });

    try {
      // 檢查競賽是否有創建者UID
      String? creatorUid;

      // 優先嘗試使用competition.createdByUid
      if (widget.competition.createdByUid.isNotEmpty) {
        creatorUid = widget.competition.createdByUid;
      }
      // 如果沒有，再從metadata中查找
      else if (widget.competition.metadata != null &&
          widget.competition.metadata!.containsKey('createdByUid') &&
          widget.competition.metadata!['createdByUid'] != null) {
        final metadataUid = widget.competition.metadata!['createdByUid'];
        if (metadataUid is String && metadataUid.isNotEmpty) {
          creatorUid = metadataUid;
        }
      }

      // 如果找到了創建者UID，嘗試獲取用戶數據
      if (creatorUid != null && creatorUid.isNotEmpty) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(creatorUid).get();

        if (userDoc.exists) {
          setState(() {
            _adminUser = UserModel.fromDoc(userDoc);
            _isLoadingAdmin = false;
          });
          return;
        }
      }

      // 如果沒有創建者UID或找不到用戶，嘗試通過創建者名稱找到用戶
      if (widget.competition.createdBy.isNotEmpty) {
        QuerySnapshot query = await _firestore
            .collection('users')
            .where('username', isEqualTo: widget.competition.createdBy)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          setState(() {
            _adminUser = UserModel.fromDoc(query.docs.first);
            _isLoadingAdmin = false;
          });
          return;
        }
      }

      // 如果找不到創建者，默認使用當前用戶（如果是管理員）
      UserModel? currentUser = await _authMethods.getCurrentUser();
      if (currentUser != null && currentUser.role == '裁判') {
        setState(() {
          _adminUser = currentUser;
          _isLoadingAdmin = false;
        });
        return;
      }

      setState(() {
        _adminError = '找不到比賽創建者信息';
        _isLoadingAdmin = false;
      });
    } catch (e) {
      setState(() {
        _adminError = '載入管理員數據失敗: $e';
        _isLoadingAdmin = false;
      });
    }
  }

  // 計算用戶年齡
  int? calculateUserAge(String? birthdayString) {
    if (birthdayString == null || birthdayString.isEmpty) return null;

    try {
      // 使用 utils.dart 中的函數計算年齡
      return calculateAge(birthdayString);
    } catch (e) {
      debugPrint('計算年齡時出錯: $e');
      return null;
    }
  }

  // 側邊欄管理工具列表
  final List<Map<String, dynamic>> _drawerTools = [
    {
      'icon': Icons.edit_note,
      'title': '編輯比賽資料',
      'onTap': () {},
    },
    {
      'icon': Icons.assignment_outlined,
      'title': '報名控制',
      'onTap': () {},
    },
    {
      'icon': Icons.people_outline,
      'title': '管理出賽名單',
      'onTap': () {},
    },
    {
      'icon': Icons.security,
      'title': '管理比賽權限',
      'onTap': () {},
    },
    {
      'icon': Icons.description_outlined,
      'title': '比賽章程管理',
      'onTap': () {},
    },
    {
      'icon': Icons.campaign_outlined,
      'title': '公布公開消息',
      'onTap': () {},
    },
    {
      'icon': Icons.timer_outlined,
      'title': '成績計時',
      'onTap': () {},
    },
  ];

  // 構建管理員信息卡片
  Widget _buildAdminInfoCard() {
    if (_isLoadingAdmin) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey[300],
                radius: 24,
                child: Icon(Icons.person, color: Colors.grey[600]),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '載入中...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    LinearProgressIndicator(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_adminError.isNotEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.red[100],
                radius: 24,
                child: const Icon(Icons.error_outline, color: Colors.red),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '比賽管理員',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _adminError,
                      style: TextStyle(color: Colors.red[700], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: primaryColor.withOpacity(0.1),
              radius: 24,
              backgroundImage: _adminUser?.profileImage != null
                  ? NetworkImage(_adminUser!.profileImage!)
                  : null,
              child: _adminUser?.profileImage == null
                  ? const Icon(Icons.person, color: primaryColor)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _adminUser?.username ?? widget.competition.createdBy,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _adminUser?.email ?? '比賽管理員',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  if (_adminUser?.school != null &&
                      _adminUser!.school!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '學校: ${_adminUser!.school}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('編輯資料'),
              onPressed: () {
                final currentUserUid = _auth.currentUser?.uid;
                final creatorUid =
                    widget.competition.metadata?['createdByUid'] ?? '';

                if (currentUserUid == creatorUid ||
                    _adminUser?.uid == currentUserUid) {
                  Navigator.pushNamed(context, '/athlete-edit-profile')
                      .then((_) {
                    _loadAdminData();
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('只有創建者才能編輯個人資料')),
                  );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF0A0E53)),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          '比賽管理',
          style: TextStyle(
            color: Color(0xFF0A0E53),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0A0E53)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 比賽信息卡片
              _buildCompetitionCard(),

              const SizedBox(height: 16),

              // 報名管理員資料卡片
              _buildAdminInfoCard(),

              const SizedBox(height: 16),

              // 管理工具標題
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                child: Text(
                  '管理工具',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A0E53),
                  ),
                ),
              ),

              // 管理工具網格
              _buildManagementTools(),

              const SizedBox(height: 16),

              // 底部聯絡資訊
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // 側邊抽屜
  Widget _buildDrawer() {
    final currentUserUid = _auth.currentUser?.uid;
    final bool isCreator = widget.competition.createdByUid == currentUserUid;

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '比賽管理工具',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.competition.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _drawerTools.length,
              itemBuilder: (context, index) {
                final tool = _drawerTools[index];

                // 檢查權限 - 只有創建者可以管理權限
                if (tool['title'] == '管理比賽權限' && !isCreator) {
                  return const SizedBox.shrink();
                }

                return ListTile(
                  leading: Icon(tool['icon']),
                  title: Text(tool['title']),
                  onTap: () {
                    Navigator.pop(context); // 先關閉抽屜

                    if (tool['title'] == '編輯比賽資料') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditCompetitionBasicInfoScreen(
                            competition: widget.competition,
                          ),
                        ),
                      ).then((result) {
                        if (result == true) {
                          Navigator.pop(context, true);
                        }
                      });
                    } else if (tool['title'] == '管理比賽權限') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CharacterManagementScreen(
                            competition: widget.competition,
                          ),
                        ),
                      );
                    } else if (tool['onTap'] != null) {
                      tool['onTap']();
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 比賽資訊卡片
  Widget _buildCompetitionCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.competition.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A0E53),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('校際運動會',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(width: 16),
                Text(
                  widget.competition.startDate.toString().substring(0, 10),
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(width: 16),
                Text(
                  widget.competition.venue ?? '中央運動場',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '進行中',
                    style: TextStyle(color: Colors.green[800], fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 管理工具網格
  Widget _buildManagementTools() {
    // 獲取當前用戶ID
    final currentUserId = _auth.currentUser?.uid;
    final isCreator = widget.competition.createdByUid == currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              // 編輯比賽資料
              _buildToolButton(
                icon: Icons.edit_outlined,
                label: '編輯比賽',
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditCompetitionBasicInfoScreen(
                        competition: widget.competition,
                      ),
                    ),
                  ).then((result) {
                    if (result == true) {
                      Navigator.pop(context, true);
                    }
                  });
                },
              ),

              // 報名管理
              _buildToolButton(
                icon: Icons.app_registration_outlined,
                label: '報名管理',
                color: Colors.green,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: const Text('報名控制'),
                      children: [
                        SimpleDialogOption(
                          onPressed: () {
                            Navigator.pop(context); // 關閉對話框
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CreateRegistrationFormScreen(
                                  competitionId: widget.competition.id,
                                  competitionName: widget.competition.name,
                                ),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Icon(Icons.edit_document),
                                SizedBox(width: 12),
                                Text('設置報名表格'),
                              ],
                            ),
                          ),
                        ),
                        SimpleDialogOption(
                          onPressed: () {
                            Navigator.pop(context); // 關閉對話框
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RegistrationsListScreen(
                                  competitionId: widget.competition.id,
                                  competitionName: widget.competition.name,
                                ),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Icon(Icons.list_alt),
                                SizedBox(width: 12),
                                Text('查看已報名運動員'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // 權限管理
              _buildToolButton(
                icon: Icons.admin_panel_settings_outlined,
                label: '權限管理',
                color: Colors.purple,
                onTap: () {
                  if (isCreator) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CharacterManagementScreen(
                          competition: widget.competition,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('只有比賽創建者才能管理權限')),
                    );
                  }
                },
              ),

              // 項目管理
              _buildToolButton(
                icon: Icons.event_note_outlined,
                label: '項目管理',
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ScoreRecordingSetupScreen(
                        competitionId: widget.competition.id,
                        competitionName: widget.competition.name,
                      ),
                    ),
                  );
                },
              ),

              // 成績記錄
              _buildToolButton(
                icon: Icons.sports_outlined,
                label: '成績記錄',
                color: Colors.teal,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ResultRecordScreen(
                        competitionId: widget.competition.id,
                        competitionName: widget.competition.name,
                      ),
                    ),
                  );
                },
              ),

              // 成績管理
              _buildToolButton(
                icon: Icons.assessment_outlined,
                label: '成績管理',
                color: Colors.amber,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('成績管理功能即將上線')),
                  );
                },
              ),

              // 分組名單
              _buildToolButton(
                icon: Icons.people_alt_outlined,
                label: '分組名單',
                color: primaryColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NameListScreen(
                        competitionId: widget.competition.id,
                        competitionName: widget.competition.name,
                      ),
                    ),
                  );
                },
              ),

              // 獎項管理
              _buildToolButton(
                icon: Icons.emoji_events_outlined,
                label: '獎項管理',
                color: Colors.deepOrange,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('獎項管理功能即將上線')),
                  );
                },
              ),

              // 數據統計
              _buildToolButton(
                icon: Icons.bar_chart_outlined,
                label: '數據統計',
                color: Colors.indigo,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StatisticsScreen(
                        competitionId: widget.competition.id,
                        competitionName: widget.competition.name,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 構建工具按鈕
  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // 構建統計選項
  Widget _buildStatisticOption({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isDisabled = false,
  }) {
    return InkWell(
      onTap: isDisabled
          ? null
          : () {
              Navigator.pop(context); // 關閉對話框
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('正在開發$title功能，敬請期待')),
              );
              // TODO: 實現跳轉到相應的數據分析頁面
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => StatisticsScreen(
              //       competitionId: widget.competition.id,
              //       competitionName: widget.competition.name,
              //       statisticType: title,
              //     ),
              //   ),
              // );
            },
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Icon(icon, color: Colors.indigo),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isDisabled) Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // 頁尾聯絡資訊
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Center(
        child: Column(
          children: [
            Text(
              '© ${DateTime.now().year} 校際比賽管理系統',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                // 測試計算年齡功能
                String testBirthday = '2000-01-01';
                int? age = calculateUserAge(testBirthday);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('出生日期 $testBirthday 的年齡是: ${age ?? "無法計算"} 歲')),
                );
              },
              child: const Text('測試計算年齡', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
