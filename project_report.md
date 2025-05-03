# 田徑比賽計時與成績記錄系統報告

## 系統概述

本系統實現了一個完整的田徑比賽計時與成績記錄模組，用於管理田徑比賽中的賽道競賽（如100米、200米等）、接力賽和田賽項目（如跳高、鉛球等）的成績記錄。系統使用Flutter開發，並整合了Firebase Firestore作為後端數據庫。

## 核心組件

### 全局數據管理器 (GlobalDataManager)

GlobalDataManager是一個singleton類，負責維護比賽數據的一致性和管理各種緩存：

1. **緩存管理**：
   - `_competitionCache`：保存比賽基本數據
   - `_timingCache`：保存田徑賽道項目的計時數據
   - `_fieldEventCache`：保存田賽項目的成績數據

2. **主要功能**：
   - 初始化和清除比賽數據緩存
   - 記錄和讀取競賽時間和成績
   - 生成賽道和田賽項目的排名
   - 將結果保存到Firestore數據庫

3. **數據處理方法**：
   - `recordEventTime`：記錄選手的競賽時間
   - `recordFieldEventAttempt`：記錄田賽項目的嘗試成績
   - `getTrackEventRanking`：獲取賽道項目的選手排名
   - `getFieldEventRanking`：獲取田賽項目的選手排名
   - `saveEventResults`：將競賽結果保存到數據庫
   - `loadFieldEventResults`：從數據庫載入田賽成績

### 賽道計時屏幕 (TrackEventTimerScreen)

管理賽道比賽的計時功能：

1. **計時功能**：
   - 實現精確到毫秒的計時器
   - 開始、停止和重置計時
   - 為每位選手單獨記錄時間

2. **選手管理**：
   - 顯示所有參賽選手列表
   - 記錄和更新選手時間
   - 根據時間自動生成排名

3. **數據保存**：
   - 使用GlobalDataManager保存成績到數據庫
   - 可查看臨時生成的結果排名

### 接力賽計時屏幕 (RelayEventTimerScreen)

專為接力賽設計的計時系統：

1. **團隊管理**：
   - 顯示參賽隊伍及其成員
   - 記錄每支隊伍的總成績
   - 記錄每位隊員的交接棒時間

2. **分段計時**：
   - 可單獨記錄每位隊員的交接棒時間
   - 記錄隊伍的總成績時間
   - 自動生成隊伍排名

### 田賽記錄屏幕 (FieldEventRecordScreen)

管理田賽項目的成績記錄：

1. **嘗試次數管理**：
   - 為每位選手記錄多次嘗試的成績
   - 支持標記犯規嘗試
   - 根據最佳成績生成排名

2. **數據驗證**：
   - 輸入驗證確保成績在合理範圍內
   - 提供適當的用戶反饋

### 名單管理屏幕 (NameListScreen)

管理比賽選手的分組和名單：

1. **選手數據展示**：
   - 按分組顯示參賽選手
   - 清晰顯示選手詳細資料（姓名、性別、學校等）
   - 處理選手編號缺失的情況，自動分配編號

2. **數據過濾功能**：
   - 支持按性別過濾選手
   - 支持按學校過濾選手
   - 提供直觀的過濾介面

## 技術實現細節

### 計時器實現

計時器使用Dart的`Timer`類和`DateTime`來實現高精度計時：

```dart
// 計時啟動
_startTime = DateTime.now();
_updateTimer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
  if (mounted) {
    setState(() {
      _currentTime = DateTime.now();
      _elapsedDuration = _currentTime!.difference(_startTime!);
    });
  }
});
```

### 時間格式化

系統將時間格式化為標準的MM:SS.CC格式（分鐘:秒.百分之一秒）：

```dart
String _formatTime(int centiseconds) {
  final minutes = (centiseconds ~/ (100 * 60)).toString().padLeft(2, '0');
  final seconds = ((centiseconds ~/ 100) % 60).toString().padLeft(2, '0');
  final remainingCentiseconds = (centiseconds % 100).toString().padLeft(2, '0');
  return '$minutes:$seconds.$remainingCentiseconds';
}
```

### 排名生成算法

系統根據選手成績自動生成排名：

```dart
// 按照時間排序 (升序)
participantsWithTimes.sort(
  (a, b) => (a['time'] as int).compareTo(b['time'] as int),
);

// 添加排名
for (int i = 0; i < participantsWithTimes.length; i++) {
  participantsWithTimes[i]['rank'] = i + 1;
}
```

田賽項目則根據項目類型不同選擇排序方式（越高越好或越遠越好）：

```dart
if (isHigherBetter) {
  // 跳高等：從高到低排序
  athletesWithResults.sort(
    (a, b) => (b['bestResult'] as double).compareTo(a['bestResult'] as double),
  );
} else {
  // 鉛球等：從遠到近排序
  athletesWithResults.sort(
    (a, b) => (b['bestResult'] as double).compareTo(a['bestResult'] as double),
  );
}
```

### 運動員數據標準化

為確保運動員數據在不同頁面間保持一致性，我們實現了數據標準化處理：

```dart
// 確保數據字段的一致性
athletes = athletes.map((athlete) {
  // 確保基本字段存在
  final normalizedAthlete = {...athlete};
  
  // 處理姓名字段 (可能是name或userName)
  if (!normalizedAthlete.containsKey('userName') && normalizedAthlete.containsKey('name')) {
    normalizedAthlete['userName'] = normalizedAthlete['name'];
  }
  
  // 處理學校字段
  if (!normalizedAthlete.containsKey('school') && normalizedAthlete.containsKey('userSchool')) {
    normalizedAthlete['school'] = normalizedAthlete['userSchool'];
  }
  
  // 處理性別字段
  if (!normalizedAthlete.containsKey('gender') && normalizedAthlete.containsKey('formData')) {
    normalizedAthlete['gender'] = normalizedAthlete['formData']['gender'];
  }

  // 處理運動員編號
  if (!normalizedAthlete.containsKey('athleteNumber') || 
      normalizedAthlete['athleteNumber'] == null || 
      normalizedAthlete['athleteNumber'].toString().isEmpty) {
    // 使用ID的前8個字符作為運動員編號前綴
    String prefix = normalizedAthlete['id'].toString().substring(0, math.min(8, normalizedAthlete['id'].toString().length));
    normalizedAthlete['athleteNumber'] = 'A${prefix}';
  }

  return normalizedAthlete;
}).toList();
```

## 用戶界面特點

1. **自適應佈局**：
   - 根據屏幕尺寸調整顯示元素大小
   - 針對小屏幕優化顯示效果

2. **狀態反饋**：
   - 計時狀態顏色反饋（綠色=計時中，紅色=已停止，灰色=重置）
   - 成績記錄時的快捷訊息通知

3. **操作流程優化**：
   - 所有功能都有直觀按鈕
   - 通過禁用不適用的按鈕減少錯誤操作
   - 重要操作（如記錄時間）有確認反饋

4. **運動員資料顯示**：
   - 直觀的性別標識（藍色=男，粉色=女）
   - 清晰顯示學校資訊
   - 按組別顯示運動員名單
   - 支持按性別和學校過濾選手列表

## 數據流程

1. **比賽開始時**：
   - 載入參賽選手/隊伍資料
   - 初始化計時器

2. **計時過程中**：
   - 開始/停止/重置計時
   - 記錄選手的成績時間

3. **結果保存時**：
   - 生成選手/隊伍排名
   - 將結果保存到Firestore數據庫
   - 產生結果報告

## 目前完成的優化

1. **代碼精簡**：移除了與簽到狀態相關的代碼，專注於記錄和計時功能
2. **性能提升**：使用緩存機制減少數據庫讀取操作
3. **錯誤處理**：添加了完善的錯誤處理機制，提高系統穩定性
4. **資料一致性**：修復了運動員性別和學校資料不一致的問題
5. **界面改進**：優化了名單顯示，添加了性別顯示，並改進了學校資料呈現

## 最新改進（2024-06-30）

1. **修復運動員性別數據**：
   - 移除了預設將運動員性別設為"男"的硬編碼，改為從表單數據中獲取
   - 在運動員名單中添加性別視覺標識，使用顏色區分性別（藍色=男，粉色=女）

2. **運動員數據標準化**：
   - 實現了數據標準化邏輯，處理不同來源的運動員數據
   - 修復了因數據結構不一致導致的顯示問題

3. **界面優化**：
   - 改進了名單中運動員資訊的顯示方式
   - 添加了更多視覺提示，使數據更易於理解

4. **運動員編號處理**：
   - 添加了自動處理運動員編號缺失的邏輯
   - 當編號缺失時，系統會使用運動員ID生成唯一編號

5. **名單過濾功能**：
   - 添加了按性別和學校過濾選手的功能
   - 實現了清晰的過濾介面，提高了用戶體驗

## 使用說明

1. **賽道計時**：
   - 開始計時後，為每位選手記錄完成時間
   - 可以更新選手時間或查看當前排名
   - 比賽結束後保存所有成績

2. **接力賽計時**：
   - 開始計時後，記錄每位隊員的交接棒時間
   - 記錄每隊的總成績
   - 比賽結束後保存所有成績

3. **田賽記錄**：
   - 為每位選手記錄多次嘗試的成績
   - 可標記犯規嘗試
   - 根據最佳成績生成排名並保存

4. **名單管理**：
   - 檢視按分組排列的運動員名單
   - 可按性別或學校過濾選手
   - 清晰查看每位選手的詳細信息 