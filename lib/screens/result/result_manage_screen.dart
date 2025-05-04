import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/searching_function.dart';
import 'event_result_screen.dart';
import '../../data/global_data_manager.dart';

class ResultManageScreen extends StatefulWidget {
  final String competitionId;
  final String competitionName;
  const ResultManageScreen({
    Key? key,
    required this.competitionId,
    required this.competitionName,
  }) : super(key: key);

  @override
  State<ResultManageScreen> createState() => _ResultManageScreenState();
}

class _ResultManageScreenState extends State<ResultManageScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalDataManager _dataManager = GlobalDataManager();
  List<Map<String, dynamic>> _allResults = [];
  List<Map<String, dynamic>> _filteredResults = [];
  String _searchText = '';
  String _selectedType = '全部';
  final List<String> _eventTypes = ['全部', '徑賽', '田賽', '接力'];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _migrateAndLoadResults();
  }

  Future<void> _migrateAndLoadResults() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final migratedCount =
          await _dataManager.migrateFieldResults(widget.competitionId);

      if (migratedCount > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已成功遷移 $migratedCount 項田賽結果到統一結果系統'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      await _loadResults();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('數據遷移發生錯誤: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      await _loadResults();
    }
  }

  Future<void> _loadResults() async {
    try {
      final snapshot = await _firestore
          .collection('competitions')
          .doc(widget.competitionId)
          .collection('final_results')
          .get();
      final results = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      setState(() {
        _allResults = results;
        _filteredResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入成績失敗: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _filterResults() {
    setState(() {
      Map<String, dynamic> filters = {};
      if (_selectedType != '全部') {
        filters['category'] = _selectedType;
      }

      _filteredResults = searchEvents(
        _allResults,
        _searchText.toLowerCase(),
        filters,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.competitionName} - 成績管理'),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 搜尋與篩選
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      // 搜尋框
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: '搜尋項目名稱...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            _searchText = value;
                            _filterResults();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 篩選下拉選單
                      DropdownButton<String>(
                        value: _selectedType,
                        items: _eventTypes
                            .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            _selectedType = value;
                            _filterResults();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // 成績列表
                Expanded(
                  child: _filteredResults.isEmpty
                      ? const Center(child: Text('沒有成績資料'))
                      : ListView.builder(
                          itemCount: _filteredResults.length,
                          itemBuilder: (context, index) {
                            final result = _filteredResults[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: ListTile(
                                title: Text(result['eventName'] ?? '未知項目'),
                                subtitle: Text(result['eventType'] ?? ''),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EventResultScreen(
                                        competitionId: widget.competitionId,
                                        competitionName: widget.competitionName,
                                        eventName: result['eventName'] ?? '',
                                        eventResults: result,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
