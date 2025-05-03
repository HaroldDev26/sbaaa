# 全局數據管理器(GlobalDataManager)報告

## 概述
為了確保在整個應用程序中保持比賽數據的一致性和準確性，我們實現了`GlobalDataManager`類。這是一個集中式數據管理解決方案，負責處理所有與比賽相關的數據操作，包括徑賽、田賽和接力賽的成績記錄和排名計算。

## 實現原理
`GlobalDataManager`採用單例模式，確保整個應用程序中只有一個實例在運行，從而避免數據不一致的問題。它通過維護多個內存緩存來提高性能，同時確保數據的同步和持久化。

## 數據結構
`GlobalDataManager`使用以下關鍵數據結構：

1. **比賽數據緩存**
   ```dart
   Map<String, dynamic> _competitionCache = {};
   ```
   用於存儲比賽的一般信息。

2. **計時數據緩存**
   ```dart
   Map<String, Map<String, Map<String, int>>> _timingCache = {};
   ```
   三層嵌套映射：比賽ID -> 項目名稱 -> 運動員ID -> 時間(厘秒)

3. **田賽成績緩存**
   ```dart
   Map<String, Map<String, Map<String, List<double>>>> _fieldEventCache = {};
   ```
   三層嵌套映射加列表：比賽ID -> 項目名稱 -> 運動員ID -> 嘗試成績列表

## 核心功能

### 緩存管理
1. **初始化緩存**
   ```dart
   void initCompetitionCache(String competitionId)
   ```
   為指定比賽初始化所有相關緩存。

2. **清除緩存**
   ```dart
   void clearCompetitionCache(String competitionId)
   ```
   清除特定比賽的所有緩存數據。

### 成績記錄
1. **記錄徑賽成績**
   ```dart
   Future<void> recordTrackEventTime({
     required String competitionId,
     required String eventName,
     required String athleteId,
     required int timeInCentiseconds,
   })
   ```
   記錄個人徑賽的成績（以厘秒為單位）。

2. **記錄接力賽成績**
   ```dart
   Future<void> recordRelayEventTime({
     required String competitionId,
     required String eventName,
     required String teamId,
     required int timeInCentiseconds,
     List<int>? legTimes,
   })
   ```
   記錄接力隊伍的總時間和各棒交接時間。

3. **記錄田賽成績**
   ```dart
   Future<void> recordFieldEventResult({
     required String competitionId,
     required String eventName,
     required String athleteId,
     required double result,
     required int attemptNumber,
   })
   ```
   記錄田賽選手的特定嘗試成績。

### 排名計算
1. **計算徑賽排名**
   ```dart
   List<Map<String, dynamic>> getTrackEventRanking({
     required String competitionId,
     required String eventName,
     required List<Map<String, dynamic>> participants,
   })
   ```
   根據記錄的時間計算徑賽或接力賽的排名。

2. **計算田賽排名**
   ```dart
   List<Map<String, dynamic>> getFieldEventRanking({
     required String competitionId,
     required String eventName,
     required List<Map<String, dynamic>> athletes,
     required bool isHigherBetter,
   })
   ```
   根據最佳成績計算田賽的排名，支持"越高越好"（如跳高）和"越遠越好"（如鉛球）兩種排名方式。

### 結果持久化
```dart
Future<void> saveEventResults({
  required String competitionId,
  required String eventName,
  required List<Map<String, dynamic>> rankedResults,
})
```
將計算好的排名結果保存到數據庫。

## 整合效益

實現`GlobalDataManager`帶來以下好處：

1. **數據一致性**：通過集中管理所有比賽數據，確保應用程序各部分使用相同的數據源。

2. **性能優化**：通過內存緩存減少數據庫查詢次數，提高應用程序響應速度。

3. **代碼重用**：避免在多個頁面中重複實現類似的數據處理邏輯。

4. **錯誤處理**：集中式的錯誤處理和日誌記錄，方便調試和問題排查。

5. **數據同步**：確保本地緩存與Firebase數據庫之間的數據同步。

## 使用示例

以下是幾個使用`GlobalDataManager`的示例：

### 記錄徑賽成績
```dart
// 記錄100米短跑成績（12.34秒 = 1234厘秒）
await dataManager.recordTrackEventTime(
  competitionId: 'competition_123',
  eventName: '100米',
  athleteId: 'athlete_456',
  timeInCentiseconds: 1234,
);
```

### 獲取排名
```dart
// 獲取100米短跑排名
final rankings = dataManager.getTrackEventRanking(
  competitionId: 'competition_123',
  eventName: '100米',
  participants: athletes, // 選手列表
);

// 保存排名結果
await dataManager.saveEventResults(
  competitionId: 'competition_123',
  eventName: '100米',
  rankedResults: rankings,
);
```

## 結論與未來改進

`GlobalDataManager`為應用程序提供了強大的數據管理基礎，但仍有改進空間：

1. **離線支持**：增強離線數據處理和同步能力。

2. **數據分頁**：對大型比賽實現數據分頁加載。

3. **數據版本控制**：實現數據版本管理，支持撤銷和重做操作。

4. **更精細的權限控制**：根據用戶角色（如管理員、裁判、觀眾）提供不同的數據訪問權限。

5. **數據統計和分析**：增加數據分析功能，提供比賽統計和洞察。

通過這些改進，`GlobalDataManager`將成為更全面、強大的比賽數據管理解決方案。 