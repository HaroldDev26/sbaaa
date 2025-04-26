import 'dart:async';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/competition.dart';

class CompetitionManager {
  // 單例模式實現
  static final CompetitionManager _instance = CompetitionManager._internal();

  // 日誌記錄器
  final _log = Logger('CompetitionManager');

  // 私有構造函數
  CompetitionManager._internal();

  // 工廠構造函數，返回單例實例
  factory CompetitionManager() {
    return _instance;
  }

  // 可以直接訪問的單例實例
  static CompetitionManager get instance => _instance;

  // 數據庫名稱
  static const String dbName = 'competition_app.db';

  // 表名
  static const String tableCompetitions = 'competitions';
  static const String tableParticipants = 'participants';

  // 數據庫
  Database? _database;

  // 獲取數據庫
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // 初始化數據庫
  Future<Database> _initDatabase() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, dbName);
      _log.info('📂 初始化數據庫路徑: $path');

      final db = await openDatabase(path, version: 1, onCreate: _onCreate,
          onOpen: (db) async {
        final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableCompetitions'");
        if (tables.isEmpty) {
          _log.warning('⚠️ 表不存在，嘗試創建...');
          await _onCreate(db, 1);
        } else {
          _log.info('✅ 找到已存在的表: ${tables.first['name']}');
        }
      });
      return db;
    } catch (e) {
      _log.severe('❌ 獲取路徑失敗: $e');
      _log.warning('⚠️ 嘗試使用臨時路徑...');

      // 嘗試使用臨時路徑
      try {
        Directory tempDir = await getTemporaryDirectory();
        String tempPath = join(tempDir.path, dbName);
        _log.info('📂 使用臨時數據庫路徑: $tempPath');

        final db = await openDatabase(
          tempPath,
          version: 1,
          onCreate: _onCreate,
          onOpen: (db) async {
            final tables = await db.rawQuery(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableCompetitions'");
            if (tables.isEmpty) {
              _log.warning('⚠️ 表不存在，嘗試創建...');
              await _onCreate(db, 1);
            } else {
              _log.info('✅ 找到已存在的表: ${tables.first['name']}');
            }
          },
        );
        return db;
      } catch (tempError) {
        _log.severe('❌ 臨時路徑也失敗: $tempError');
        _log.warning('⚠️ 嘗試使用備用固定路徑...');

        // 嘗試使用備用固定路徑
        const backupPath =
            '/data/user/0/com.example.sbaaa/databases/competition_app.db';
        _log.info('📂 使用備用固定路徑: $backupPath');

        // 確保目錄存在
        final dir = Directory(dirname(backupPath));
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        final db = await openDatabase(backupPath,
            version: 1, onCreate: _onCreate, onOpen: (db) async {
          final tables = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableCompetitions'");
          if (tables.isEmpty) {
            _log.warning('⚠️ 表不存在，嘗試創建...');
            await _onCreate(db, 1);
          } else {
            _log.info('✅ 找到已存在的表: ${tables.first['name']}');
          }
        });
        return db;
      }
    }
  }

  // 創建數據庫表
  Future<void> _onCreate(Database db, int version) async {
    _log.info('創建數據庫表...');

    // 創建比賽表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCompetitions (
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

    // 創建參與者表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableParticipants (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        competition_id TEXT NOT NULL,
        contact TEXT,
        registration_date TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (competition_id) REFERENCES $tableCompetitions (id) ON DELETE CASCADE
      )
    ''');

    _log.info('數據庫表創建完成');
  }

  // 插入比賽
  Future<int> insert(CompetitionModel competition) async {
    // 準備行數據
    final row = {
      'id': competition.id,
      'name': competition.name,
      'description': competition.description,
      'venue': competition.venue,
      'start_date': competition.startDate,
      'end_date': competition.endDate,
      'status': competition.status,
      'created_by': competition.createdBy,
      'created_at': competition.createdAt,
    };

    _log.info('保存比賽到SQLite: $row');

    try {
      final Database db = await database;
      int result = await db.insert(tableCompetitions, row,
          conflictAlgorithm: ConflictAlgorithm.replace);

      // 驗證數據是否已插入
      final inserted = await db.query(tableCompetitions,
          where: 'id = ?', whereArgs: [competition.id], limit: 1);

      if (inserted.isNotEmpty) {
        _log.info('成功插入比賽 ID: ${competition.id}, 結果: $result');
      } else {
        _log.warning('插入失敗，未找到ID: ${competition.id}');
      }

      return result;
    } catch (e) {
      _log.severe('插入比賽時出錯: $e');
      rethrow;
    }
  }

  // 從Map直接插入比賽數據
  Future<int> insertFromMap(Map<String, dynamic> competitionData) async {
    // 確保ID存在
    if (competitionData['id'] == null ||
        competitionData['id'].toString().isEmpty) {
      throw Exception('比賽ID不能為空');
    }

    try {
      final Database db = await database;
      String dbPath = db.path;
      _log.info('🗄️ 使用數據庫: $dbPath');

      // 確保數據庫中的表名匹配
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableCompetitions'");
      if (tables.isEmpty) {
        await _onCreate(db, 1);
      }

      // 轉換為適合數據庫的列名格式
      final Map<String, dynamic> row = {
        'id': competitionData['id'],
        'name': competitionData['name'],
        'description': competitionData['description'],
        'venue': competitionData['venue'] ?? '',
        'start_date': competitionData['startDate'],
        'end_date': competitionData['endDate'],
        'status': competitionData['status'],
        'created_by': competitionData['createdBy'],
        'created_at': competitionData['createdAt'],
      };

      _log.info('📝 從Map保存比賽到SQLite: $row');

      // 檢查表結構
      final tableInfo =
          await db.rawQuery("PRAGMA table_info($tableCompetitions)");
      _log.info('📊 表結構: $tableInfo');

      // 檢查是否已存在相同ID的記錄
      final existing = await db.query(
        tableCompetitions,
        where: 'id = ?',
        whereArgs: [row['id']],
      );

      if (existing.isNotEmpty) {
        _log.warning('⚠️ 已存在相同ID的記錄: ${existing.first}');
        // 繼續執行，將使用REPLACE衝突策略
      }

      // 執行插入
      int result = await db.insert(
        tableCompetitions,
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _log.info('✅ 插入結果: $result, ID: ${row['id']}');

      // 驗證插入是否成功
      final check = await db.query(
        tableCompetitions,
        where: 'id = ?',
        whereArgs: [row['id']],
      );

      if (check.isEmpty) {
        _log.warning('❌ 驗證失敗: 插入後無法找到數據');
      } else {
        _log.info('✓ 驗證成功: 找到插入的數據 ${check.first}');
      }

      return result;
    } catch (e, stackTrace) {
      _log.severe('❌ insertFromMap失敗: $e');
      _log.severe('堆疊追蹤: $stackTrace');
      rethrow;
    }
  }

  // 獲取所有比賽
  Future<List<CompetitionModel>> getAllCompetitions() async {
    try {
      final db = await database;
      _log.info('📂 getAllCompetitions使用數據庫: ${db.path}');

      List<CompetitionModel> results = [];

      // 嘗試直接使用原始SQL查詢
      try {
        final rawResult = await db.rawQuery('SELECT * FROM $tableCompetitions');
        _log.info('🔍 原始SQL查詢結果: ${rawResult.length} 筆資料');
        if (rawResult.isNotEmpty) {
          _log.info('🔍 第一筆原始資料: ${rawResult.first}');
        }
      } catch (rawError) {
        _log.warning('❌ 原始SQL查詢失敗: $rawError');
      }

      // 使用普通查詢
      final List<Map<String, dynamic>> maps = await db.query(tableCompetitions);
      _log.info('📊 從SQLite獲取比賽數量: ${maps.length}');

      if (maps.isEmpty) {
        _log.warning('⚠️ SQLite中沒有比賽資料');
        return [];
      }

      // 打印第一個結果以便調試
      if (maps.isNotEmpty) {
        _log.info('✅ 查詢到的第一筆資料: ${maps.first}');
      }

      // 轉換結果行到模型對象
      int i = 0;
      while (i < maps.length) {
        try {
          // 將snake_case轉換為camelCase
          final modelData = {
            'id': maps[i]['id'],
            'name': maps[i]['name'],
            'description': maps[i]['description'],
            'venue': maps[i]['venue'],
            'startDate': maps[i]['start_date'],
            'endDate': maps[i]['end_date'],
            'status': maps[i]['status'],
            'createdBy': maps[i]['created_by'],
            'createdAt': maps[i]['created_at'],
          };

          final model = CompetitionModel.fromMap(modelData);
          results.add(model);
          _log.info('✓ 成功轉換為模型 #${i + 1}: ${model.id} - ${model.name}');
        } catch (conversionError) {
          // 跳過轉換失敗的記錄
        }
        i++;
      }

      return results;
    } catch (e, stackTrace) {
      _log.severe('❌ getAllCompetitions失敗: $e');
      _log.severe('堆疊追蹤: $stackTrace');
      rethrow;
    }
  }

  // 根據ID獲取比賽
  Future<CompetitionModel?> getCompetitionById(String? id) async {
    if (id == null || id.isEmpty) {
      _log.warning('⚠️ 獲取比賽: ID為空');
      return null;
    }

    try {
      final db = await database;
      _log.info('🔍 正在獲取比賽 ID: $id');

      // 查詢數據庫
      final List<Map<String, dynamic>> results = await db.query(
        tableCompetitions,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (results.isEmpty) {
        _log.warning('⚠️ 未找到比賽 ID: $id');
        return null;
      }

      _log.info('✅ 找到比賽: ${results.first}');

      // 將snake_case轉換為camelCase
      final modelData = {
        'id': results.first['id'],
        'name': results.first['name'],
        'description': results.first['description'],
        'venue': results.first['venue'],
        'startDate': results.first['start_date'],
        'endDate': results.first['end_date'],
        'status': results.first['status'],
        'createdBy': results.first['created_by'],
        'createdAt': results.first['created_at'],
      };

      return CompetitionModel.fromMap(modelData);
    } catch (e, stackTrace) {
      _log.severe('❌ 獲取比賽失敗: $e');
      _log.severe('堆疊追蹤: $stackTrace');
      return null;
    }
  }

  // 獲取數據庫路徑
  Future<String> getDatabasePath() async {
    final db = await database;
    return db.path;
  }

  // 獲取比賽數量
  Future<int> getCompetitionCount() async {
    Database db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM $tableCompetitions');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // 更新比賽
  Future<int> update(String id, Map<String, dynamic> data) async {
    Database db = await database;

    // 創建與數據庫列名對應的數據
    final dbData = {
      'name': data['name'],
      'description': data['description'],
      'venue': data['venue'] ?? '',
      'start_date': data['startDate'],
      'end_date': data['endDate'],
      'status': data['status'],
      'created_by': data['createdBy'],
      'created_at': data['createdAt'],
    };

    return await db.update(
      tableCompetitions,
      dbData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 執行原始SQL查詢
  Future<List<Map<String, dynamic>>> rawQuery(String sql,
      [List<dynamic>? arguments]) async {
    Database db = await database;
    return await db.rawQuery(sql, arguments);
  }

  // 檢查數據庫表結構
  Future<Map<String, dynamic>> checkDatabaseStructure() async {
    try {
      final db = await database;
      final dbPath = db.path;

      // 獲取所有表名
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;");

      // 獲取competitions表結構
      final competitionsSchema =
          await db.rawQuery('PRAGMA table_info($tableCompetitions)');

      // 獲取competitions表中的數據
      final competitionsData = await db.query(tableCompetitions);

      // 獲取測試查詢結果
      final testQuery =
          await db.rawQuery('SELECT COUNT(*) as count FROM $tableCompetitions');
      final countResult = Sqflite.firstIntValue(testQuery) ?? 0;

      return {
        'db_path': dbPath,
        'tables': tables,
        'competitions_schema': competitionsSchema,
        'competitions_count': competitionsData.length,
        'test_query_count': countResult,
        'first_record':
            competitionsData.isNotEmpty ? competitionsData.first : null
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // 刪除比賽
  Future<int> delete(String id) async {
    Database db = await database;
    return await db.delete(
      tableCompetitions,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
