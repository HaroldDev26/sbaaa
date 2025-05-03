import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/competition_model.dart';
import '../services/competition_service.dart';
import '../utils/age_group_handler.dart'; // 導入年齡分組處理工具

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
    _registrationsSubscription?.cancel();
    super.dispose();
  }

  // 加載競賽列表
  Future<void> loadCompetitions() async {
    _loadingState = CompetitionLoadingState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      // 使用服務層獲取數據
      final competitions = await _competitionService.getAvailableCompetitions();

      _allCompetitions =
          competitions.map((map) => CompetitionModel.fromMap(map)).toList();

      // 應用過濾器和搜索
      _applyFilters();
      _loadingState = CompetitionLoadingState.loaded;
    } catch (e) {
      _loadingState = CompetitionLoadingState.error;
      _errorMessage = '載入比賽列表失敗: $e';
    }

    notifyListeners();
  }

  // 加載特定競賽詳情
  Future<void> loadCompetitionDetails(String competitionId) async {
    _loadingState = CompetitionLoadingState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      // 使用服務層獲取數據
      final competitionData =
          await _competitionService.getCompetitionDetails(competitionId);

      if (competitionData == null) {
        _loadingState = CompetitionLoadingState.error;
        _errorMessage = '找不到該比賽';
      } else {
        _selectedCompetition = CompetitionModel.fromMap(competitionData);
        _loadingState = CompetitionLoadingState.loaded;
      }
    } catch (e) {
      _loadingState = CompetitionLoadingState.error;
      _errorMessage = '載入比賽詳情失敗: $e';
    }

    notifyListeners();
  }

  // 設置搜索查詢
  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilters();
    notifyListeners();
  }

  // 設置狀態過濾器
  void setStatusFilter(String filter) {
    _statusFilter = filter;
    _applyFilters();
    notifyListeners();
  }

  // 設置選中的競賽
  void selectCompetition(CompetitionModel competition) {
    _selectedCompetition = competition;
    notifyListeners();
  }

  // 清除選中的競賽
  void clearSelectedCompetition() {
    _selectedCompetition = null;
    notifyListeners();
  }

  // 應用過濾器和搜索
  void _applyFilters() {
    _filteredCompetitions = _allCompetitions.where((competition) {
      // 檢查名稱是否包含搜索關鍵詞
      final matchesQuery =
          competition.name.toLowerCase().contains(_searchQuery);

      // 不再檢查狀態過濾
      return matchesQuery;
    }).toList();
  }

  // 開始報名流程
  Future<void> startRegistration(CompetitionModel competition) async {
    _registrationState = RegistrationActionState.loading;
    notifyListeners();

    // 模擬短暫延遲，以顯示加載狀態
    await Future.delayed(const Duration(milliseconds: 300));

    _registrationState = RegistrationActionState.success;
    notifyListeners();
  }

  // 刷新數據
  Future<void> refresh() async {
    if (_selectedCompetition != null) {
      await loadCompetitionDetails(_selectedCompetition!.id);
    } else {
      await loadCompetitions();
    }
  }

  // 清除緩存
  void clearCache() {
    _competitionService.clearCache();
  }

  // 獲取適合某年齡的比賽列表
  List<CompetitionModel> getCompetitionsSuitableForAge(int age) {
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
    // 使用AgeGroupHandler計算年齡
    int age = AgeGroupHandler.calculateAge(birthDate);
    return getCompetitionsSuitableForAge(age);
  }

  // 設置基於年齡的過濾
  void setAgeFilter(int age) {
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
    // 重新應用原始過濾器，不考慮年齡
    _applyFilters();
    notifyListeners();
  }
}
