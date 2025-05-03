# 全局數據管理器整合文檔

## 概述

本文檔記錄了全局數據管理器 (`GlobalDataManager`) 的整合過程，該管理器用於集中管理應用程序中的比賽數據和成績記錄。全局數據管理器解決了之前直接訪問 Firestore 的碎片化問題，提高了代碼的可維護性和一致性。

## 已完成的整合工作

### 1. `lib/screens/result/event_result_screen.dart` 文件整合

我們對 `event_result_screen.dart` 文件進行了以下修改，以使用全局數據管理器：

#### 基本整合：
- 引入了 `GlobalDataManager` 類並創建了實例
- 將直接操作 Firestore 的代碼替換為使用 `GlobalDataManager` 的方法

#### 功能增強：
- 添加了田賽成績編輯對話框 `_showEditFieldResultDialog`
- 實現了田賽成績排序方法 `_sortAndRankAthletesByFieldResult`
- 改進了 `_sortAndRankAthletes` 方法，使其能自動檢測並根據比賽類型正確排序

#### 用戶體驗優化：
- 修正了時間和田賽成績的格式化顯示
- 根據比賽類型（田賽/徑賽）自動選擇合適的編輯對話框和排序邏輯

### 2. `lib/screens/result/field_event_record_screen.dart` 文件整合

我們對 `field_event_record_screen.dart` 文件進行了以下修改：

#### 基本整合：
- 確保使用 `GlobalDataManager` 實例處理所有數據操作
- 將 `_loadAthletes` 方法修改為使用 `_dataManager.getEventParticipants()`
- 添加了 `getEventParticipants` 方法到 `GlobalDataManager` 類中，使其能與 `field_event_record_screen.dart` 無縫整合

#### 已整合的方法：
- `_loadAthletes` - 使用 `_dataManager.getEventParticipants()`
- `_loadSavedResults` - 使用 `_dataManager.loadFieldEventResults()`
- `_handleAttemptInput` - 使用 `_dataManager.recordFieldEventResult()`
- `_saveResults` - 使用 `_dataManager.saveFieldEventResults()`
- `_calculateRanksAndNavigate` - 使用 `_dataManager.getFieldEventRanking()` 和 `_dataManager.saveEventResults()`
- `_getRankedAthletes` - 使用 `_dataManager.getFieldEventRanking()`

### 代碼變更摘要

```dart
// 引入全局數據管理器
import '../../data/global_data_manager.dart';

class _EventResultScreenState extends State<EventResultScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalDataManager _dataManager = GlobalDataManager(); // 初始化全局數據管理器
  
  // ...
  
  // 使用全局數據管理器更新結果
  Future<void> _updateResultInFirestore() async {
    // ...
    try {
      await _dataManager.saveEventResults(
        competitionId: widget.competitionId,
        eventName: widget.eventName,
        rankedResults: _rankedAthletes,
      );
      // ...
    } catch (e) {
      // ...
    }
  }
}
```

### GlobalDataManager 類擴展

為支持 `field_event_record_screen.dart` 的完全整合，我們在 `GlobalDataManager` 類中添加了以下方法：

```dart
/// 獲取項目參賽者
Future<List<Map<String, dynamic>>> getEventParticipants({
  required String competitionId,
  required String eventName,
}) async {
  try {
    // 使用CompetitionData類的方法獲取參賽者
    return await CompetitionData.getEventParticipants(
      competitionId: competitionId,
      eventName: eventName,
    );
  } catch (e) {
    print('獲取項目參賽者失敗: $e');
    return [];
  }
}
```

## 技術細節

### 田賽/徑賽自動檢測

我們添加了一個檢測機制來判斷當前事件是田賽還是徑賽：

```dart
final bool isFieldEvent = widget.eventName.contains('跳遠') ||
    widget.eventName.contains('跳高') ||
    widget.eventName.contains('鉛球') ||
    widget.eventName.contains('鐵餅') ||
    widget.eventName.contains('標槍');
```

### 不同的排序邏輯

- 徑賽：時間越短越好（升序排列）
- 田賽：距離/高度越大越好（降序排列）

### 數據格式

- 徑賽：時間以 "MM:SS.CC" 格式顯示（分:秒.百分秒）
- 田賽：成績以 "XX.XXm" 格式顯示（米）

## 後續工作

- 完成其他相關頁面的全局數據管理器整合
- 添加單元測試確保功能正確性
- 考慮添加數據緩存機制提高性能
- 考慮添加離線支持

## 注意事項

- 使用 `GlobalDataManager` 時需要傳入正確的參數，特別是 `competitionId` 和 `eventName`
- 對於田賽和徑賽，需要使用不同的數據結構和排序邏輯
- 確保在保存成績前正確設置了排名 