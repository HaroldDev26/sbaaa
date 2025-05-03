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
import 'name_list.dart';
import 'score_recording_setup_screen.dart';
import 'result/result_record.dart';
import 'statistics/statistics_screen.dart';
import 'result/result_manage_screen.dart';
import 'award_list_screen.dart';

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

  // 側邊欄管理工具列表
  final List<Map<String, dynamic>> _drawerTools = [
    // 比賽管理類
    {
      'category': '比賽設置',
      'isCategory': true,
    },
    {
      'icon': Icons.edit_outlined,
      'title': '編輯比賽',
      'color': Colors.blue,
      'subtitle': '修改比賽基本信息和設置',
      'forCreator': true,
      'onTap': () {},
    },
    {
      'icon': Icons.event_note_outlined,
      'title': '項目管理',
      'color': Colors.orange,
      'subtitle': '管理比賽項目和設置',
      'roles': ['score'],
      'onTap': () {},
    },
    {
      'icon': Icons.admin_panel_settings_outlined,
      'title': '權限管理',
      'color': Colors.purple,
      'subtitle': '設置用戶角色和權限',
      'forCreator': true,
      'onTap': () {},
    },

    // 報名和參賽者管理類
    {
      'category': '參賽者管理',
      'isCategory': true,
    },
    {
      'icon': Icons.app_registration_outlined,
      'title': '報名管理',
      'color': Colors.green,
      'subtitle': '管理報名表格和申請',
      'roles': ['registration'],
      'onTap': () {},
    },
    {
      'icon': Icons.people_alt_outlined,
      'title': '分組名單',
      'color': primaryColor,
      'subtitle': '查看和管理參賽者分組',
      'roles': ['registration', 'score'],
      'onTap': () {},
    },

    // 成績和獎項管理類
    {
      'category': '成績和獎項',
      'isCategory': true,
    },
    {
      'icon': Icons.sports_outlined,
      'title': '成績記錄',
      'color': Colors.teal,
      'subtitle': '記錄比賽成績數據',
      'roles': ['score'],
      'onTap': () {},
    },
    {
      'icon': Icons.assessment_outlined,
      'title': '成績管理',
      'color': Colors.amber,
      'subtitle': '管理和審核比賽成績',
      'roles': ['score'],
      'onTap': () {},
    },
    {
      'icon': Icons.emoji_events_outlined,
      'title': '獎項管理',
      'color': Colors.deepOrange,
      'subtitle': '管理獎牌和頒獎儀式',
      'roles': ['award'],
      'onTap': () {},
    },
    {
      'icon': Icons.bar_chart_outlined,
      'title': '數據統計',
      'color': Colors.indigo,
      'subtitle': '查看競賽數據和統計',
      'roles': ['award'],
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
              backgroundColor: primaryColor.withValues(alpha: 0.1),
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
                  // 顯示用戶角色
                  _buildUserRoles(),
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

  // 構建用戶角色顯示
  Widget _buildUserRoles() {
    final currentUserUid = _auth.currentUser?.uid;
    if (currentUserUid == null) return const SizedBox.shrink();

    List<String> roles = [];

    // 檢查是否為比賽創建者
    if (widget.competition.createdByUid == currentUserUid) {
      // 如果是創建者，則只顯示「創建者」角色，不顯示其他角色
      roles.add('創建者');
    } else {
      // 如果不是創建者，才檢查其他角色
      if (widget.competition.hasRole(currentUserUid, 'registration')) {
        roles.add('報名管理員');
      }

      if (widget.competition.hasRole(currentUserUid, 'score')) {
        roles.add('成績管理員');
      }

      if (widget.competition.hasRole(currentUserUid, 'award')) {
        roles.add('頒獎典禮管理員');
      }
    }

    if (roles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              roles.join(' • '),
              style: TextStyle(
                color: primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
      child: Container(
        color: primaryColor, // 整個側邊欄使用統一的背景色
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
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 添加比賽信息行
                  Row(
                    children: [
                      // 日期指示
                      Icon(Icons.calendar_today,
                          size: 14, color: Colors.white.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Text(
                        widget.competition.startDate
                            .toString()
                            .substring(0, 10),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 場地指示
                      Icon(Icons.location_on,
                          size: 14, color: Colors.white.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          widget.competition.venue ?? '未指定場地',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _drawerTools.length,
                itemBuilder: (context, index) {
                  final tool = _drawerTools[index];

                  // 如果是分類標題
                  if (tool.containsKey('isCategory') &&
                      tool['isCategory'] == true) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tool['category'],
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Divider(
                              color: Colors.white.withValues(alpha: 0.2),
                              height: 1),
                        ],
                      ),
                    );
                  }

                  // 檢查權限 - 處理特殊角色權限
                  if ((tool.containsKey('forCreator') &&
                          tool['forCreator'] == true &&
                          !isCreator) ||
                      (tool.containsKey('roles') &&
                          currentUserUid != null &&
                          !_userHasAnyRole(currentUserUid,
                              List<String>.from(tool['roles'])))) {
                    return const SizedBox.shrink();
                  }

                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(tool['icon'], color: Colors.white),
                    ),
                    title: Text(
                      tool['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: tool.containsKey('subtitle')
                        ? Text(
                            tool['subtitle'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          )
                        : null,
                    trailing: const Icon(Icons.chevron_right,
                        size: 20, color: Colors.white70),
                    onTap: () {
                      Navigator.pop(context);

                      // 尋找對應的網格工具項並執行相同的操作
                      final toolTitle = tool['title'];
                      for (var gridTool in _getManagementToolList()) {
                        if ((gridTool['label'] == toolTitle ||
                                _getEquivalentTitle(gridTool['label']) ==
                                    toolTitle) &&
                            gridTool['onTap'] != null) {
                          gridTool['onTap']();
                          return;
                        }
                      }

                      // 如果沒有找到對應的網格工具，則執行默認操作
                      if (toolTitle == '編輯比賽') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EditCompetitionBasicInfoScreen(
                              competition: widget.competition,
                            ),
                          ),
                        ).then((result) {
                          if (result == true) {
                            Navigator.pop(context, true);
                          }
                        });
                      } else if (toolTitle == '權限管理') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CharacterManagementScreen(
                              competition: widget.competition,
                            ),
                          ),
                        );
                      } else if (toolTitle == '項目管理') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ScoreRecordingSetupScreen(
                              competitionId: widget.competition.id,
                              competitionName: widget.competition.name,
                            ),
                          ),
                        );
                      } else if (toolTitle == '分組名單') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NameListScreen(
                              competitionId: widget.competition.id,
                              competitionName: widget.competition.name,
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
            // 底部返回按鈕區域 - 無需額外的Container背景色，已經在外層設置
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.white),
              title: const Text(
                '返回比賽列表',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
  }

  // 獲取標題轉換（網格標籤到側邊欄標題的映射）
  String _getEquivalentTitle(String gridLabel) {
    Map<String, String> titleMap = {
      '編輯比賽': '編輯比賽',
      '報名管理': '報名管理',
      '權限管理': '權限管理',
      '項目管理': '項目管理',
      '成績記錄': '成績記錄',
      '成績管理': '成績管理',
      '分組名單': '分組名單',
      '獎項管理': '獎項管理',
      '數據統計': '數據統計',
    };
    return titleMap[gridLabel] ?? gridLabel;
  }

  // 檢查用戶是否擁有任何所需角色
  bool _userHasAnyRole(String userId, List<String> requiredRoles) {
    if (widget.competition.createdByUid == userId) return true; // 創建者擁有所有權限

    for (var role in requiredRoles) {
      if (widget.competition.hasRole(userId, role)) {
        return true;
      }
    }
    return false;
  }

  // 獲取管理工具列表方法（用於保持一致性）
  List<Map<String, dynamic>> _getManagementToolList() {
    return [
      {
        'icon': Icons.edit_outlined,
        'label': '編輯比賽',
        'color': Colors.blue,
        'forCreator': true,
        'onTap': () {
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
      },
      {
        'icon': Icons.app_registration_outlined,
        'label': '報名管理',
        'color': Colors.green,
        'roles': ['registration'],
        'onTap': () {
          showDialog(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text('報名控制'),
              children: [
                SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateRegistrationFormScreen(
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
                    Navigator.pop(context);
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
      },
      {
        'icon': Icons.admin_panel_settings_outlined,
        'label': '權限管理',
        'color': Colors.purple,
        'forCreator': true,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CharacterManagementScreen(
                competition: widget.competition,
              ),
            ),
          );
        },
      },
      {
        'icon': Icons.event_note_outlined,
        'label': '項目管理',
        'color': Colors.orange,
        'roles': ['score'],
        'onTap': () {
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
      },
      {
        'icon': Icons.sports_outlined,
        'label': '成績記錄',
        'color': Colors.teal,
        'roles': ['score'],
        'onTap': () {
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
      },
      {
        'icon': Icons.assessment_outlined,
        'label': '成績管理',
        'color': Colors.amber,
        'roles': ['score'],
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultManageScreen(
                competitionId: widget.competition.id,
                competitionName: widget.competition.name,
              ),
            ),
          );
        },
      },
      {
        'icon': Icons.people_alt_outlined,
        'label': '分組名單',
        'color': primaryColor,
        'roles': ['registration', 'score'],
        'onTap': () {
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
      },
      {
        'icon': Icons.emoji_events_outlined,
        'label': '獎項管理',
        'color': Colors.deepOrange,
        'roles': ['award'],
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AwardListScreen(
                competitionId: widget.competition.id,
                competitionName: widget.competition.name,
              ),
            ),
          );
        },
      },
      {
        'icon': Icons.bar_chart_outlined,
        'label': '數據統計',
        'color': Colors.indigo,
        'roles': ['award'],
        'onTap': () {
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
      },
    ];
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

    // 定義所有可用管理工具
    final List<Map<String, dynamic>> allTools = [
      {
        'icon': Icons.edit_outlined,
        'label': '編輯比賽',
        'color': Colors.blue,
        'forCreator': true, // 只有創建者可見
        'onTap': () {
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
      },
      {
        'icon': Icons.app_registration_outlined,
        'label': '報名管理',
        'color': Colors.green,
        'roles': ['registration'], // 報名管理員可見
        'onTap': () {
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
                        builder: (context) => CreateRegistrationFormScreen(
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
      },
      {
        'icon': Icons.admin_panel_settings_outlined,
        'label': '權限管理',
        'color': Colors.purple,
        'forCreator': true, // 只有創建者可見
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CharacterManagementScreen(
                competition: widget.competition,
              ),
            ),
          );
        },
      },
      {
        'icon': Icons.event_note_outlined,
        'label': '項目管理',
        'color': Colors.orange,
        'roles': ['score'], // 成績管理員可見
        'onTap': () {
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
      },
      {
        'icon': Icons.sports_outlined,
        'label': '成績記錄',
        'color': Colors.teal,
        'roles': ['score'], // 成績管理員可見
        'onTap': () {
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
      },
      {
        'icon': Icons.assessment_outlined,
        'label': '成績管理',
        'color': Colors.amber,
        'roles': ['score'], // 成績管理員可見
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultManageScreen(
                competitionId: widget.competition.id,
                competitionName: widget.competition.name,
              ),
            ),
          );
        },
      },
      {
        'icon': Icons.people_alt_outlined,
        'label': '分組名單',
        'color': primaryColor,
        'roles': ['registration', 'score'], // 報名管理員和成績管理員可見
        'onTap': () {
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
      },
      {
        'icon': Icons.emoji_events_outlined,
        'label': '獎項管理',
        'color': Colors.deepOrange,
        'roles': ['award'], // 頒獎典禮管理員可見
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AwardListScreen(
                competitionId: widget.competition.id,
                competitionName: widget.competition.name,
              ),
            ),
          );
        },
      },
      {
        'icon': Icons.bar_chart_outlined,
        'label': '數據統計',
        'color': Colors.indigo,
        'roles': ['award'], // 頒獎典禮管理員可見
        'onTap': () {
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
      },
    ];

    // 根據用戶角色篩選工具
    List<Map<String, dynamic>> visibleTools = [];

    if (currentUserId != null) {
      if (isCreator) {
        // 比賽創建者可以看到所有工具
        visibleTools = List.from(allTools);
      } else {
        // 其他用戶根據角色權限篩選
        for (var tool in allTools) {
          // 跳過只給創建者顯示的工具
          if (tool['forCreator'] == true) {
            continue;
          }

          // 檢查用戶是否有該工具所需的任一角色
          if (tool.containsKey('roles')) {
            List<String> requiredRoles = List<String>.from(tool['roles']);
            bool hasAnyRole = false;

            for (var role in requiredRoles) {
              if (widget.competition.hasRole(currentUserId, role)) {
                hasAnyRole = true;
                break;
              }
            }

            if (hasAnyRole) {
              visibleTools.add(tool);
            }
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: visibleTools.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(Icons.lock, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          '沒有可用的管理工具',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '請聯繫比賽創建者獲取權限',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              : GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: visibleTools.map((tool) {
                    return _buildToolButton(
                      icon: tool['icon'],
                      label: tool['label'],
                      color: tool['color'],
                      onTap: tool['onTap'],
                    );
                  }).toList(),
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
    // 確保顏色不為null
    final Color safeColor = color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: safeColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: safeColor.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: safeColor, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: safeColor,
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
          ],
        ),
      ),
    );
  }
}
