import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/competition_model.dart';
import '../services/competition_service.dart';
import '../utils/age_group_handler.dart'; // 導入年齡分組處理工具
import '../utils/searching_function.dart'; // 添加搜索函數導入

// 競賽列表的狀態
enum CompetitionLoadingState {
  initial,
  loading,
  loaded,
  error,
}

// 競賽操作的狀態
enum RegistrationActionState {
  initial,
  loading,
  success,
  error,
}

// 競賽列表 ViewModel
class CompetitionListViewModel extends ChangeNotifier {
  // 服務和依賴項
  final CompetitionService _competitionService = CompetitionService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 狀態變量
  CompetitionLoadingState _loadingState = CompetitionLoadingState.initial;
  RegistrationActionState _registrationState = RegistrationActionState.initial;
  String _errorMessage = '';
  String _searchQuery = '';
  String _statusFilter = '全部';
  List<CompetitionModel> _allCompetitions = [];
  List<CompetitionModel> _filteredCompetitions = [];
  CompetitionModel? _selectedCompetition;
  StreamSubscription? _registrationsSubscription;

  // 新增：標記是否已被釋放
  bool _isDisposed = false;

  // Getters
  CompetitionLoadingState get loadingState => _loadingState;
  RegistrationActionState get registrationState => _registrationState;
  String get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get statusFilter => _statusFilter;
  List<CompetitionModel> get filteredCompetitions => _filteredCompetitions;
  CompetitionModel? get selectedCompetition => _selectedCompetition;
  bool get isLoading => _loadingState == CompetitionLoadingState.loading;
  bool get isRegistrationLoading =>
      _registrationState == RegistrationActionState.loading;

  // 初始化
  CompetitionListViewModel() {
    _setupListeners();
  }

  // 設置監聽器
  void _setupListeners() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // 監聽用戶報名狀態變化
    _registrationsSubscription = _competitionService
        .getUserRegistrationsStream(currentUser.uid)
        .listen((_) {
      // 報名狀態變化時刷新數據
      if (_isDisposed) return; // 新增：安全檢查
      if (_selectedCompetition != null) {
        loadCompetitionDetails(_selectedCompetition!.id);
      } else {
        loadCompetitions();
      }
    });
  }

  // 釋放資源
  @override
  void dispose() {
    _isDisposed = true; // 新增：標記已被釋放
    _registrationsSubscription?.cancel();
    debugPrint('🚨 CompetitionListViewModel 已被釋放');
    super.dispose();
  }

  // 新增：安全的通知監聽器方法
  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    } else {
      debugPrint('⚠️ 嘗試在 CompetitionListViewModel 被釋放後通知監聽器');
    }
  }

  // 加載競賽列表
  Future<void> loadCompetitions() async {
    if (_isDisposed) return; // 新增：安全檢查

    _loadingState = CompetitionLoadingState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      // 使用服務層獲取數據
      final competitions = await _competitionService.getAvailableCompetitions();

      if (_isDisposed) return; // 新增：安全檢查

      _allCompetitions =
          competitions.map((map) => CompetitionModel.fromMap(map)).toList();

      // 應用過濾器和搜索
      _applyFilters();
      _loadingState = CompetitionLoadingState.loaded;
    } catch (e) {
      if (_isDisposed) return; // 新增：安全檢查
      _loadingState = CompetitionLoadingState.error;
      _errorMessage = '載入比賽列表失敗: $e';
    }

    notifyListeners();
  }

  // 加載特定競賽詳情
  Future<void> loadCompetitionDetails(String competitionId) async {
    if (_isDisposed) return; // 新增：安全檢查

    _loadingState = CompetitionLoadingState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      // 使用服務層獲取數據
      final competitionData =
          await _competitionService.getCompetitionDetails(competitionId);

      if (_isDisposed) return; // 新增：安全檢查

      if (competitionData == null) {
        _loadingState = CompetitionLoadingState.error;
        _errorMessage = '找不到該比賽';
      } else {
        _selectedCompetition = CompetitionModel.fromMap(competitionData);
        _loadingState = CompetitionLoadingState.loaded;
      }
    } catch (e) {
      if (_isDisposed) return; // 新增：安全檢查
      _loadingState = CompetitionLoadingState.error;
      _errorMessage = '載入比賽詳情失敗: $e';
    }

    notifyListeners();
  }

  // 設置搜索查詢
  void setSearchQuery(String query) {
    if (_isDisposed) return; // 新增：安全檢查
    _searchQuery = query.toLowerCase();
    _applyFilters();
    notifyListeners();
  }

  // 設置狀態過濾器
  void setStatusFilter(String filter) {
    if (_isDisposed) return; // 新增：安全檢查
    _statusFilter = filter;
    _applyFilters();
    notifyListeners();
  }

  // 設置選中的競賽
  void selectCompetition(CompetitionModel competition) {
    if (_isDisposed) return; // 新增：安全檢查
    _selectedCompetition = competition;
    notifyListeners();
  }

  // 清除選中的競賽
  void clearSelectedCompetition() {
    if (_isDisposed) return; // 新增：安全檢查
    _selectedCompetition = null;
    notifyListeners();
  }

  // 應用過濾器和搜索
  void _applyFilters() {
    if (_isDisposed) return; // 新增：安全檢查

    // 快速路徑：無需過濾
    if (_searchQuery.isEmpty &&
        (_statusFilter.isEmpty || _statusFilter == '全部')) {
      _filteredCompetitions = List.from(_allCompetitions);
      return;
    }

    // 將 CompetitionModel 轉換為 Map<String, dynamic> 格式
    List<Map<String, dynamic>> competitionsAsMap = _allCompetitions
        .map((comp) => {
              'name': comp.name,
              'description': comp.description,
              'venue': comp.venue ?? '',
              'status': comp.status,
              'startDate': comp.startDate,
              'endDate': comp.endDate,
              'originalObject': comp, // 保存原始對象以便後續轉換回來
            })
        .toList();

    // 使用 linearSearchMap 函數進行搜索
    List<Map<String, dynamic>> filteredMaps = linearSearchMap(
      competitionsAsMap,
      _searchQuery,
      _statusFilter == '全部' ? '' : _statusFilter,
      isSorted: false, // 假設數據未排序
    );

    // 將搜索結果轉換回 CompetitionModel 對象
    _filteredCompetitions = filteredMaps
        .map((map) => map['originalObject'] as CompetitionModel)
        .toList();
  }

  // 開始報名流程
  Future<void> startRegistration(CompetitionModel competition) async {
    if (_isDisposed) return; // 新增：安全檢查
    _registrationState = RegistrationActionState.loading;
    notifyListeners();

    // 模擬短暫延遲，以顯示加載狀態
    await Future.delayed(const Duration(milliseconds: 300));

    if (_isDisposed) return; // 新增：安全檢查
    _registrationState = RegistrationActionState.success;
    notifyListeners();
  }

  // 刷新數據
  Future<void> refresh() async {
    if (_isDisposed) return; // 新增：安全檢查
    if (_selectedCompetition != null) {
      await loadCompetitionDetails(_selectedCompetition!.id);
    } else {
      await loadCompetitions();
    }
  }

  // 清除緩存
  void clearCache() {
    if (_isDisposed) return; // 新增：安全檢查
    _competitionService.clearCache();
  }

  // 獲取適合某年齡的比賽列表
  List<CompetitionModel> getCompetitionsSuitableForAge(int age) {
    if (_isDisposed) return []; // 新增：安全檢查
    return _allCompetitions.where((competition) {
      if (competition.metadata == null ||
          !competition.metadata!.containsKey('ageGroups')) {
        // 如果沒有年齡分組限制，則假設所有年齡都可參加
        return true;
      }

      // 使用AgeGroupHandler加載年齡分組
      final ageGroups =
          AgeGroupHandler.loadAgeGroupsFromMetadata(competition.metadata);

      // 檢查是否有適合該年齡的分組
      for (var group in ageGroups) {
        int? startAge = group['startAge'] as int?;
        int? endAge = group['endAge'] as int?;

        if (startAge != null && endAge != null) {
          if (age >= startAge && age <= endAge) {
            return true; // 找到適合的年齡組別
          }
        }
      }

      return false; // 沒有適合的年齡組別
    }).toList();
  }

  // 根據出生日期篩選合適的比賽
  List<CompetitionModel> getCompetitionsSuitableForBirthDate(
      DateTime birthDate) {
    if (_isDisposed) return []; // 新增：安全檢查
    // 使用AgeGroupHandler計算年齡
    int age = AgeGroupHandler.calculateAge(birthDate);
    return getCompetitionsSuitableForAge(age);
  }

  // 設置基於年齡的過濾
  void setAgeFilter(int age) {
    if (_isDisposed) return; // 新增：安全檢查

    List<CompetitionModel> ageFilteredCompetitions =
        getCompetitionsSuitableForAge(age);

    // 現在將這些比賽設置為過濾後的結果，但仍然需要應用搜索過濾
    _filteredCompetitions = ageFilteredCompetitions.where((competition) {
      // 檢查名稱是否包含搜索關鍵詞
      final matchesQuery =
          competition.name.toLowerCase().contains(_searchQuery);

      return matchesQuery;
    }).toList();

    notifyListeners();
  }

  // 清除年齡過濾
  void clearAgeFilter() {
    if (_isDisposed) return; // 新增：安全檢查

    // 重置為原始列表並應用其他過濾條件
    _applyFilters();
    notifyListeners();
  }
}
