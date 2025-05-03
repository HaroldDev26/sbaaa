# 更新日誌

本文檔記錄了應用程序的所有重要更改。

## [未發布]

### 新增功能
- 為田賽成績添加了專門的編輯對話框
- 根據比賽類型自動選擇合適的編輯對話框和排序邏輯
- 在 GlobalDataManager 類中添加了 getEventParticipants 方法以獲取項目參賽者

### 架構改進
- 引入了全局數據管理器 (`GlobalDataManager`) 集中管理比賽數據
- 將以下頁面整合到全局數據管理器中：
  - 成績結果頁面 (`event_result_screen.dart`)
  - 田賽記錄頁面 (`field_event_record_screen.dart`)
  - 徑賽計時頁面 (`track_event_timer_screen.dart`)
  - 接力賽計時頁面 (`relay_event_timer_screen.dart`)
- 擴展 GlobalDataManager 類，支持獲取項目參賽者信息

### 代碼優化
- 改進了田賽和徑賽的成績格式化顯示
- 優化了排名排序邏輯
- 移除了冗餘的檢錄狀態代碼
- 整合了 field_event_record_screen.dart 的所有數據操作方法到 GlobalDataManager

### 錯誤修復
- 修復了田賽成績排序邏輯錯誤
- 修復了時間格式化顯示問題
- 解決了未使用的 import 和其他小型代碼問題

## [0.1.0] - 2023-10-01

### 初次發布
- 基本比賽管理功能
- 運動員登記與編組
- 徑賽計時功能
- 田賽成績記錄功能
- 接力賽管理功能 