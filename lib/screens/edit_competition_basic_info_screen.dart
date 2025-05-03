import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/competition.dart';
import '../data/competition_data.dart';
import '../resources/auth_methods.dart';
import '../models/user.dart';
import '../utils/age_group_handler.dart'; // 引入年齡分組處理工具
import '../utils/events_handler.dart'; // 引入比賽項目處理工具

class EditCompetitionBasicInfoScreen extends StatefulWidget {
  final CompetitionModel competition;

  const EditCompetitionBasicInfoScreen({
    Key? key,
    required this.competition,
  }) : super(key: key);

  @override
  State<EditCompetitionBasicInfoScreen> createState() =>
      _EditCompetitionBasicInfoScreenState();
}

class _EditCompetitionBasicInfoScreenState
    extends State<EditCompetitionBasicInfoScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final CompetitionData _competitionData = CompetitionData();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthMethods _authMethods = AuthMethods();

  UserModel? _currentUser;
  late TextEditingController _nameController;
  late TextEditingController _venueController;
  late TextEditingController _dateController;
  late TextEditingController _itemsController;
  late TextEditingController _ageGroupsController;
  late TextEditingController _maxParticipantsController;
  late TextEditingController _currentParticipantsController;
  String _publicityScope = '公開';

  // 比賽項目和年齡分組列表
  List<String> _events = [];
  List<Map<String, dynamic>> _ageGroups = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeControllersWithLocalData();
    // 從Firebase獲取最新數據
    _fetchLatestDataFromFirebase();
    // 加載當前用戶數據
    _loadCurrentUser();
    // 加載年齡分組數據
    _loadAgeGroups();
  }

  // 使用本地數據初始化控制器
  void _initializeControllersWithLocalData() {
    _nameController = TextEditingController(text: widget.competition.name);
    _venueController =
        TextEditingController(text: widget.competition.venue ?? '');
    _dateController = TextEditingController(
        text: widget.competition.startDate.toString().substring(0, 10));

    // 使用EventsHandler加載比賽項目
    List<Map<String, dynamic>> eventsData =
        EventsHandler.loadEventsFromMetadata(widget.competition.metadata);
    _events = eventsData.map((e) => e['name'] as String).toList();
    _itemsController = TextEditingController(
        text: EventsHandler.convertEventsToDisplay(eventsData));

    // 使用AgeGroupHandler加載年齡分組
    _ageGroups =
        AgeGroupHandler.loadAgeGroupsFromMetadata(widget.competition.metadata);
    _ageGroupsController = TextEditingController(
        text: AgeGroupHandler.convertAgeGroupsToDisplay(_ageGroups));

    _maxParticipantsController = TextEditingController(
        text: (widget.competition.metadata?['maxParticipants'] ?? '100')
            .toString());
    _currentParticipantsController = TextEditingController(
        text: (widget.competition.metadata?['currentParticipants'] ?? '0')
            .toString());

    // 設置公開對象，確保只能是有效的選項之一
    String audience = widget.competition.metadata?['targetAudience'] ?? '公開';
    // 檢查是否為允許的值，不是的話設為預設值
    if (!['公開', '僅限特定人士', '僅限管理員', '僅限會員'].contains(audience)) {
      audience = '公開';
    }
    _publicityScope = audience;
  }

  // 從Firebase獲取最新數據
  Future<void> _fetchLatestDataFromFirebase() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 從Firebase獲取最新的比賽數據
      DocumentSnapshot doc = await _firestore
          .collection('competitions')
          .doc(widget.competition.id)
          .get();

      if (doc.exists && mounted) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        setState(() {
          // 更新控制器的值
          _nameController.text = data['name'] ?? '';
          _venueController.text = data['venue'] ?? '';
          _dateController.text = data['startDate'] ?? '';

          // 更新元數據相關控制器
          final metadata = data['metadata'];
          if (metadata != null) {
            // 更新公開對象
            String audience = metadata['targetAudience'] ?? '公開';
            if (['公開', '僅限特定人士', '僅限管理員', '僅限會員'].contains(audience)) {
              _publicityScope = audience;
            }

            // 更新比賽項目
            if (metadata['events'] != null) {
              try {
                // 使用EventsHandler加載比賽項目
                List<Map<String, dynamic>> eventsData =
                    EventsHandler.loadEventsFromMetadata(metadata);
                _events = eventsData.map((e) => e['name'] as String).toList();
                _itemsController.text =
                    EventsHandler.convertEventsToDisplay(eventsData);
              } catch (e) {
                // 出現錯誤時設為空列表
                debugPrint('處理比賽項目時出錯: $e');
                _events = [];
                _itemsController.text = '';
              }
            }

            // 更新年齡分組
            if (metadata['ageGroups'] != null) {
              try {
                _ageGroups =
                    AgeGroupHandler.loadAgeGroupsFromMetadata(metadata);
                _ageGroupsController.text =
                    AgeGroupHandler.convertAgeGroupsToDisplay(_ageGroups);
              } catch (e) {
                // 出現錯誤時設為空列表
                debugPrint('處理年齡組別時出錯: $e');
                _ageGroups = [];
                _ageGroupsController.text = '';
              }
            }

            // 更新參與者數量限制
            _maxParticipantsController.text =
                (metadata['maxParticipants'] ?? '100').toString();
            _currentParticipantsController.text =
                (metadata['currentParticipants'] ?? '0').toString();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('獲取最新數據失敗: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 加載當前登錄用戶信息
  Future<void> _loadCurrentUser() async {
    try {
      _currentUser = await _authMethods.getCurrentUser();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('獲取用戶信息失敗: $e')),
        );
      }
    }
  }

  // 加載年齡分組數據
  Future<void> _loadAgeGroups() async {
    // 檢查是否已經銷毁
    if (!mounted) return;

    try {
      // 使用AgeGroupHandler從元數據中獲取年齡分組數據
      _ageGroups = AgeGroupHandler.loadAgeGroupsFromMetadata(
          widget.competition.metadata);

      setState(() {
        // 更新控制器文本
        _ageGroupsController.text =
            AgeGroupHandler.convertAgeGroupsToDisplay(_ageGroups);
      });

      // 如果沒有年齡分組數據，添加默認分組
      if (_ageGroups.isEmpty && mounted) {
        setState(() {
          _ageGroups = AgeGroupHandler.getDefaultAgeGroups();
          _ageGroupsController.text =
              AgeGroupHandler.convertAgeGroupsToDisplay(_ageGroups);
        });
      }
    } catch (e) {
      // 錯誤處理
      debugPrint('處理年齡組別時出錯: $e');
      if (mounted) {
        setState(() {
          _ageGroups = [];
          _ageGroupsController.text = '';
        });

        // 顯示錯誤消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入年齡分組失敗: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _venueController.dispose();
    _dateController.dispose();
    _itemsController.dispose();
    _ageGroupsController.dispose();
    _maxParticipantsController.dispose();
    _currentParticipantsController.dispose();
    super.dispose();
  }

  // 處理比賽項目輸入
  Future<void> _handleEventsInput() async {
    // 檢查是否已經銷毁
    if (!mounted) return;

    try {
      // 使用簡單版本對話框
      final result =
          await EventsHandler.showEventsDialog(context, _itemsController.text);

      if (result != null && mounted) {
        setState(() {
          _itemsController.text = result;
          _events =
              result.split(',').where((e) => e.trim().isNotEmpty).toList();
        });

        // 顯示成功提示
        if (_events.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('比賽項目已更新'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }

      // 使用高級版本對話框（可選，取消註釋下方代碼即可啟用）
      /*
      // 轉換當前項目為所需格式
      List<Map<String, dynamic>> currentEvents = _events.map((name) => {
        'name': name,
        'status': '進行中',
      }).toList();

      final advancedResult = await EventsHandler.showAdvancedEventsDialog(
          context, currentEvents);

      if (advancedResult != null && mounted) {
        setState(() {
          // 將結果保存並轉換為顯示格式
          _events = advancedResult.map((e) => e['name'] as String).toList();
          _itemsController.text = EventsHandler.convertEventsToDisplay(advancedResult);
        });

        // 顯示成功提示
        if (_events.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('比賽項目已更新'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
      */
    } catch (e) {
      // 處理錯誤情況
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新比賽項目失敗: $e')),
        );
      }
    }
  }

  // 處理年齡分組輸入
  Future<void> _handleAgeGroupsInput() async {
    // 檢查是否已經銷毁
    if (!mounted) return;

    try {
      // 使用AgeGroupHandler顯示年齡分組對話框
      final result =
          await AgeGroupHandler.showAgeGroupsDialog(context, _ageGroups);

      if (result != null && mounted) {
        setState(() {
          // 將結果保存並轉換為顯示格式
          _ageGroups = result;
          _ageGroupsController.text =
              AgeGroupHandler.convertAgeGroupsToDisplay(_ageGroups);
        });

        // 顯示成功提示
        if (_ageGroups.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('年齡分組已更新'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      // 處理錯誤情況
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新年齡分組失敗: $e')),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    // 檢查是否已經銷毁
    if (!mounted) return;

    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      try {
        // 準備比賽項目數據
        final List<Map<String, dynamic>> eventsData =
            EventsHandler.convertDisplayToEvents(_itemsController.text);

        // 獲取當前用戶
        final String createdBy =
            _currentUser?.username ?? widget.competition.createdBy;
        final String uid = _currentUser?.uid ?? _auth.currentUser?.uid ?? "";

        // 準備更新資料
        final competitionData = {
          'id': widget.competition.id,
          'name': _nameController.text.trim(),
          'description': widget.competition.description,
          'venue': _venueController.text.trim(),
          'startDate': _dateController.text,
          'endDate': widget.competition.endDate.toString(),
          'status': widget.competition.status,
          'createdBy': createdBy,
          'createdAt': widget.competition.createdAt,
          'createdByUid': uid,
          'metadata': {
            'targetAudience': _publicityScope,
            'ageGroups': _parseAgeGroups(_ageGroups),
            'events': eventsData,
            'maxParticipants':
                int.tryParse(_maxParticipantsController.text) ?? 100,
            'currentParticipants':
                int.tryParse(_currentParticipantsController.text) ?? 0,
          },
        };

        // 1. 更新到 Firebase
        await _firestore
            .collection('competitions')
            .doc(widget.competition.id)
            .update(competitionData);

        // 2. 更新到 SQLite
        await _competitionData.updateCompetition(
          widget.competition.id,
          competitionData,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('比賽資料已成功更新')),
          );

          // 返回上一頁並傳遞更新成功的信號
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新失敗: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _cancel() {
    // 檢查是否已經銷毁
    if (!mounted) return;

    Navigator.pop(context);
  }

  void _deleteCompetition() {
    // 檢查是否已經銷毁
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: const Text('確定要刪除此比賽嗎？此操作不可撤銷。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // 關閉對話框

              // 檢查是否已經銷毁
              if (!mounted) return;

              setState(() {
                _isLoading = true;
              });

              try {
                // 從 Firebase 刪除
                await _firestore
                    .collection('competitions')
                    .doc(widget.competition.id)
                    .delete();

                // 從 SQLite 刪除
                await _competitionData.deleteCompetition(widget.competition.id);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('比賽已刪除')),
                  );

                  // 返回上一頁並傳遞刪除信號
                  Navigator.pop(context, true);
                }
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('刪除失敗: $e')),
                  );
                }
              }
            },
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 確認保存變更
  Future<void> _confirmSaveChanges() async {
    // 檢查是否已經銷毁
    if (!mounted) return;

    // 顯示確認對話框
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認保存變更'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('您確定要保存以下變更嗎？'),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: '比賽名稱: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: _nameController.text),
                ],
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: '比賽日期: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: _dateController.text),
                ],
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: '比賽地點: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: _venueController.text),
                ],
              ),
            ),
            if (_nameController.text != widget.competition.name ||
                _dateController.text !=
                    widget.competition.startDate.toString().substring(0, 10) ||
                _venueController.text != (widget.competition.venue ?? ''))
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  '注意: 您對這些欄位進行了更改，請確認變更是否正確。',
                  style: TextStyle(
                      color: Colors.orange[800], fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確認保存'),
          ),
        ],
      ),
    );

    // 如果用戶確認，則保存變更
    if (confirm == true && mounted) {
      await _saveChanges();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0A0E53)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '編輯比賽設置',
          style: TextStyle(
            color: Color(0xFF0A0E53),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF0A0E53)),
            onPressed: _isLoading ? null : _fetchLatestDataFromFirebase,
            tooltip: '從雲端重新同步',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 頁面說明
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(top: 16, bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '編輯比賽設置',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '修改後點擊「保存」將同時更新雲端與本地資料。',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 基本資訊部分
                    _buildSectionHeader('基本資訊'),
                    _buildSettingField(
                      label: '比賽名稱',
                      controller: _nameController,
                      originalValue: widget.competition.name,
                      required: true,
                    ),
                    _buildDivider(),
                    _buildSettingField(
                      label: '比賽日期',
                      controller: _dateController,
                      originalValue: widget.competition.startDate
                          .toString()
                          .substring(0, 10),
                      required: true,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null && mounted) {
                          setState(() {
                            _dateController.text =
                                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                          });
                        }
                      },
                      isDate: true,
                    ),
                    _buildDivider(),
                    _buildSettingField(
                      label: '比賽地點',
                      controller: _venueController,
                      originalValue: widget.competition.venue ?? '未設置',
                      required: false,
                    ),
                    _buildDivider(),

                    // 參與設置部分
                    _buildSectionHeader('參與設置'),
                    _buildDropdownSettingField(
                      label: '公開對象',
                      value: _publicityScope,
                      originalValue:
                          widget.competition.metadata?['targetAudience'] ??
                              '公開',
                      items: const [
                        DropdownMenuItem(value: '公開', child: Text('公開')),
                        DropdownMenuItem(
                            value: '僅限特定人士', child: Text('僅限特定人士')),
                        DropdownMenuItem(value: '僅限管理員', child: Text('僅限管理員')),
                        DropdownMenuItem(value: '僅限會員', child: Text('僅限會員')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _publicityScope = value;
                          });
                        }
                      },
                    ),
                    _buildDivider(),
                    _buildSettingField(
                      label: '參賽人數上限',
                      controller: _maxParticipantsController,
                      originalValue:
                          (widget.competition.metadata?['maxParticipants'] ??
                                  '100')
                              .toString(),
                      keyboardType: TextInputType.number,
                    ),
                    _buildDivider(),
                    _buildSettingField(
                      label: '目前參賽人數',
                      controller: _currentParticipantsController,
                      originalValue: (widget.competition
                                  .metadata?['currentParticipants'] ??
                              '0')
                          .toString(),
                      keyboardType: TextInputType.number,
                      readOnly: true,
                      enabled: false,
                    ),
                    _buildDivider(),

                    // 比賽項目部分
                    _buildSectionHeader('比賽項目與分組'),
                    _buildSettingField(
                      label: '比賽項目',
                      controller: _itemsController,
                      originalValue: _getOriginalEvents(),
                      onTap: _handleEventsInput,
                      readOnly: true,
                      multiline: true,
                      helperText: '點擊編輯比賽項目',
                    ),
                    _buildDivider(),
                    _buildSettingField(
                      label: '年齡分組',
                      controller: _ageGroupsController,
                      originalValue: _getOriginalAgeGroups(),
                      onTap: _handleAgeGroupsInput,
                      readOnly: true,
                      multiline: true,
                      helperText: '點擊編輯年齡分組',
                    ),
                    _buildDivider(),

                    // 其他資訊部分
                    _buildSectionHeader('其他資訊'),
                    _buildInfoItem('比賽ID', widget.competition.id),
                    _buildDivider(),
                    _buildInfoItem('創建者', widget.competition.createdBy),
                    _buildDivider(),
                    _buildInfoItem('創建時間', widget.competition.createdAt),
                    const SizedBox(height: 32),

                    // 保存按鈕
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _isLoading ? null : () => _confirmSaveChanges(),
                            icon: const Icon(
                              Icons.save_outlined,
                              color: Colors.white,
                            ),
                            label: _isLoading
                                ? const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('處理中...')
                                    ],
                                  )
                                : const Text(
                                    '保存修改',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A0E53),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 2,
                              shadowColor: const Color(0xFF0A0E53)
                                  .withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _cancel,
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text(
                              '取消',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              side: BorderSide(color: Colors.grey[400]!),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 刪除按鈕
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _deleteCompetition,
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text(
                          '刪除比賽',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          foregroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 獲取原始比賽項目字符串
  String _getOriginalEvents() {
    if (widget.competition.metadata == null ||
        widget.competition.metadata!['events'] == null) {
      return '未設置';
    }

    try {
      // 使用EventsHandler加載比賽項目並轉換為顯示文本
      List<Map<String, dynamic>> events =
          EventsHandler.loadEventsFromMetadata(widget.competition.metadata);
      return EventsHandler.convertEventsToDisplay(events);
    } catch (e) {
      debugPrint('格式化比賽項目時出錯: $e');
      return '未設置';
    }
  }

  // 獲取原始年齡分組字符串
  String _getOriginalAgeGroups() {
    if (widget.competition.metadata == null ||
        widget.competition.metadata!['ageGroups'] == null) {
      return '未設置';
    }

    try {
      // 使用AgeGroupHandler加載年齡分組並轉換為顯示文本
      List<Map<String, dynamic>> ageGroups =
          AgeGroupHandler.loadAgeGroupsFromMetadata(
              widget.competition.metadata);
      return AgeGroupHandler.convertAgeGroupsToDisplay(ageGroups);
    } catch (e) {
      debugPrint('格式化年齡分組時出錯: $e');
      return '未設置';
    }
  }

  // 構建分區標題
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0A0E53),
        ),
      ),
    );
  }

  // 構建分隔線
  Widget _buildDivider() {
    return Divider(color: Colors.grey[300]);
  }

  // 構建一個設置字段
  Widget _buildSettingField({
    required String label,
    required TextEditingController controller,
    required String originalValue,
    bool required = false,
    bool enabled = true,
    bool readOnly = false,
    bool multiline = false,
    bool isDate = false,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onTap,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (required)
                const Text(
                  '*',
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            enabled: enabled,
            readOnly: readOnly || onTap != null,
            keyboardType: keyboardType,
            maxLines: multiline ? 3 : 1,
            onTap: onTap,
            decoration: InputDecoration(
              filled: true,
              fillColor: enabled ? Colors.white : Colors.grey[100],
              helperText: helperText,
              suffixIcon: isDate ? const Icon(Icons.calendar_today) : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF0A0E53), width: 1.5),
              ),
            ),
            validator: required
                ? (value) {
                    if (value == null || value.isEmpty) {
                      return '$label 不能為空';
                    }
                    return null;
                  }
                : null,
          ),
        ],
      ),
    );
  }

  // 構建一個下拉菜單設置字段
  Widget _buildDropdownSettingField<T>({
    required String label,
    required T value,
    required String originalValue,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (required)
                const Text(
                  '*',
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF0A0E53), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 構建一個只讀信息項
  Widget _buildInfoItem(String label, String value) {
    // 如果是創建者信息且有當前用戶數據，則顯示完整的用戶信息
    if (label == '創建者' &&
        _currentUser != null &&
        widget.competition.createdBy == _currentUser!.username) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentUser!.username,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentUser!.email,
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                  if (_currentUser!.school != null &&
                      _currentUser!.school!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '學校: ${_currentUser!.school}',
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 原有的顯示邏輯
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  // 解析年齡組別數據
  List<Map<String, dynamic>> _parseAgeGroups(
      List<Map<String, dynamic>> ageGroups) {
    return ageGroups;
  }
}
