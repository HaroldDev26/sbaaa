import '../models/competition.dart';
import 'dart:collection';

// 通用比較函數類型定義
typedef CompareFunction<T> = int Function(T a, T b);

/// 冒泡排序算法 - 通用實現
/// [source] 源數據列表
/// [compare] 比較函數，決定排序方式
List<T> bubbleSort<T>(List<T> source, CompareFunction<T> compare) {
  // 如果列表為空或只有一個元素，直接返回
  if (source.length <= 1) {
    return List.from(source);
  }

  // 創建新列表用於排序，不修改原列表
  List<T> result = List.from(source);
  int n = result.length;

  // 冒泡排序實現
  for (int i = 0; i < n - 1; i++) {
    bool swapped = false;
    for (int j = 0; j < n - i - 1; j++) {
      if (compare(result[j], result[j + 1]) > 0) {
        // 交換元素
        T temp = result[j];
        result[j] = result[j + 1];
        result[j + 1] = temp;
        swapped = true;
      }
    }
    // 如果內層循環未發生交換，則數組已排序
    if (!swapped) break;
  }

  return result;
}

/// 快速排序算法 - 通用實現
/// [source] 源數據列表
/// [compare] 比較函數，決定排序方式
List<T> quickSort<T>(List<T> source, CompareFunction<T> compare) {
  // 如果列表為空或只有一個元素，直接返回
  if (source.length <= 1) {
    return List.from(source);
  }

  // 創建新列表用於排序，不修改原列表
  List<T> result = List.from(source);

  // 使用堆棧實現的非遞歸快速排序
  _quickSortIterative(result, 0, result.length - 1, compare);

  return result;
}

// 非遞歸快速排序輔助函數
void _quickSortIterative<T>(
    List<T> arr, int low, int high, CompareFunction<T> compare) {
  // 創建輔助堆棧
  ListQueue<int> stack = ListQueue<int>();

  // 將初始值推入堆棧
  stack.add(low);
  stack.add(high);

  // 直到堆棧為空
  while (stack.isNotEmpty) {
    // 彈出high和low
    high = stack.removeLast();
    low = stack.removeLast();

    // 分區過程
    int pivotIndex = _partition(arr, low, high, compare);

    // 如果左側有元素，則將左側子數組索引放入堆棧
    if (pivotIndex - 1 > low) {
      stack.add(low);
      stack.add(pivotIndex - 1);
    }

    // 如果右側有元素，則將右側子數組索引放入堆棧
    if (pivotIndex + 1 < high) {
      stack.add(pivotIndex + 1);
      stack.add(high);
    }
  }
}

// 快速排序的分區函數
int _partition<T>(List<T> arr, int low, int high, CompareFunction<T> compare) {
  // 選擇最右元素作為基準
  T pivot = arr[high];
  int i = low - 1;

  for (int j = low; j < high; j++) {
    // 如果當前元素小於或等於基準
    if (compare(arr[j], pivot) <= 0) {
      i++;
      // 交換元素
      T temp = arr[i];
      arr[i] = arr[j];
      arr[j] = temp;
    }
  }

  // 將基準放到正確位置
  T temp = arr[i + 1];
  arr[i + 1] = arr[high];
  arr[high] = temp;

  return i + 1;
}

/// 歸併排序算法 - 通用實現
/// [source] 源數據列表
/// [compare] 比較函數，決定排序方式
List<T> mergeSort<T>(List<T> source, CompareFunction<T> compare) {
  // 如果列表為空或只有一個元素，直接返回
  if (source.length <= 1) {
    return List.from(source);
  }

  // 創建新列表用於排序，不修改原列表
  List<T> result = List.from(source);

  // 使用歸併排序的非遞歸實現
  _mergeSortIterative(result, compare);

  return result;
}

// 非遞歸歸併排序實現
void _mergeSortIterative<T>(List<T> arr, CompareFunction<T> compare) {
  int n = arr.length;

  // 對不同大小的子數組進行歸併排序
  for (int size = 1; size < n; size = 2 * size) {
    // 以size為步長選取左側數組起點
    for (int leftStart = 0; leftStart < n - 1; leftStart += 2 * size) {
      // 計算中點和右側終點
      int mid = leftStart + size - 1 < n - 1 ? leftStart + size - 1 : n - 1;
      int rightEnd =
          leftStart + 2 * size - 1 < n - 1 ? leftStart + 2 * size - 1 : n - 1;

      // 合併兩個子數組
      _merge(arr, leftStart, mid, rightEnd, compare);
    }
  }
}

// 合併兩個已排序子數組
void _merge<T>(
    List<T> arr, int left, int mid, int right, CompareFunction<T> compare) {
  int n1 = mid - left + 1;
  int n2 = right - mid;

  // 創建臨時數組
  List<T> leftArr = List<T>.filled(n1, arr[0]);
  List<T> rightArr = List<T>.filled(n2, arr[0]);

  // 複製數據到臨時數組
  for (int i = 0; i < n1; i++) {
    leftArr[i] = arr[left + i];
  }
  for (int i = 0; i < n2; i++) {
    rightArr[i] = arr[mid + 1 + i];
  }

  // 合併臨時數組
  int i = 0, j = 0;
  int k = left;

  while (i < n1 && j < n2) {
    if (compare(leftArr[i], rightArr[j]) <= 0) {
      arr[k] = leftArr[i];
      i++;
    } else {
      arr[k] = rightArr[j];
      j++;
    }
    k++;
  }

  // 複製剩餘元素
  while (i < n1) {
    arr[k] = leftArr[i];
    i++;
    k++;
  }
  while (j < n2) {
    arr[k] = rightArr[j];
    j++;
    k++;
  }
}

/// 插入排序函數 - 通用實現
/// [source] 源數據列表
/// [compare] 比較函數，決定排序方式
List<T> insertionSort<T>(List<T> source, CompareFunction<T> compare) {
  // 如果列表為空或只有一個元素，直接返回
  if (source.length <= 1) {
    return List.from(source);
  }

  // 創建新列表用於排序，不修改原列表
  List<T> result = List.from(source);

  // 插入排序算法實現
  for (int i = 1; i < result.length; i++) {
    T current = result[i];
    int j = i - 1;

    while (j >= 0 && compare(result[j], current) > 0) {
      result[j + 1] = result[j];
      j--;
    }
    result[j + 1] = current;
  }

  return result;
}

// 比賽排序專用函數 - 按開始日期對比賽進行排序
List<CompetitionModel> sortCompetitionsByDate(
    List<CompetitionModel> competitions) {
  return quickSort<CompetitionModel>(competitions, (a, b) {
    // Manual string comparison for dates
    String aDate = a.startDate;
    String bDate = b.startDate;

    // Compare year first
    if (aDate.length >= 4 && bDate.length >= 4) {
      String aYear = aDate.substring(0, 4);
      String bYear = bDate.substring(0, 4);

      if (aYear != bYear) {
        if (aYear.length != bYear.length) {
          return aYear.length < bYear.length ? -1 : 1;
        }

        for (int i = 0; i < aYear.length; i++) {
          int aDigit = aYear.codeUnitAt(i);
          int bDigit = bYear.codeUnitAt(i);

          if (aDigit != bDigit) {
            return aDigit < bDigit ? -1 : 1;
          }
        }
      }
    }

    // Compare full date strings
    int minLength;
    if (aDate.length < bDate.length) {
      minLength = aDate.length;
    } else {
      minLength = bDate.length;
    }

    for (int i = 0; i < minLength; i++) {
      int aChar = aDate.codeUnitAt(i);
      int bChar = bDate.codeUnitAt(i);

      if (aChar != bChar) {
        return aChar < bChar ? -1 : 1;
      }
    }

    // If all characters matched but strings have different lengths
    if (aDate.length != bDate.length) {
      return aDate.length < bDate.length ? -1 : 1;
    }

    return 0; // Dates are identical
  });
}

// 比賽排序專用函數 - 按名稱字母排序（A-Z）
List<CompetitionModel> sortCompetitionsByName(
    List<CompetitionModel> competitions) {
  return quickSort<CompetitionModel>(competitions, (a, b) {
    String aName = a.name.toLowerCase();
    String bName = b.name.toLowerCase();

    int minLength;
    if (aName.length < bName.length) {
      minLength = aName.length;
    } else {
      minLength = bName.length;
    }

    for (int i = 0; i < minLength; i++) {
      int aChar = aName.codeUnitAt(i);
      int bChar = bName.codeUnitAt(i);

      if (aChar != bChar) {
        return aChar < bChar ? -1 : 1;
      }
    }

    // If all characters matched but strings have different lengths
    if (aName.length != bName.length) {
      return aName.length < bName.length ? -1 : 1;
    }

    return 0; // Names are identical
  });
}

// 按英文字母（A-Z）排序通用實現
List<Map<String, dynamic>> sortByAlphabet(
    List<Map<String, dynamic>> source, String field) {
  // 檢查來源是否為空
  if (source.isEmpty) return [];

  // 使用快速排序進行排序
  return quickSort(source, (a, b) {
    String aValue;
    if (a[field] != null) {
      aValue = a[field].toString().toLowerCase();
    } else {
      aValue = '';
    }

    String bValue;
    if (b[field] != null) {
      bValue = b[field].toString().toLowerCase();
    } else {
      bValue = '';
    }

    // Traditional string comparison
    int minLength;
    if (aValue.length < bValue.length) {
      minLength = aValue.length;
    } else {
      minLength = bValue.length;
    }

    for (int i = 0; i < minLength; i++) {
      int aChar = aValue.codeUnitAt(i);
      int bChar = bValue.codeUnitAt(i);

      if (aChar < bChar) {
        return -1;
      } else if (aChar > bChar) {
        return 1;
      }
    }

    // If all characters matched but strings have different lengths
    if (aValue.length < bValue.length) {
      return -1;
    } else if (aValue.length > bValue.length) {
      return 1;
    }

    // Both strings are identical
    return 0;
  });
}

// 按成績數字大小排序（如田徑成績）
List<Map<String, dynamic>> sortByScore(
    List<Map<String, dynamic>> source, String scoreField,
    {bool ascending = false}) {
  // 檢查來源是否為空
  if (source.isEmpty) return [];

  // 使用快速排序進行排序
  return quickSort(source, (a, b) {
    // 嘗試獲取並轉換得分
    double aScore;
    if (a[scoreField] is num) {
      aScore = (a[scoreField] as num).toDouble();
    } else if (a[scoreField] is String &&
        (a[scoreField] as String).isNotEmpty) {
      try {
        aScore = double.parse(a[scoreField]);
      } catch (e) {
        aScore = 0.0;
      }
    } else {
      aScore = 0.0;
    }

    double bScore;
    if (b[scoreField] is num) {
      bScore = (b[scoreField] as num).toDouble();
    } else if (b[scoreField] is String &&
        (b[scoreField] as String).isNotEmpty) {
      try {
        bScore = double.parse(b[scoreField]);
      } catch (e) {
        bScore = 0.0;
      }
    } else {
      bScore = 0.0;
    }

    // 根據升序/降序進行比較
    if (ascending) {
      if (aScore < bScore) {
        return -1;
      } else if (aScore > bScore) {
        return 1;
      } else {
        return 0;
      }
    } else {
      if (bScore < aScore) {
        return -1;
      } else if (bScore > aScore) {
        return 1;
      } else {
        return 0;
      }
    }
  });
}

// 按項目類型進行排序（徑賽、田賽、接力等）
List<Map<String, dynamic>> sortByEventType(List<Map<String, dynamic>> source) {
  // 檢查來源是否為空
  if (source.isEmpty) return [];

  // 定義項目類型順序
  const typeOrder = {
    '徑賽': 1,
    '田賽': 2,
    '接力': 3,
  };

  // 使用冒泡排序進行排序
  return bubbleSort(source, (a, b) {
    // 先按照項目類型排序
    String aType;
    if (a['eventType'] != null) {
      aType = a['eventType'].toString();
    } else {
      aType = '';
    }

    String bType;
    if (b['eventType'] != null) {
      bType = b['eventType'].toString();
    } else {
      bType = '';
    }

    int aOrder;
    if (typeOrder.containsKey(aType)) {
      aOrder = typeOrder[aType]!;
    } else {
      aOrder = 999;
    }

    int bOrder;
    if (typeOrder.containsKey(bType)) {
      bOrder = typeOrder[bType]!;
    } else {
      bOrder = 999;
    }

    if (aOrder != bOrder) {
      if (aOrder < bOrder) {
        return -1;
      } else {
        return 1;
      }
    }

    // 類型相同，再按照項目名稱排序
    String aName;
    if (a['eventName'] != null) {
      aName = a['eventName'].toString();
    } else {
      aName = '';
    }

    String bName;
    if (b['eventName'] != null) {
      bName = b['eventName'].toString();
    } else {
      bName = '';
    }

    // 如果項目名稱以數字開始，按數字排序
    final aMatch = RegExp(r'^\d+').firstMatch(aName);
    final bMatch = RegExp(r'^\d+').firstMatch(bName);

    if (aMatch != null && bMatch != null) {
      int aNum;
      if (aMatch.group(0) != null) {
        aNum = int.parse(aMatch.group(0)!);
      } else {
        aNum = 0;
      }

      int bNum;
      if (bMatch.group(0) != null) {
        bNum = int.parse(bMatch.group(0)!);
      } else {
        bNum = 0;
      }

      if (aNum < bNum) {
        return -1;
      } else if (aNum > bNum) {
        return 1;
      } else {
        return 0;
      }
    } else if (aMatch != null) {
      return -1; // 數字優先於字母
    } else if (bMatch != null) {
      return 1;
    }

    // 否則按字母順序排序
    // Traditional string comparison for names
    String aNameLower = aName.toLowerCase();
    String bNameLower = bName.toLowerCase();

    int minLength;
    if (aNameLower.length < bNameLower.length) {
      minLength = aNameLower.length;
    } else {
      minLength = bNameLower.length;
    }

    for (int i = 0; i < minLength; i++) {
      int aChar = aNameLower.codeUnitAt(i);
      int bChar = bNameLower.codeUnitAt(i);

      if (aChar < bChar) {
        return -1;
      } else if (aChar > bChar) {
        return 1;
      }
    }

    // If all characters matched but strings have different lengths
    if (aNameLower.length < bNameLower.length) {
      return -1;
    } else if (aNameLower.length > bNameLower.length) {
      return 1;
    }

    return 0; // Names are identical
  });
}

// 按年齡組別排序
List<Map<String, dynamic>> sortByAgeGroup(List<Map<String, dynamic>> source) {
  // 檢查來源是否為空
  if (source.isEmpty) return [];

  // 年齡組別處理函數：提取數字部分
  int extractAge(String ageGroup) {
    final match = RegExp(r'\d+').firstMatch(ageGroup);
    if (match != null) {
      return int.parse(match.group(0) ?? '0');
    }
    return 0;
  }

  // 使用歸併排序進行排序
  return mergeSort(source, (a, b) {
    final aAgeGroup = a['ageGroup']?.toString() ?? '';
    final bAgeGroup = b['ageGroup']?.toString() ?? '';

    int aAge = extractAge(aAgeGroup);
    int bAge = extractAge(bAgeGroup);

    if (aAge < bAge) {
      return -1;
    } else if (aAge > bAge) {
      return 1;
    } else {
      return 0;
    }
  });
}

// 按學校或團隊分數排序積分榜
List<Map<String, dynamic>> sortByTeamScore(List<Map<String, dynamic>> source,
    {bool ascending = false}) {
  // 檢查來源是否為空
  if (source.isEmpty) return [];

  // 使用快速排序進行排序
  return quickSort(source, (a, b) {
    // 取得總分數據
    num aScore;
    if (a['totalScore'] != null) {
      aScore = a['totalScore'] as num;
    } else {
      aScore = 0;
    }

    num bScore;
    if (b['totalScore'] != null) {
      bScore = b['totalScore'] as num;
    } else {
      bScore = 0;
    }

    // 使用傳統比較方法
    if (ascending) {
      // 升序排列（小的在前）
      if (aScore < bScore) return -1;
      if (aScore > bScore) return 1;
      return 0; // 相等
    } else {
      // 降序排列（大的在前）
      if (aScore > bScore) return -1;
      if (aScore < bScore) return 1;
      return 0; // 相等
    }
  });
}

// 按運動員/學校名稱排序（A-Z）
List<Map<String, dynamic>> sortByName(List<Map<String, dynamic>> source) {
  return sortByAlphabet(source, 'name');
}

// 按學校名稱排序（A-Z）
List<Map<String, dynamic>> sortBySchool(List<Map<String, dynamic>> source) {
  return sortByAlphabet(source, 'school');
}
