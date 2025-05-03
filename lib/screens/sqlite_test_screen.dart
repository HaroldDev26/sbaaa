import 'package:flutter/material.dart';
import '../utils/sqlite_test.dart';
import '../utils/colors.dart';

class SQLiteTestScreen extends StatefulWidget {
  const SQLiteTestScreen({Key? key}) : super(key: key);

  @override
  State<SQLiteTestScreen> createState() => _SQLiteTestScreenState();
}

class _SQLiteTestScreenState extends State<SQLiteTestScreen> {
  final SQLiteTest _sqliteTest = SQLiteTest();
  bool _isLoading = false;
  Map<String, dynamic>? _directTestResult;
  Map<String, dynamic>? _managerTestResult;
  Map<String, dynamic>? _helperTestResult;
  Map<String, dynamic>? _statusResult;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _sqliteTest.checkDatabaseStatus();
      setState(() {
        _statusResult = result;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('檢查狀態失敗: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _runDirectTest() async {
    setState(() {
      _isLoading = true;
      _directTestResult = null;
    });

    try {
      final result = await _sqliteTest.testDirectSQLiteInsert();
      setState(() {
        _directTestResult = result;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('直接測試失敗: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
      _checkStatus();
    }
  }

  Future<void> _runManagerTest() async {
    setState(() {
      _isLoading = true;
      _managerTestResult = null;
    });

    try {
      final result = await _sqliteTest.testManagerSQLiteInsert();
      setState(() {
        _managerTestResult = result;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Manager測試失敗: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
      _checkStatus();
    }
  }

  Future<void> _runHelperTest() async {
    setState(() {
      _isLoading = true;
      _helperTestResult = null;
    });

    try {
      final result = await _sqliteTest.testHelperSQLiteInsert();
      setState(() {
        _helperTestResult = result;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Helper測試失敗: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
      _checkStatus();
    }
  }

  Widget _buildResultCard(String title, Map<String, dynamic>? result) {
    if (result == null) {
      return Card(
        margin: const EdgeInsets.all(8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('$title: 未執行測試'),
        ),
      );
    }

    final success = result['success'] == true;
    final textColor = success ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title: ${success ? '成功' : '失敗'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textColor,
              ),
            ),
            const Divider(),
            if (result.containsKey('error'))
              Text('錯誤: ${result['error']}',
                  style: TextStyle(color: Colors.red)),
            if (result.containsKey('database_path'))
              Text('數據庫路徑: ${result['database_path']}'),
            if (result.containsKey('count')) Text('記錄數量: ${result['count']}'),
            if (result.containsKey('insert_result'))
              Text('插入結果代碼: ${result['insert_result']}'),
            if (result.containsKey('data') && result['data'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('數據樣本:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...(result['data'] as Map<String, dynamic>).entries.map(
                        (e) => Text('  ${e.key}: ${e.value}'),
                      ),
                ],
              ),
            if (result.containsKey('found_record') &&
                result['found_record'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('找到的記錄:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...(result['found_record'] as Map<String, dynamic>)
                      .entries
                      .map(
                        (e) => Text('  ${e.key}: ${e.value}'),
                      ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    if (_statusResult == null) {
      return const Card(
        margin: EdgeInsets.all(8.0),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('狀態: 未檢查'),
        ),
      );
    }

    final success = _statusResult!['success'] == true;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '數據庫狀態: ${success ? '正常' : '異常'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: success ? Colors.green : Colors.red,
              ),
            ),
            const Divider(),
            if (_statusResult!.containsKey('manager_db_path'))
              Text('Manager數據庫路徑: ${_statusResult!['manager_db_path']}'),
            if (_statusResult!.containsKey('helper_db_path'))
              Text('Helper數據庫路徑: ${_statusResult!['helper_db_path']}'),
            if (_statusResult!.containsKey('paths_match'))
              Text(
                '路徑一致: ${_statusResult!['paths_match'] ? '是' : '否'}',
                style: TextStyle(
                  color:
                      _statusResult!['paths_match'] ? Colors.green : Colors.red,
                ),
              ),
            if (_statusResult!.containsKey('competition_count'))
              Text('比賽數量: ${_statusResult!['competition_count']}'),
            if (_statusResult!.containsKey('raw_data_count'))
              Text('原始數據數量: ${_statusResult!['raw_data_count']}'),
            if (_statusResult!.containsKey('raw_data_sample') &&
                _statusResult!['raw_data_sample'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('數據樣本:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...((_statusResult!['raw_data_sample']
                          as Map<String, dynamic>)
                      .entries
                      .take(5)
                      .map(
                        (e) => Text('  ${e.key}: ${e.value}'),
                      )),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SQLite測試'),
        backgroundColor: primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'SQLite功能測試',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _runDirectTest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                        ),
                        child: const Text('直接API測試'),
                      ),
                      ElevatedButton(
                        onPressed: _runManagerTest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                        ),
                        child: const Text('Manager測試'),
                      ),
                      ElevatedButton(
                        onPressed: _runHelperTest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                        ),
                        child: const Text('Helper測試'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '數據庫狀態',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildStatusCard(),
                  const SizedBox(height: 16),
                  const Text(
                    '測試結果',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildResultCard('直接API測試', _directTestResult),
                  _buildResultCard('Manager測試', _managerTestResult),
                  _buildResultCard('Helper測試', _helperTestResult),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _checkStatus,
        backgroundColor: primaryColor,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
