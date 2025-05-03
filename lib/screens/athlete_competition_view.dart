import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/competition_list_viewmodel.dart';
import '../models/competition_model.dart';
import '../widgets/competition_card_widget.dart';
import '../widgets/competition_detail_widget.dart';
import '../widgets/competition_filter_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../utils/age_group_handler.dart'; // 導入年齡組別處理工具
import 'athlete_registration_form_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // 添加這一行以使用 debugPrint

class AthleteCompetitionViewScreen extends StatefulWidget {
  final String competitionId;

  const AthleteCompetitionViewScreen({
    Key? key,
    this.competitionId = '',
  }) : super(key: key);

  @override
  State<AthleteCompetitionViewScreen> createState() =>
      _AthleteCompetitionViewScreenState();
}

class _AthleteCompetitionViewScreenState
    extends State<AthleteCompetitionViewScreen> {
  final TextEditingController _searchController = TextEditingController();
  late CompetitionListViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    // 在initState中我們只創建ViewModel實例，不執行數據加載
    _viewModel = CompetitionListViewModel();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 在didChangeDependencies中加載數據，這樣在熱重載時也能正確處理
    _loadData();
  }

  // 根據是否有競賽ID決定加載列表還是詳情
  Future<void> _loadData() async {
    if (widget.competitionId.isEmpty) {
      await _viewModel.loadCompetitions();
    } else {
      await _viewModel.loadCompetitionDetails(widget.competitionId);
    }
  }

  // 搜索文本變化處理
  void _onSearchChanged() {
    _viewModel.setSearchQuery(_searchController.text);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  // 導航到報名表單頁面
  void _navigateToRegistrationForm(CompetitionModel competition) async {
    try {
      // 標記開始報名流程
      await _viewModel.startRegistration(competition);

      if (!mounted) return; // 確保 widget 仍然掛載

      // 導航到報名頁面
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AthleteRegistrationFormScreen(
            competitionId: competition.id,
            competitionName: competition.name,
            viewMode: false, // 編輯模式
          ),
        ),
      );

      // 如果返回true，表示報名成功，刷新數據
      if (result == true && mounted) {
        // 確保 widget 仍然掛載
        _viewModel.refresh();
      }
    } catch (e) {
      debugPrint('導航到報名頁面出錯: $e');
    }
  }

  // 查看已提交的報名表
  void _viewRegistrationForm(CompetitionModel competition) async {
    try {
      if (!mounted) return; // 確保 widget 仍然掛載

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AthleteRegistrationFormScreen(
            competitionId: competition.id,
            competitionName: competition.name,
            viewMode: true, // 查看模式
          ),
        ),
      );
    } catch (e) {
      debugPrint('導航到報名查看頁面出錯: $e');
    }
  }

  // 根據年齡篩選比賽
  void _filterCompetitionsByAge() async {
    // 如果沒有登錄用戶資料，則可能需要先提示登錄
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return; // 確保 widget 仍然掛載

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入帳號以使用此功能')),
      );
      return;
    }

    // 顯示年齡分組對話框以選擇適合的年齡分組
    try {
      // 獲取所有比賽中的年齡分組
      List<Map<String, dynamic>> allAgeGroups = [];
      for (var competition in _viewModel.filteredCompetitions) {
        if (competition.metadata != null &&
            competition.metadata!.containsKey('ageGroups')) {
          final ageGroups =
              AgeGroupHandler.loadAgeGroupsFromMetadata(competition.metadata);
          for (var group in ageGroups) {
            // 避免重複添加相同的年齡分組
            if (!allAgeGroups.any((g) =>
                g['name'] == group['name'] &&
                g['startAge'] == group['startAge'] &&
                g['endAge'] == group['endAge'])) {
              allAgeGroups.add(group);
            }
          }
        }
      }

      // 如果沒有找到任何年齡分組，則使用默認的年齡分組
      if (allAgeGroups.isEmpty) {
        allAgeGroups = AgeGroupHandler.getDefaultAgeGroups();
      }

      if (!mounted) return; // 確保 widget 仍然掛載

      // 使用AgeGroupHandler顯示年齡分組選擇對話框
      final selectedAgeGroup = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _buildAgeGroupSelectionDialog(allAgeGroups),
      );

      if (selectedAgeGroup != null && mounted) {
        // 獲取選擇的年齡範圍
        int? startAge = selectedAgeGroup['startAge'] as int?;
        int? endAge = selectedAgeGroup['endAge'] as int?;
        String groupName = selectedAgeGroup['name'] as String;

        if (startAge != null && endAge != null) {
          // 計算中間年齡作為過濾依據
          int midAge = ((startAge + endAge) / 2).round();
          _viewModel.setAgeFilter(midAge);

          // 顯示提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('已篩選出適合「$groupName」($startAge-$endAge歲)的比賽')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return; // 確保 widget 仍然掛載

      // 顯示錯誤信息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('篩選比賽時出錯: $e')),
      );
    }
  }

  // 構建年齡組別選擇對話框
  Widget _buildAgeGroupSelectionDialog(List<Map<String, dynamic>> ageGroups) {
    return AlertDialog(
      title: const Text('選擇年齡組別'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: ageGroups.length,
          itemBuilder: (context, index) {
            final group = ageGroups[index];
            return ListTile(
              title: Text(group['name'] as String),
              subtitle: Text('${group['startAge']}-${group['endAge']}歲'),
              onTap: () => Navigator.pop(context, group),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 使用ChangeNotifierProvider提供ViewModel
    return ChangeNotifierProvider<CompetitionListViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          title: Text(
            widget.competitionId.isEmpty ? '可報名比賽' : '比賽詳情',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _viewModel.refresh,
            ),
            IconButton(
              icon: const Icon(Icons.filter_alt),
              tooltip: '按年齡篩選比賽',
              onPressed: _filterCompetitionsByAge,
            ),
            Consumer<CompetitionListViewModel>(
              builder: (context, viewModel, _) {
                // 只有在篩選器生效時才顯示清除按鈕
                return IconButton(
                  icon: const Icon(Icons.filter_alt_off),
                  tooltip: '清除年齡篩選',
                  onPressed: () {
                    viewModel.clearAgeFilter();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已清除年齡篩選')),
                    );
                  },
                );
              },
            ),
          ],
          iconTheme: const IconThemeData(color: Colors.black87),
        ),
        body: Consumer<CompetitionListViewModel>(
          builder: (context, viewModel, child) {
            // 顯示加載狀態
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            // 顯示錯誤信息
            if (viewModel.loadingState == CompetitionLoadingState.error) {
              return EmptyStateWidget(
                icon: Icons.error_outline,
                title: '加載失敗',
                message: viewModel.errorMessage,
                action: ElevatedButton.icon(
                  onPressed: _viewModel.refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重試'),
                ),
              );
            }

            // 根據頁面模式顯示內容
            return widget.competitionId.isEmpty
                ? _buildCompetitionsList(viewModel)
                : _buildCompetitionDetails(viewModel);
          },
        ),
      ),
    );
  }

  // 構建比賽列表頁面
  Widget _buildCompetitionsList(CompetitionListViewModel viewModel) {
    return Column(
      children: [
        // 搜索和過濾區域
        CompetitionFilterWidget(
          currentFilter: viewModel.statusFilter,
          onFilterChanged: viewModel.setStatusFilter,
          searchController: _searchController,
          onSearchChanged: viewModel.setSearchQuery,
        ),

        // 比賽列表
        Expanded(
          child: viewModel.filteredCompetitions.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.search_off,
                  title: '沒有找到比賽',
                  message: _searchController.text.isNotEmpty
                      ? '嘗試使用不同的關鍵詞'
                      : viewModel.statusFilter != '全部'
                          ? '嘗試選擇不同的狀態過濾器'
                          : '暫無可報名的比賽',
                )
              : ListView.builder(
                  itemCount: viewModel.filteredCompetitions.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final competition = viewModel.filteredCompetitions[index];
                    return CompetitionCardWidget(
                      competition: competition,
                      isLoadingRegistration: viewModel.isRegistrationLoading,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AthleteCompetitionViewScreen(
                              competitionId: competition.id,
                            ),
                          ),
                        ).then((_) => viewModel.loadCompetitions());
                      },
                      onRegisterTap: () =>
                          _navigateToRegistrationForm(competition),
                      onViewRegistrationTap: competition.alreadyRegistered
                          ? () => _viewRegistrationForm(competition)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  // 構建單個比賽詳情頁面
  Widget _buildCompetitionDetails(CompetitionListViewModel viewModel) {
    final competition = viewModel.selectedCompetition;

    if (competition == null) {
      return EmptyStateWidget(
        icon: Icons.error_outline,
        title: '找不到比賽',
        message: '無法載入此比賽的詳細資訊',
        action: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('返回'),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: CompetitionDetailWidget(
        competition: competition,
        isLoadingRegistration: viewModel.isRegistrationLoading,
        onRegisterTap: () => _navigateToRegistrationForm(competition),
        onViewRegistrationTap: competition.alreadyRegistered
            ? () => _viewRegistrationForm(competition)
            : null,
      ),
    );
  }
}
