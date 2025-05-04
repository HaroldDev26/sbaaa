import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:logging/logging.dart';
import '../data/competition_manager.dart';
import '../data/database_helper.dart';

/// SQLite測試工具，用於驗證SQLite存儲功能是否正常工作
class SQLiteTest {
  final _log = Logger('SQLiteTest');
  static final SQLiteTest _instance = SQLiteTest._internal();

  factory SQLiteTest() {
    return _instance;
  }

  SQLiteTest._internal();

  /// 測試直接使用SQLite API保存數據
  Future<Map<String, dynamic>> testDirectSQLiteInsert() async {
    try {
      // 1. 獲取數據庫路徑
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, 'competition_app.db');
      _log.info('📁 測試使用數據庫路徑: $path');

      // 2. 打開數據庫
      final db = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS competitions (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              description TEXT NOT NULL,
              venue TEXT,
              start_date TEXT NOT NULL,
              end_date TEXT NOT NULL,
              status TEXT NOT NULL,
              created_by TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
        },
      );

      // 3. 創建測試數據
      final testId = 'test_${DateTime.now().millisecondsSinceEpoch}';
      final testData = {
        'id': testId,
        'name': 'Test Competition Direct',
        'description': 'SQLite直接測試',
        'venue': 'Test Venue',
        'start_date': '2024-09-09',
        'end_date': '2024-09-10',
        'status': '測試',
        'created_by': 'System Test',
        'created_at': DateTime.now().toIso8601String(),
      };

      // 4. 直接插入數據
      _log.info('🔍 直接插入測試數據: $testData');
      final result = await db.insert(
        'competitions',
        testData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _log.info('📊 直接插入結果: $result');

      // 5. 查詢驗證
      final records =
          await db.query('competitions', where: 'id = ?', whereArgs: [testId]);

      final count = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM competitions')) ??
          0;

      // 6. 關閉數據庫
      await db.close();

      return {
        'success': records.isNotEmpty,
        'data': records.isNotEmpty ? records.first : null,
        'count': count,
        'insert_result': result,
        'database_path': path,
      };
    } catch (e, stackTrace) {
      _log.severe('❌ 直接測試SQLite失敗: $e');
      _log.severe('堆疊追蹤: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
        'stack_trace': stackTrace.toString(),
      };
    }
  }

  /// 測試通過CompetitionManager保存數據
  Future<Map<String, dynamic>> testManagerSQLiteInsert() async {
    try {
      final manager = CompetitionManager.instance;
      final testId = 'manager_test_${DateTime.now().millisecondsSinceEpoch}';

      // 1. 創建測試數據
      final testData = {
        'id': testId,
        'name': 'Manager Test Competition',
        'description': 'CompetitionManager測試',
        'venue': 'Manager Test Venue',
        'startDate': '2024-09-09',
        'endDate': '2024-09-10',
        'status': '測試',
        'createdBy': 'Manager Test',
        'createdAt': DateTime.now().toIso8601String(),
      };

      // 2. 使用Manager插入
      _log.info('🔍 通過Manager插入測試數據: $testData');
      final result = await manager.insertFromMap(testData);
      _log.info('📊 Manager插入結果: $result');

      // 3. 查詢驗證
      final dbPath = await manager.getDatabasePath();
      final allCompetitions = await manager.getAllCompetitions();
      final count = await manager.getCompetitionCount();

      // 檢查是否包含我們插入的測試數據
      final foundData =
          allCompetitions.where((comp) => comp.id == testId).toList();

      return {
        'success': foundData.isNotEmpty,
        'count': count,
        'total_records': allCompetitions.length,
        'found_record': foundData.isNotEmpty ? foundData.first.toMap() : null,
        'insert_result': result,
        'database_path': dbPath,
      };
    } catch (e, stackTrace) {
      _log.severe('❌ Manager測試SQLite失敗: $e');
      _log.severe('堆疊追蹤: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
        'stack_trace': stackTrace.toString(),
      };
    }
  }

  /// 測試通過DatabaseHelper保存數據
  Future<Map<String, dynamic>> testHelperSQLiteInsert() async {
    try {
      final helper = DatabaseHelper();
      final testId = 'helper_test_${DateTime.now().millisecondsSinceEpoch}';

      // 1. 創建測試數據
      final testData = {
        'id': testId,
        'name': 'Helper Test Competition',
        'description': 'DatabaseHelper測試',
        'venue': 'Helper Test Venue',
        'startDate': '2024-09-09',
        'endDate': '2024-09-10',
        'status': '測試',
        'createdBy': 'Helper Test',
        'createdAt': DateTime.now().toIso8601String(),
      };

      // 2. 使用Helper插入
      _log.info('🔍 通過Helper插入測試數據: $testData');
      final result = await helper.saveCompetition(testData);
      _log.info('📊 Helper插入結果: $result');

      // 3. 查詢驗證
      final dbPath = await helper.getDatabasePath();
      final allCompetitions = await helper.getAllCompetitions();

      // 檢查是否包含我們插入的測試數據
      final foundData =
          allCompetitions.where((comp) => comp['id'] == testId).toList();

      return {
        'success': foundData.isNotEmpty,
        'count': allCompetitions.length,
        'found_record': foundData.isNotEmpty ? foundData.first : null,
        'insert_result': result,
        'database_path': dbPath,
      };
    } catch (e, stackTrace) {
      _log.severe('❌ Helper測試SQLite失敗: $e');
      _log.severe('堆疊追蹤: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
        'stack_trace': stackTrace.toString(),
      };
    }
  }

  /// 檢查數據庫狀態並返回詳細信息
  Future<Map<String, dynamic>> checkDatabaseStatus() async {
    try {
      final manager = CompetitionManager.instance;
      final helper = DatabaseHelper();

      // 競賽管理器數據庫信息
      final managerDbPath = await manager.getDatabasePath();
      final managerCount = await manager.getCompetitionCount();
      final managerStructure = await manager.checkDatabaseStructure();

      // 數據庫助手信息
      final helperDbPath = await helper.getDatabasePath();
      final helperRawData = await helper.rawQuery('SELECT * FROM competitions');

      // 驗證两個路徑是否一致
      final pathsMatch = managerDbPath == helperDbPath;

      return {
        'success': true,
        'manager_db_path': managerDbPath,
        'helper_db_path': helperDbPath,
        'paths_match': pathsMatch,
        'competition_count': managerCount,
        'raw_data_count': helperRawData.length,
        'database_structure': managerStructure,
        'raw_data_sample':
            helperRawData.isNotEmpty ? helperRawData.first : null,
      };
    } catch (e, stackTrace) {
      _log.severe('❌ 檢查數據庫狀態失敗: $e');
      _log.severe('堆疊追蹤: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
        'stack_trace': stackTrace.toString(),
      };
    }
  }
}
