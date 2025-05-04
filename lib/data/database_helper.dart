import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:logging/logging.dart';
import 'competition_manager.dart';
import 'dart:convert';

class DatabaseHelper {
  // 單例模式
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  // 日誌記錄器
  final _log = Logger('DatabaseHelper');

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  // 數據庫名稱和版本 - 確保與 CompetitionManager 使用相同名稱
  static const String dbName = 'competition_app.db';
  static const int databaseVersion = 1;

  // 表名 - 確保與 CompetitionManager 使用相同名稱
  static const String tableCompetition = 'competitions';
  static const String tableParticipant = 'participants';

  // 數據庫引用
  static Database? _database;

  // 獲取數據庫實例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();

    // 在獲取數據庫後立即檢查並升級結構
    await upgradeDatabase();

    return _database!;
  }

  // 初始化數據庫
  Future<Database> _initDatabase() async {
    try {
      // 使用固定的應用文檔目錄路徑
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, dbName);
      _log.info('📁 DatabaseHelper初始化路徑: $path');

      // 確保建立了數據庫目錄
      if (!await Directory(dirname(path)).exists()) {
        await Directory(dirname(path)).create(recursive: true);
        _log.info('📁 創建數據庫目錄: ${dirname(path)}');
      }

      // 開啟或創建數據庫
      final db = await openDatabase(
        path,
        version: databaseVersion,
        onCreate: _onCreate,
        onOpen: (db) async {
          // 檢查表是否存在，如果不存在則創建
          final tables = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableCompetition'");
          if (tables.isEmpty) {
            _log.warning('⚠️ 表不存在，嘗試創建...');
            await _onCreate(db, databaseVersion);
          } else {
            _log.info('✅ 找到已存在的表: ${tables.first['name']}');
          }
        },
      );

      _log.info('✅ DatabaseHelper成功初始化數據庫: $path');
      return db;
    } catch (e) {
      _log.severe('❌ 主數據庫初始化失敗: $e');

      try {
        // 嘗試使用臨時目錄作為備用
        Directory tempDir = await getTemporaryDirectory();
        String tempPath = join(tempDir.path, dbName);
        _log.info('📁 使用臨時數據庫路徑: $tempPath');

        return await openDatabase(
          tempPath,
          version: databaseVersion,
          onCreate: _onCreate,
          onOpen: (db) async {
            final tables = await db.rawQuery(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableCompetition'");
            if (tables.isEmpty) {
              _log.warning('⚠️ 臨時數據庫表不存在，嘗試創建...');
              await _onCreate(db, databaseVersion);
            }
          },
        );
      } catch (tempError) {
        _log.severe('❌ 臨時數據庫初始化也失敗: $tempError');
        throw Exception('無法初始化任何數據庫: $e, $tempError');
      }
    }
  }

  // 創建表結構
  Future _onCreate(Database db, int version) async {
    _log.info('📝 DatabaseHelper: 創建數據庫表...');

    try {
      // 建立競賽表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableCompetition (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT NOT NULL,
          venue TEXT,
          start_date TEXT NOT NULL,
          end_date TEXT NOT NULL,
          status TEXT NOT NULL,
          created_by TEXT NOT NULL,
          created_by_uid TEXT,
          created_at TEXT NOT NULL,
          events TEXT,
          metadata TEXT
        )
      ''');
      _log.info('✅ 成功創建 $tableCompetition 表');

      // 建立參與者表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableParticipant (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          competition_id TEXT NOT NULL,
          contact TEXT,
          registration_date TEXT NOT NULL,
          status TEXT NOT NULL,
          FOREIGN KEY (competition_id) REFERENCES $tableCompetition (id) ON DELETE CASCADE
        )
      ''');
      _log.info('✅ 成功創建 $tableParticipant 表');

      // 確認表已創建
      final tables = await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      _log.info('📊 數據庫中的表: $tables');
    } catch (e) {
      _log.severe('❌ 創建表失敗: $e');
      // 重新拋出異常，使調用者能夠處理錯誤
      rethrow;
    }
  }

  Future<int> insert(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert(tableCompetition, row);
  }

  // 保存比賽到本地數據庫
  Future<int> saveCompetition(Map<String, dynamic> competition) async {
    // 確保ID已設置
    if (competition['id'] == null || competition['id'].toString().isEmpty) {
      throw Exception('無法保存比賽：ID不能為空');
    }

    // 打印調試信息
    _log.info('保存比賽數據到SQLite: $competition');
    _log.info('ID確認: ${competition['id']}');

    try {
      // 使用CompetitionManager.instance.insertFromMap來保存到SQLite
      final result =
          await CompetitionManager.instance.insertFromMap(competition);
      _log.info('通過CompetitionManager保存結果: $result');

      // 驗證數據是否存在
      final competitions =
          await CompetitionManager.instance.getAllCompetitions();
      _log.info('📦 本地 SQLite 目前共有 ${competitions.length} 筆資料');

      // 驗證剛剛插入的資料是否存在
      final savedComp =
          competitions.where((c) => c.id == competition['id']).toList();
      if (savedComp.isNotEmpty) {
        _log.info('✅ 已確認資料存在於SQLite: ${savedComp.first.name}');
      } else {
        _log.warning('⚠️ 警告：無法在SQLite中找到剛插入的資料 ID: ${competition['id']}');
      }

      return result;
    } catch (e, stacktrace) {
      _log.severe('❌ SQLite 插入失敗: $e');
      _log.severe('堆疊追蹤: $stacktrace');
      rethrow;
    }
  }

  // 獲取所有比賽
  Future<List<Map<String, dynamic>>> getAllCompetitions() async {
    // 確保先檢查和升級數據庫結構
    await upgradeDatabase();

    Database db = await database;
    final result = await db.query(tableCompetition);
    _log.info('從數據庫獲取比賽數量: ${result.length}');

    // 將snake_case轉換為camelCase
    return result.map((row) {
      final Map<String, dynamic> compData = {
        'id': row['id'],
        'name': row['name'],
        'description': row['description'],
        'venue': row['venue'],
        'startDate': row['start_date'],
        'endDate': row['end_date'],
        'status': row['status'],
        'createdBy': row['created_by'],
        'createdByUid': row['created_by_uid'],
        'createdAt': row['created_at'],
      };

      // 處理JSON格式的events和metadata
      if (row['events'] != null) {
        try {
          compData['events'] = jsonDecode(row['events'].toString());
          _log.info('📝 解析events JSON成功: ${compData['events']}');
        } catch (jsonError) {
          _log.warning('⚠️ 解析events JSON失敗: $jsonError');
        }
      }

      if (row['metadata'] != null) {
        try {
          compData['metadata'] = jsonDecode(row['metadata'].toString());
          _log.info('📝 解析metadata JSON成功: ${compData['metadata']}');
        } catch (jsonError) {
          _log.warning('⚠️ 解析metadata JSON失敗: $jsonError');
        }
      }

      return compData;
    }).toList();
  }

  // 根據ID獲取比賽
  Future<Map<String, dynamic>?> getCompetitionById(String id) async {
    Database db = await database;
    List<Map<String, dynamic>> results = await db.query(
      tableCompetition,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) {
      return null;
    }

    // 轉換snake_case為camelCase並處理JSON
    final row = results.first;
    final Map<String, dynamic> compData = {
      'id': row['id'],
      'name': row['name'],
      'description': row['description'],
      'venue': row['venue'],
      'startDate': row['start_date'],
      'endDate': row['end_date'],
      'status': row['status'],
      'createdBy': row['created_by'],
      'createdByUid': row['created_by_uid'],
      'createdAt': row['created_at'],
    };

    // 處理JSON格式的events和metadata
    if (row['events'] != null) {
      try {
        compData['events'] = jsonDecode(row['events'].toString());
        _log.info('📝 解析events JSON成功: ${compData['events']}');
      } catch (jsonError) {
        _log.warning('⚠️ 解析events JSON失敗: $jsonError');
      }
    }

    if (row['metadata'] != null) {
      try {
        compData['metadata'] = jsonDecode(row['metadata'].toString());
        _log.info('📝 解析metadata JSON成功: ${compData['metadata']}');
      } catch (jsonError) {
        _log.warning('⚠️ 解析metadata JSON失敗: $jsonError');
      }
    }

    return compData;
  }

  // 更新比賽
  Future<int> updateCompetition(
      String id, Map<String, dynamic> competition) async {
    _log.info('更新比賽 ID: $id, 數據: $competition');

    Database db = await database;

    // 創建與數據庫列名對應的數據
    final dbCompetition = {
      'name': competition['name'],
      'description': competition['description'],
      'venue': competition['venue'] ?? '',
      'start_date': competition['startDate'],
      'end_date': competition['endDate'],
      'status': competition['status'],
      'created_by': competition['createdBy'],
      'created_by_uid': competition['createdByUid'],
      'created_at': competition['createdAt'],
    };

    // 處理events和metadata欄位，將其轉換為JSON字符串
    if (competition['events'] != null) {
      dbCompetition['events'] = jsonEncode(competition['events']);
      _log.info('📝 轉換events為JSON: ${dbCompetition['events']}');
    }

    if (competition['metadata'] != null) {
      dbCompetition['metadata'] = jsonEncode(competition['metadata']);
      _log.info('📝 轉換metadata為JSON: ${dbCompetition['metadata']}');
    }

    // 更新數據庫
    final result = await db.update(
      tableCompetition,
      dbCompetition,
      where: 'id = ?',
      whereArgs: [id],
    );

    _log.info('更新結果: $result, ID: $id');

    // 驗證更新是否成功
    if (result > 0) {
      final check = await db.query(tableCompetition,
          where: 'id = ?',
          whereArgs: [id],
          columns: ['id', 'name', 'events', 'metadata']);

      if (check.isNotEmpty) {
        _log.info('✓ 驗證成功: 已更新比賽 ${check.first['name']}');

        // 檢查events和metadata是否已更新
        if (check.first['events'] != null) {
          _log.info('✓ events已更新: ${check.first['events']}');
        }
        if (check.first['metadata'] != null) {
          _log.info('✓ metadata已更新: ${check.first['metadata']}');
        }
      }
    }

    return result;
  }

  // 刪除比賽
  Future<int> deleteCompetition(String id) async {
    Database db = await database;
    return await db.delete(
      tableCompetition,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 保存參與者
  Future<int> saveParticipant(Map<String, dynamic> participant) async {
    Database db = await database;

    // 打印調試信息
    _log.info('保存參與者數據: $participant');

    return await db.transaction((txn) async {
      int result = await txn.insert(
        tableParticipant,
        participant,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 確認數據已保存
      final savedData = await txn.query(
        tableParticipant,
        where: 'id = ?',
        whereArgs: [participant['id']],
      );

      if (savedData.isNotEmpty) {
        _log.info('成功保存參與者: ${savedData.first}');
      } else {
        _log.warning('保存參與者失敗，未找到插入的記錄');
      }

      return result;
    });
  }

  // 獲取比賽的所有參與者
  Future<List<Map<String, dynamic>>> getParticipantsByCompetition(
      String competitionId) async {
    Database db = await database;
    return await db.query(
      tableParticipant,
      where: 'competition_id = ?',
      whereArgs: [competitionId],
    );
  }

  // 獲取數據庫路徑
  Future<String> getDatabasePath() async {
    final db = await database;
    return db.path;
  }

  // 獲取比賽數量
  Future<int> getCompetitionCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM $tableCompetition');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // 執行原始SQL查詢
  Future<List<Map<String, dynamic>>> rawQuery(String sql,
      [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  // 刪除比賽 - 為了兼容性
  Future<int> delete(String id) async {
    return await deleteCompetition(id);
  }

  // 升級數據庫結構
  Future<void> upgradeDatabase() async {
    try {
      final db = await _database!;
      _log.info('📝 檢查並更新數據庫結構...');

      // 檢查表結構
      final tableInfo =
          await db.rawQuery("PRAGMA table_info($tableCompetition)");
      bool hasEventsColumn = false;
      bool hasMetadataColumn = false;
      bool hasCreatedByUidColumn = false;

      for (var column in tableInfo) {
        final colName = column['name'].toString();
        if (colName == 'events') hasEventsColumn = true;
        if (colName == 'metadata') hasMetadataColumn = true;
        if (colName == 'created_by_uid') hasCreatedByUidColumn = true;
      }

      _log.info(
          '📊 當前結構: events欄位=${hasEventsColumn}, metadata欄位=${hasMetadataColumn}, created_by_uid欄位=${hasCreatedByUidColumn}');

      // 開始事務以確保所有更改一起應用
      await db.transaction((txn) async {
        // 添加缺少的列
        if (!hasEventsColumn) {
          await txn
              .execute("ALTER TABLE $tableCompetition ADD COLUMN events TEXT");
          _log.info('✅ 已添加events欄位');
        }

        if (!hasMetadataColumn) {
          await txn.execute(
              "ALTER TABLE $tableCompetition ADD COLUMN metadata TEXT");
          _log.info('✅ 已添加metadata欄位');
        }

        if (!hasCreatedByUidColumn) {
          await txn.execute(
              "ALTER TABLE $tableCompetition ADD COLUMN created_by_uid TEXT");
          _log.info('✅ 已添加created_by_uid欄位');
        }
      });

      // 報告升級結果
      if (!hasEventsColumn || !hasMetadataColumn || !hasCreatedByUidColumn) {
        _log.info('🔄 資料庫結構已更新');
      } else {
        _log.info('✓ 資料庫結構已是最新');
      }

      // 重新檢查結構以驗證更新
      final updatedTableInfo =
          await db.rawQuery("PRAGMA table_info($tableCompetition)");
      _log.info('🔍 更新後的表結構: $updatedTableInfo');
    } catch (e, stackTrace) {
      _log.severe('❌ 升級數據庫結構失敗: $e');
      _log.severe('堆疊追蹤: $stackTrace');
    }
  }
}
