import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import '../models/competition.dart';
import 'database_helper.dart'; // 使用DatabaseHelper
import 'competition_manager.dart'; // 使用CompetitionManager

// 集中管理比賽數據的類
class CompetitionData {
  // 單例模式實現
  static final CompetitionData _instance = CompetitionData._internal();

  // 日誌記錄器
  final _log = Logger('CompetitionData');

  // 私有構造函數
  CompetitionData._internal();

  // 工廠構造函數，返回單例實例
  factory CompetitionData() {
    return _instance;
  }

  // Firestore 引用
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // SQLite 數據庫幫助類
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // 存儲所有比賽的列表
  List<CompetitionModel> _competitions = [];

  // 比賽集合的引用
  CollectionReference get competitionsRef =>
      _firestore.collection('competitions');

  // 獲取所有比賽
  List<CompetitionModel> get competitions => _competitions;

  // 初始化加載數據
  Future<void> loadCompetitions() async {
    try {
      // 加載Firebase數據
      final competitionDocs = await competitionsRef.get();
      _competitions = [];

      int i = 0;
      while (i < competitionDocs.docs.length) {
        try {
          final doc = competitionDocs.docs[i];
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // 確保 ID 正確設置
          _competitions.add(CompetitionModel.fromMap(data));
        } catch (e) {
          _log.warning('解析比賽數據錯誤: ${competitionDocs.docs[i].id}, $e');
        }
        i++;
      }

      // 加載SQLite數據
      try {
        final List<Map<String, dynamic>> sqliteData =
            await _dbHelper.getAllCompetitions();

        // 將數據庫行轉換為CompetitionModel對象
        for (var row in sqliteData) {
          // 檢查是否已經存在於列表中
          bool exists = false;
          for (var comp in _competitions) {
            if (comp.id == row['id']) {
              exists = true;
              break;
            }
          }

          if (!exists) {
            _competitions.add(CompetitionModel.fromMap(row));
          }
        }

        // 獲取並打印數據庫計數
        final count = await _dbHelper.getCompetitionCount();
        _log.info('從SQLite加載了 ${sqliteData.length} 個比賽，總數: $count');

        // 獲取並打印數據庫路徑
        final dbPath = await _dbHelper.getDatabasePath();
        _log.info('數據庫路徑: $dbPath');
      } catch (e) {
        _log.severe('從SQLite加載比賽失敗: $e');
      }
    } catch (e) {
      _log.severe('加載比賽數據失敗: $e');

      // 如果Firebase加載失敗，嘗試從SQLite加載
      try {
        final List<Map<String, dynamic>> sqliteData =
            await _dbHelper.getAllCompetitions();

        // 清空並重新填充比賽列表
        _competitions = [];
        for (var row in sqliteData) {
          _competitions.add(CompetitionModel.fromMap(row));
        }

        final count = await _dbHelper.getCompetitionCount();
        _log.info('從SQLite加載了 ${_competitions.length} 個比賽，總數: $count');
      } catch (sqliteError) {
        _log.severe('SQLite加載失敗: $sqliteError');
        throw e; // 如果兩者都失敗，拋出原始錯誤
      }
    }
  }

  // 獲取符合條件的比賽列表
  Future<List<CompetitionModel>> getFilteredCompetitions(
      String query, String filter) async {
    // 確保數據已加載
    if (_competitions.isEmpty) {
      await loadCompetitions();
    }

    // 使用線性搜索篩選數據
    String lowerQuery = query.toLowerCase();
    List<CompetitionModel> results = [];

    int i = 0;
    while (i < _competitions.length) {
      final competition = _competitions[i];

      // 先檢查狀態是否匹配
      if (filter == '全部' || competition.status == filter) {
        // 再檢查名稱是否匹配
        if (query.isEmpty ||
            competition.name.toLowerCase().contains(lowerQuery)) {
          results.add(competition);
        }
      }

      i++;
    }

    return results;
  }

  // 添加新比賽
  Future<String> addCompetition(Map<String, dynamic> competitionData) async {
    String id = '';
    bool firebaseSuccess = false;

    try {
      // 第一步：保存到Firestore並獲取ID
      try {
        // 使用add()方法自動生成ID
        final docRef = await competitionsRef.add(competitionData);
        id = docRef.id;

        // 將Firebase生成的ID設置回資料中
        competitionData['id'] = id;
        _log.info('已保存到Firebase並獲取ID: $id');

        // 更新Firebase上的文檔，加入ID
        await docRef.update({'id': id});
        firebaseSuccess = true;
      } catch (firebaseError) {
        _log.warning('保存到Firebase失敗: $firebaseError');
        // 這裡我們不立即拋出異常，而是將錯誤記錄下來
      }

      // 第二步：保存到SQLite數據庫
      bool sqliteSuccess = false;
      String? sqliteError;

      try {
        final result =
            await CompetitionManager.instance.insertFromMap(competitionData);
        _log.info('✅ 已插入 SQLite！結果: $result, ID: $id');
        sqliteSuccess = true;
      } catch (e) {
        sqliteError = e.toString();
        _log.severe('❌ 保存到SQLite失敗: $e');
      }

      // 檢查兩個存儲是否都成功
      if (!firebaseSuccess && !sqliteSuccess) {
        throw Exception('Firebase 和 SQLite 保存均失敗');
      }

      // 如果只有一個存儲成功，記錄警告但仍然繼續
      if (!firebaseSuccess) {
        _log.warning('⚠️ 警告：只有SQLite保存成功，Firebase保存失敗');
      }

      if (!sqliteSuccess) {
        _log.warning('⚠️ 警告：只有Firebase保存成功，SQLite保存失敗：$sqliteError');
      }

      // 更新本地記憶體數據
      _competitions.add(CompetitionModel.fromMap(competitionData));

      // 驗證SQLite保存結果
      if (sqliteSuccess) {
        try {
          final comps = await CompetitionManager.instance.getAllCompetitions();
          final savedComp = comps.where((c) => c.id == id).toList();
          if (savedComp.isNotEmpty) {
            _log.info('✓ 確認資料已寫入SQLite：${savedComp.first.name}');
          } else {
            _log.warning('⚠️ 警告：無法在SQLite中找到剛插入的資料 ID: $id');
          }
        } catch (verifyError) {
          _log.warning('驗證SQLite資料時出錯: $verifyError');
        }
      }

      return id;
    } catch (e) {
      // 如果發生完全失敗，嘗試清理
      if (firebaseSuccess && id.isNotEmpty) {
        try {
          await competitionsRef.doc(id).delete();
          _log.info('因操作失敗，已清理Firebase中的數據: $id');
        } catch (cleanupError) {
          _log.warning('清理Firebase數據失敗: $cleanupError');
        }
      }

      _log.severe('添加比賽完全失敗: $e');
      rethrow;
    }
  }

  // 更新比賽
  Future<void> updateCompetition(
      String id, Map<String, dynamic> competitionData) async {
    try {
      // 確保ID存在於數據中
      competitionData['id'] = id;

      // 更新Firestore
      try {
        await competitionsRef.doc(id).update(competitionData);
        _log.info('已更新到Firebase: $id');
      } catch (firebaseError) {
        _log.warning('更新Firebase失敗: $firebaseError');
      }

      // 更新SQLite
      try {
        final result = await _dbHelper.updateCompetition(id, competitionData);
        _log.info('更新SQLite結果: $result, ID: $id');

        // 驗證更新
        final updatedData = await _dbHelper.getCompetitionById(id);
        if (updatedData != null) {
          _log.info('成功驗證比賽已更新: ${updatedData['name']}');
        }
      } catch (sqliteError) {
        _log.warning('更新SQLite失敗: $sqliteError');
      }

      // 更新本地數據
      int i = 0;
      while (i < _competitions.length) {
        if (_competitions[i].id == id) {
          _competitions[i] = CompetitionModel.fromMap(competitionData);
          break;
        }
        i++;
      }
    } catch (e) {
      _log.severe('更新比賽失敗: $e');
      rethrow;
    }
  }

  // 刪除比賽
  Future<void> deleteCompetition(String id) async {
    try {
      // 從Firestore刪除
      try {
        await competitionsRef.doc(id).delete();
        _log.info('已從Firebase刪除: $id');
      } catch (firebaseError) {
        _log.warning('從Firebase刪除失敗: $firebaseError');
      }

      // 從SQLite刪除
      try {
        final result = await _dbHelper.delete(id);
        _log.info('從SQLite刪除結果: $result, ID: $id');
      } catch (sqliteError) {
        _log.warning('從SQLite刪除失敗: $sqliteError');
      }

      // 從本地數據刪除
      _competitions.removeWhere((competition) => competition.id == id);
    } catch (e) {
      _log.severe('刪除比賽失敗: $e');
      rethrow;
    }
  }

  // 根據ID獲取比賽
  CompetitionModel? getCompetitionById(String id) {
    int i = 0;
    while (i < _competitions.length) {
      if (_competitions[i].id == id) {
        return _competitions[i];
      }
      i++;
    }
    return null;
  }

  // 從數據庫獲取比賽詳細信息
  Future<CompetitionModel?> getCompetitionByIdFromDb(String id) async {
    final Map<String, dynamic>? data = await _dbHelper.getCompetitionById(id);
    return data != null ? CompetitionModel.fromMap(data) : null;
  }

  // 檢查SQLite數據庫狀態
  Future<Map<String, dynamic>> checkSQLiteStatus() async {
    try {
      final path = await _dbHelper.getDatabasePath();
      final count = await _dbHelper.getCompetitionCount();

      // 嘗試執行直接SQL查詢
      final sqlResult =
          await _dbHelper.rawQuery('SELECT * FROM competitions LIMIT 5');

      return {
        'success': true,
        'path': path,
        'count': count,
        'sample_data': sqlResult,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
