import '../models/competition.dart';
import 'dart:collection';

bool _isSorted<T>(List<T> source, String field, {bool descending = false}) {
  if (source.length <= 1) return true;

  if (source.first is! Map) return false;

  for (int i = 0; i < source.length - 1; i++) {
    dynamic current = (source[i] as Map)[field];
    dynamic next = (source[i + 1] as Map)[field];

    if (current is String && next is String) {
      int comparison;
      String currentLower = current.toLowerCase();
      String nextLower = next.toLowerCase();

      int minLength;
      if (currentLower.length < nextLower.length) {
        minLength = currentLower.length;
      } else {
        minLength = nextLower.length;
      }
      comparison = 0;

      for (int i = 0; i < minLength; i++) {
        int currentChar = currentLower.codeUnitAt(i);
        int nextChar = nextLower.codeUnitAt(i);

        if (currentChar != nextChar) {
          if (currentChar < nextChar) {
            comparison = -1;
          } else {
            comparison = 1;
          }
          break;
        }
      }

      if (comparison == 0 && currentLower.length != nextLower.length) {
        if (currentLower.length < nextLower.length) {
          comparison = -1;
        } else {
          comparison = 1;
        }
      }

      if ((descending && comparison < 0) || (!descending && comparison > 0)) {
        return false;
      }
    } else if ((current is num || current == null) &&
        (next is num || next == null)) {
      if (current == null) {
        current = 0;
      }
      if (next == null) {
        next = 0;
      }
      if ((descending && current < next) || (!descending && current > next)) {
        return false;
      }
    } else {
      return false;
    }
  }
  return true;
}

List<Map<String, dynamic>> binarySearch(
    List<Map<String, dynamic>> source, String query, String field,
    {int Function(String, dynamic)? compareFunction}) {
  if (source.isEmpty || query.isEmpty) return [];

  compareFunction ??= (q, value) {
    if (value == null) return 1;
    String strValue = value.toString().toLowerCase();
    String lowerQuery = q.toLowerCase();

    if (strValue.contains(lowerQuery)) {
      return 0;
    } else {
      int minLength;
      if (strValue.length < lowerQuery.length) {
        minLength = strValue.length;
      } else {
        minLength = lowerQuery.length;
      }

      for (int i = 0; i < minLength; i++) {
        int strChar = strValue.codeUnitAt(i);
        int queryChar = lowerQuery.codeUnitAt(i);

        if (strChar < queryChar) {
          return -1;
        } else if (strChar > queryChar) {
          return 1;
        }
      }

      if (strValue.length < lowerQuery.length) {
        return -1;
      } else if (strValue.length > lowerQuery.length) {
        return 1;
      } else {
        return 0;
      }
    }
  };

  Queue<Map<String, dynamic>> results = Queue<Map<String, dynamic>>();

  ListQueue<List<int>> rangeStack = ListQueue<List<int>>();
  rangeStack.add([0, source.length - 1]);

  while (rangeStack.isNotEmpty) {
    List<int> range = rangeStack.removeLast();
    int low = range[0];
    int high = range[1];

    while (low <= high) {
      int mid = low + ((high - low) ~/ 2);
      dynamic value = source[mid][field];
      int compResult = compareFunction(query, value);

      if (compResult == 0) {
        results.add(source[mid]);

        int left = mid - 1;
        int right = mid + 1;

        if (left >= low) {
          rangeStack.add([low, left]);
        }

        if (right <= high) {
          rangeStack.add([right, high]);
        }

        break;
      } else if (compResult < 0) {
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
  }
  return results.toList();
}

List<CompetitionModel> searchCompetitions(
    List<CompetitionModel> source, String query, String filter) {
  if (source.isEmpty) return [];

  if (query.isEmpty && (filter.isEmpty || filter == '全部')) {
    return List.from(source);
  }

  final results = <CompetitionModel>[];

  final String lowerQuery = query.toLowerCase();
  final bool hasQueryFilter = query.isNotEmpty;
  final bool hasStatusFilter = filter.isNotEmpty && filter != '全部';

  for (int i = 0; i < source.length; i++) {
    final competition = source[i];

    if (hasStatusFilter && competition.status != filter) {
      continue;
    }

    if (hasQueryFilter) {
      final name = competition.name.toLowerCase();
      final description = competition.description.toLowerCase();

      String venue;
      if (competition.venue != null) {
        venue = competition.venue!.toLowerCase();
      } else {
        venue = '';
      }

      final dates =
          '${competition.startDate} ${competition.endDate}'.toLowerCase();

      if (name.contains(lowerQuery) ||
          description.contains(lowerQuery) ||
          venue.contains(lowerQuery) ||
          dates.contains(lowerQuery)) {
        results.add(competition);
      }

      continue;
    }

    results.add(competition);
  }

  return results;
}

List<Map<String, dynamic>> searchAthletes(List<Map<String, dynamic>> source,
    String query, Map<String, String> filters,
    {bool? isSorted, String sortField = 'name'}) {
  if (source.isEmpty) return [];

  if (query.isEmpty &&
      (filters.isEmpty ||
          filters.values.every((v) => v.isEmpty || v == '全部'))) {
    return List.from(source);
  }

  bool useBinarySearch;
  if (isSorted != null) {
    useBinarySearch = isSorted && query.isNotEmpty && filters.isEmpty;
  } else {
    useBinarySearch =
        _isSorted(source, sortField) && query.isNotEmpty && filters.isEmpty;
  }

  if (useBinarySearch) {
    return binarySearch(source, query, sortField);
  }

  final results = <Map<String, dynamic>>[];

  final String lowerQuery = query.toLowerCase();
  final bool hasQueryFilter = query.isNotEmpty;

  for (int i = 0; i < source.length; i++) {
    final athlete = source[i];
    bool matchesFilters = true;

    if (filters.isNotEmpty) {
      for (final filterEntry in filters.entries) {
        final filterKey = filterEntry.key;
        final filterValue = filterEntry.value;

        if (filterValue.isEmpty || filterValue == '全部') continue;

        String? athleteValue;

        if (athlete.containsKey(filterKey)) {
          athleteValue = athlete[filterKey]?.toString();
        } else if (filterKey == 'gender' && athlete.containsKey('userGender')) {
          athleteValue = athlete['userGender']?.toString();
        } else if (filterKey == 'name' && athlete.containsKey('userName')) {
          athleteValue = athlete['userName']?.toString();
        } else if (filterKey == 'ageGroup' &&
            athlete.containsKey('userAgeGroup')) {
          athleteValue = athlete['userAgeGroup']?.toString();
        } else if (filterKey == 'school' && athlete.containsKey('userSchool')) {
          athleteValue = athlete['userSchool']?.toString();
        }

        if (athleteValue == null || athleteValue != filterValue) {
          matchesFilters = false;
          break;
        }
      }

      if (!matchesFilters) continue;
    }

    if (hasQueryFilter) {
      String name = '';
      if (athlete['name'] != null) {
        name = athlete['name'].toString().toLowerCase();
      } else if (athlete['userName'] != null) {
        name = athlete['userName'].toString().toLowerCase();
      }

      if (name.contains(lowerQuery)) {
        results.add(athlete);
        continue;
      }

      String athleteNumber = '';
      if (athlete['athleteNumber'] != null) {
        athleteNumber = athlete['athleteNumber'].toString().toLowerCase();
      }

      if (athleteNumber.contains(lowerQuery)) {
        results.add(athlete);
        continue;
      }

      String school = '';
      if (athlete['school'] != null) {
        school = athlete['school'].toString().toLowerCase();
      } else if (athlete['userSchool'] != null) {
        school = athlete['userSchool'].toString().toLowerCase();
      }

      if (school.contains(lowerQuery)) {
        results.add(athlete);
        continue;
      }

      final events = athlete['events'];
      if (events is List && events.isNotEmpty) {
        bool matchesEvent = false;
        for (final event in events) {
          if (event.toString().toLowerCase().contains(lowerQuery)) {
            matchesEvent = true;
            break;
          }
        }

        if (matchesEvent) {
          results.add(athlete);
          continue;
        }
      }

      bool foundInOtherFields = false;
      for (final entry in athlete.entries) {
        if ([
              'name',
              'userName',
              'athleteNumber',
              'school',
              'userSchool',
              'class',
              'userClass',
              'events'
            ].contains(entry.key) ||
            entry.value is Map ||
            entry.value is List) {
          continue;
        }

        if (entry.value != null &&
            entry.value.toString().toLowerCase().contains(lowerQuery)) {
          foundInOtherFields = true;
          break;
        }
      }

      if (foundInOtherFields) {
        results.add(athlete);
      }
    } else {
      results.add(athlete);
    }
  }

  return results;
}

/// 專用於搜索比賽項目的函數 - 支持二分查找優化
/// [source] 源項目數據列表
/// [query] 搜索關鍵詞
/// [filters] 過濾條件，如項目類型、性別要求等
/// [isSorted] 指定數據是否已按特定字段排序
/// [sortField] 數據排序的字段名，用於二分查找
/// 返回所有匹配的項目
List<Map<String, dynamic>> searchEvents(List<Map<String, dynamic>> source,
    String query, Map<String, dynamic> filters,
    {bool? isSorted, String sortField = 'name'}) {
  // 快速路徑：源為空，直接返回空列表
  if (source.isEmpty) return [];

  // 快速路徑：無查詢和過濾條件
  if (query.isEmpty &&
      (filters.isEmpty ||
          filters.values.every((v) => v.isEmpty || v == '全部'))) {
    return List.from(source);
  }

  bool useBinarySearch;
  if (isSorted != null) {
    useBinarySearch = isSorted && query.isNotEmpty && filters.isEmpty;
  } else {
    useBinarySearch =
        _isSorted(source, sortField) && query.isNotEmpty && filters.isEmpty;
  }

  if (useBinarySearch) {
    return binarySearch(source, query, sortField);
  }

  Queue<Map<String, dynamic>> resultsQueue = Queue<Map<String, dynamic>>();

  final String lowerQuery = query.toLowerCase();
  final bool hasQueryFilter = query.isNotEmpty;
  final bool hasCategoryFilter = filters.isNotEmpty &&
      filters.values.any((v) => v.isNotEmpty && v != '全部');

  for (int i = 0; i < source.length; i++) {
    final event = source[i];

    if (hasCategoryFilter) {
      String eventCategory = '';
      if (event['eventType'] != null) {
        eventCategory = event['eventType'].toString();
      } else if (event['category'] != null) {
        eventCategory = event['category'].toString();
      } else if (event['type'] != null) {
        eventCategory = event['type'].toString();
      }

      // 檢查項目名稱中是否包含接力關鍵詞，並設置為接力類型
      if (eventCategory.isEmpty && event['eventName'] != null) {
        String eventName = event['eventName'].toString().toLowerCase();
        if (eventName.contains('接力賽')) {
          eventCategory = '接力';
        }
      }

      String categoryFilter = '';
      if (filters['eventType'] != null) {
        categoryFilter = filters['eventType'].toString();
      } else if (filters['category'] != null) {
        categoryFilter = filters['category'].toString();
      }

      // 打印過濾條件和項目類型，用於調試
      print(
          '過濾: $categoryFilter, 項目: ${event['eventName']}, 類型: $eventCategory');

      if (eventCategory != categoryFilter) {
        continue;
      }
    }

    if (hasQueryFilter) {
      String name = '';
      if (event['name'] != null) {
        name = event['name'].toString().toLowerCase();
      }

      if (name.contains(lowerQuery)) {
        resultsQueue.add(event);
        continue;
      }

      String description = '';
      if (event['description'] != null) {
        description = event['description'].toString().toLowerCase();
      }

      if (description.contains(lowerQuery)) {
        resultsQueue.add(event);
        continue;
      }

      String rules = '';
      if (event['rules'] != null) {
        rules = event['rules'].toString().toLowerCase();
      }

      if (rules.contains(lowerQuery)) {
        resultsQueue.add(event);
        continue;
      }
    } else {
      // 無關鍵詞過濾，但符合所有過濾條件
      resultsQueue.add(event);
    }
  }

  return resultsQueue.toList();
}

/// 優化後的搜索函數 - 支持已排序數據的二分查找
/// [source] 要搜索的數據列表
/// [query] 搜索關鍵詞
/// [filter] 過濾條件（如狀態）
/// [isSorted] 指定數據是否已按特定字段排序
/// [sortField] 數據排序的字段名，用於二分查找
/// 返回匹配的數據項列表
List<Map<String, dynamic>> linearSearchMap(
    List<Map<String, dynamic>> source, String query, String filter,
    {bool? isSorted, String sortField = 'name'}) {
  // 快速路徑：源列表為空
  if (source.isEmpty) {
    return [];
  }

  // 快速路徑：沒有查詢條件時返回整個列表
  if (query.isEmpty && (filter.isEmpty || filter == '全部')) {
    return List.from(source);
  }

  // 檢查是否可以使用二分查找（需要有查詢詞、無過濾條件且數據已排序）
  bool useBinarySearch;
  if (isSorted != null) {
    useBinarySearch =
        isSorted && query.isNotEmpty && (filter.isEmpty || filter == '全部');
  } else {
    useBinarySearch = _isSorted(source, sortField) &&
        query.isNotEmpty &&
        (filter.isEmpty || filter == '全部');
  }

  // 如果條件適合，使用二分查找
  if (useBinarySearch) {
    return binarySearch(source, query, sortField);
  }

  // 創建隊列用於保存結果
  Queue<Map<String, dynamic>> resultsQueue = Queue<Map<String, dynamic>>();

  // 準備查詢參數
  final String lowerQuery = query.toLowerCase();
  final bool hasQueryFilter = query.isNotEmpty;
  final bool hasStatusFilter = filter.isNotEmpty && filter != '全部';

  // 使用堆棧實現搜索（示範目的，這裡使用堆棧處理數據）
  ListQueue<Map<String, dynamic>> stack = ListQueue<Map<String, dynamic>>();
  for (var item in source.reversed) {
    stack.add(item);
  }

  // 從堆棧中取出項目進行檢查
  while (stack.isNotEmpty) {
    final item = stack.removeLast();
    bool matched = false;

    // 先檢查狀態條件（如果有）
    if (hasStatusFilter && item['status'] != filter) {
      continue; // 狀態不匹配，跳過
    }

    // 如果沒有搜索查詢，只有過濾條件，則所有通過過濾的項目都匹配
    if (!hasQueryFilter) {
      resultsQueue.add(item);
      continue;
    }

    // 檢查是否匹配查詢詞 - 按可能性高低順序檢查各個字段
    // 1. 名稱/標題 (最常匹配)
    if (item.containsKey('name') &&
        item['name'] != null &&
        item['name'].toString().toLowerCase().contains(lowerQuery)) {
      matched = true;
    }
    // 2. 描述
    else if (item.containsKey('description') &&
        item['description'] != null &&
        item['description'].toString().toLowerCase().contains(lowerQuery)) {
      matched = true;
    }
    // 3. 地點
    else if (item.containsKey('venue') &&
        item['venue'] != null &&
        item['venue'].toString().toLowerCase().contains(lowerQuery)) {
      matched = true;
    }
    // 4. 日期
    else if ((item.containsKey('startDate') &&
            item['startDate'] != null &&
            item['startDate'].toString().toLowerCase().contains(lowerQuery)) ||
        (item.containsKey('endDate') &&
            item['endDate'] != null &&
            item['endDate'].toString().toLowerCase().contains(lowerQuery)) ||
        (item.containsKey('date') &&
            item['date'] != null &&
            item['date'].toString().toLowerCase().contains(lowerQuery))) {
      matched = true;
    }
    // 5. 用戶名
    else if (item.containsKey('userName') &&
        item['userName'] != null &&
        item['userName'].toString().toLowerCase().contains(lowerQuery)) {
      matched = true;
    }
    // 6. 學校
    else if (item.containsKey('school') &&
        item['school'] != null &&
        item['school'].toString().toLowerCase().contains(lowerQuery)) {
      matched = true;
    }
    // 7. 選手編號
    else if (item.containsKey('athleteNumber') &&
        item['athleteNumber'] != null &&
        item['athleteNumber'].toString().toLowerCase().contains(lowerQuery)) {
      matched = true;
    }

    // 如果任何欄位匹配，添加到結果中
    if (matched) {
      resultsQueue.add(item);
    }
  }

  return resultsQueue.toList();
}

bool isListSorted<T>(List<T> list, {String? field, bool descending = false}) {
  String fieldToUse;
  if (field != null) {
    fieldToUse = field;
  } else {
    fieldToUse = 'name';
  }

  return _isSorted(list, fieldToUse, descending: descending);
}
