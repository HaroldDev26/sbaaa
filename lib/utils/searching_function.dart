import '../models/competition.dart';

// 篩選版本的線性搜索 - 返回所有匹配項，使用純Isearch風格
List<CompetitionModel> linearSearch(
    List<CompetitionModel> source, String query, String filter) {
  // 特殊情況：都為空或全部，直接返回全部
  if (query.isEmpty && filter == '全部') {
    return List.from(source);
  }

  // 創建結果列表
  List<CompetitionModel> results = [];

  // 將查詢詞轉為小寫
  String lowerQuery = query.toLowerCase();

  // 循環遍歷源列表
  int i = 0;
  while (i < source.length) {
    final competition = source[i];

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

// 用於處理Map類型比賽數據的線性搜尋函數
List<Map<String, dynamic>> linearSearchMap(
    List<Map<String, dynamic>> source, String query, String filter) {
  // 特殊情況：都為空或全部，直接返回全部
  if (query.isEmpty && filter == '全部') {
    return List.from(source);
  }

  // 創建結果列表
  List<Map<String, dynamic>> results = [];

  // 將查詢詞轉為小寫
  String lowerQuery = query.toLowerCase();

  // 循環遍歷源列表
  for (int i = 0; i < source.length; i++) {
    final competition = source[i];
    final name = competition['name']?.toString().toLowerCase() ?? '';
    final venue = competition['venue']?.toString().toLowerCase() ?? '';
    final date = competition['date']?.toString().toLowerCase() ?? '';
    final description =
        competition['description']?.toString().toLowerCase() ?? '';
    final status = competition['status']?.toString() ?? '';

    // 先檢查狀態是否匹配
    if (filter == '全部' || status == filter) {
      // 再檢查名稱、場地、日期或描述是否匹配
      if (query.isEmpty ||
          name.contains(lowerQuery) ||
          venue.contains(lowerQuery) ||
          date.contains(lowerQuery) ||
          description.contains(lowerQuery)) {
        results.add(competition);
      }
    }
  }

  return results;
}
