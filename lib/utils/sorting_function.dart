import '../models/competition.dart';

// 插入排序函數 - 按開始日期對比賽進行排序
List<CompetitionModel> insertionSort(List<CompetitionModel> source) {
  // 如果列表為空或只有一個元素，直接返回
  if (source.length <= 1) {
    return List.from(source);
  }

  // 創建新列表用於排序，不修改原列表
  List<CompetitionModel> result = List.from(source);

  // 插入排序算法實現
  int i = 1;
  while (i < result.length) {
    // 當前元素
    CompetitionModel current = result[i];
    // 前一個位置索引
    int j = i - 1;

    // 將當前元素與已排序部分比較並插入到正確位置
    while (j >= 0 && result[j].startDate.compareTo(current.startDate) > 0) {
      // 將較大的元素向後移動一位
      result[j + 1] = result[j];
      j = j - 1;
    }
    // 在正確位置插入當前元素
    result[j + 1] = current;

    i = i + 1;
  }

  return result;
}
