import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/competition.dart';
import '../utils/colors.dart';

class CharacterManagementScreen extends StatefulWidget {
  final CompetitionModel competition;

  const CharacterManagementScreen({
    Key? key,
    required this.competition,
  }) : super(key: key);

  @override
  State<CharacterManagementScreen> createState() =>
      _CharacterManagementScreenState();
}

class _CharacterManagementScreenState extends State<CharacterManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String _errorMessage = '';

  // 角色定義
  final List<Map<String, dynamic>> _roles = [
    {
      'field': 'registration',
      'name': '報名管理員',
      'description': '管理參賽者報名',
      'icon': Icons.app_registration,
      'color': Colors.teal,
    },
    {
      'field': 'score',
      'name': '成績管理員',
      'description': '管理比賽成績和計分方法',
      'icon': Icons.score,
      'color': Colors.orange,
    },
    {
      'field': 'violation',
      'name': '違規管理員',
      'description': '管理比賽違規情況',
      'icon': Icons.warning,
      'color': Colors.red,
    },
    {
      'field': 'award',
      'name': '頒獎員',
      'description': '管理頒獎名單與頒獎儀式',
      'icon': Icons.emoji_events,
      'color': Colors.purple,
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  // 檢查當前用戶是否有權限訪問此頁面 - 只有創建者才能訪問
  Future<void> _checkPermission() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      setState(() {
        _errorMessage = '請先登入再進行此操作';
      });
      _navigateBack('請先登入再進行此操作');
      return;
    }

    // 檢查是否為創建者 - 嚴格檢查
    bool isCreator = false;

    // 直接從比賽對象檢查
    if (widget.competition.createdByUid == currentUserId) {
      isCreator = true;
    }
    // 從metadata檢查
    else if (widget.competition.metadata != null) {
      final metadataCreatorUid = widget.competition.metadata!['createdByUid'];
      if (metadataCreatorUid is String && metadataCreatorUid == currentUserId) {
        isCreator = true;
      }
    }
    // 從permissions檢查
    else if (widget.competition.permissions != null) {
      final permissionOwner = widget.competition.permissions!['owner'];
      if (permissionOwner is String && permissionOwner == currentUserId) {
        isCreator = true;
      }
    }

    if (!isCreator) {
      setState(() {
        _errorMessage = '只有比賽創建者才能管理角色權限';
      });
      _navigateBack('只有比賽創建者才能管理角色權限');
    }
  }

  void _navigateBack(String message) {
    Future.delayed(Duration.zero, () {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('無法訪問'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0A0E53)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '比賽角色管理',
          style: TextStyle(
            color: Color(0xFF0A0E53),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('添加管理員'),
            onPressed: _showAddManagerDialog,
            style: TextButton.styleFrom(
              foregroundColor: primaryColor,
            ),
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
                    // 頂部比賽資訊卡片
                    _buildCompetitionInfoCard(),

                    const SizedBox(height: 16),

                    // 權限管理說明卡片
                    _buildInfoCard(),

                    const SizedBox(height: 24),

                    // 角色管理區
                    ..._roles.map((role) => Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _buildRoleCard(role),
                        )),
                  ],
                ),
              ),
            ),
    );
  }

  // 比賽資訊卡片
  Widget _buildCompetitionInfoCard() {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 60,
                height: 60,
                color: primaryColor.withValues(alpha: 0.1),
                child: const Icon(Icons.emoji_events,
                    color: primaryColor, size: 32),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.competition.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A0E53),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.competition.createdBy,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        widget.competition.startDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
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
    );
  }

  // 資訊卡片
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Text(
                '角色權限說明',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A0E53),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '作為比賽創建者，您可以在此管理其他人的角色權限。每個角色對應不同的管理功能，請根據需要進行分配。添加角色成員將向他們發送通知，並在他們登入後顯示相應的功能。',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF5C5E6F),
            ),
          ),
        ],
      ),
    );
  }

  // 建立角色卡片
  Widget _buildRoleCard(Map<String, dynamic> role) {
    final Color themeColor = role['color'];
    final IconData roleIcon = role['icon'];
    final String permissionField = role['field'];

    // 獲取該角色的管理員列表
    List<String> roleMembers = [];
    final permissions = widget.competition.permissions;
    if (permissions != null &&
        permissions.containsKey(permissionField) &&
        permissions[permissionField] != null) {
      try {
        roleMembers = List<String>.from(permissions[permissionField] ?? []);
      } catch (e) {
        debugPrint('⚠️ 轉換角色成員列表出錯: $e');
      }
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 角色標題區
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Color.fromRGBO(
                  themeColor.red, themeColor.green, themeColor.blue, 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(roleIcon, color: themeColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role['name'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                      Text(
                        role['description'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5C5E6F),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: themeColor),
                  ),
                  child: Text(
                    '${roleMembers.length} 人',
                    style: TextStyle(
                      fontSize: 12,
                      color: themeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 成員列表區
          Container(
            padding: const EdgeInsets.all(16),
            child: roleMembers.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Column(
                        children: [
                          Icon(Icons.person_off,
                              color: Colors.grey[400], size: 36),
                          const SizedBox(height: 8),
                          Text(
                            '目前沒有${role['name']}',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: roleMembers
                        .map((userId) => _buildMemberTile(
                            userId, permissionField, themeColor))
                        .toList(),
                  ),
          ),

          // 底部按鈕區
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: Icon(Icons.add, size: 16, color: themeColor),
                  label: Text('添加${role['name']}',
                      style: TextStyle(color: themeColor)),
                  onPressed: () =>
                      _addRoleMember(permissionField, role['name']),
                  style: ButtonStyle(
                    overlayColor: WidgetStateProperty.all(
                        themeColor.withValues(alpha: 0.1)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 成員項目
  Widget _buildMemberTile(
      String userId, String permissionField, Color themeColor) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: themeColor.withValues(alpha: 0.2),
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Container(height: 14, width: 100, color: Colors.grey[200]),
            subtitle:
                Container(height: 10, width: 150, color: Colors.grey[100]),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[200],
              child: Icon(Icons.person, color: Colors.grey[500]),
            ),
            title: Text('未知用戶 (${userId.substring(0, 5)}...)',
                style: const TextStyle(fontStyle: FontStyle.italic)),
            subtitle: const Text('用戶數據不可用',
                style: TextStyle(color: Colors.red, fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
              onPressed: () => _removeRoleMember(permissionField, userId),
            ),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final username = userData['username'] ?? '未命名用戶';
        final email = userData['email'] ?? '';
        final profileImage = userData['profileImage'];

        return ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: themeColor.withValues(alpha: 0.2),
            backgroundImage:
                profileImage != null ? NetworkImage(profileImage) : null,
            child: profileImage == null
                ? Icon(Icons.person, color: themeColor)
                : null,
          ),
          title: Text(username,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(email, style: const TextStyle(fontSize: 12)),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 18),
            onPressed: () => _removeRoleMember(permissionField, userId),
            tooltip: '移除角色權限',
          ),
        );
      },
    );
  }

  // 顯示添加管理員對話框
  void _showAddManagerDialog() {
    TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add, size: 24, color: primaryColor),
            SizedBox(width: 12),
            Text('添加管理員'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '添加的管理員將可以訪問比賽的管理功能，具體權限取決於您所賦予的角色。',
              style: TextStyle(fontSize: 12, color: Color(0xFF5C5E6F)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: '管理員電子郵件',
                hintText: '請輸入管理員的電子郵件',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: primaryColor, width: 2),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            const Text(
              '注意：用戶必須已在系統中註冊才能被添加為管理員。',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 16),
            label: const Text('添加'),
            onPressed: () {
              _addManagerByEmail(emailController.text.trim());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 通過電子郵件添加管理員
  Future<void> _addManagerByEmail(String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入有效的電子郵件')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 查詢用戶
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        _showError('找不到此電子郵件對應的用戶');
        return;
      }

      final userDoc = querySnapshot.docs.first;
      final userData = userDoc.data();
      final userUid = userDoc.id;

      // 更新比賽權限
      await _firestore
          .collection('competitions')
          .doc(widget.competition.id)
          .update({
        'permissions.canEdit': FieldValue.arrayUnion([userUid]),
        'permissions.canManage': FieldValue.arrayUnion([userUid]),
      });

      _showSuccess('已成功添加管理員: ${userData['username'] ?? email}');

      // 重新載入頁面數據
      setState(() {});
    } catch (e) {
      _showError('添加管理員失敗: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 添加角色成員
  void _addRoleMember(String permissionField, String roleName) {
    TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('添加$roleName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: '用戶電子郵件',
                hintText: '請輸入用戶的電子郵件',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('請輸入有效的電子郵件')),
                );
                return;
              }

              Navigator.pop(context);
              await _addRoleMemberByEmail(email, permissionField, roleName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  // 通過電子郵件添加角色成員
  Future<void> _addRoleMemberByEmail(
      String email, String permissionField, String roleName) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 查詢用戶
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        _showError('找不到此電子郵件對應的用戶');
        return;
      }

      final userDoc = querySnapshot.docs.first;
      final userData = userDoc.data();
      final userUid = userDoc.id;

      // 更新比賽權限
      final updateData = {
        'permissions.$permissionField': FieldValue.arrayUnion([userUid]),
      };

      await _firestore
          .collection('competitions')
          .doc(widget.competition.id)
          .update(updateData);

      _showSuccess('已成功添加$roleName: ${userData['username'] ?? email}');

      // 重新載入頁面數據
      setState(() {});
    } catch (e) {
      _showError('添加$roleName失敗: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 移除角色成員
  Future<void> _removeRoleMember(String permissionField, String userId) async {
    // 確認刪除對話框
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認移除'),
        content: const Text('確定要移除此成員的角色權限嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('確定移除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 更新比賽權限
      final updateData = {
        'permissions.$permissionField': FieldValue.arrayRemove([userId]),
      };

      await _firestore
          .collection('competitions')
          .doc(widget.competition.id)
          .update(updateData);

      _showSuccess('已成功移除角色權限');

      // 重新載入頁面數據
      setState(() {});
    } catch (e) {
      _showError('移除角色權限失敗: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 顯示成功消息
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 顯示錯誤消息
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
