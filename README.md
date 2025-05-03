# sbaaa

一個用於學校田徑比賽計時和記錄的 Flutter 應用程序。

## 項目概述

這個應用程序旨在幫助學校組織和管理田徑比賽，提供賽事管理、運動員登記、計時記錄和成績統計等功能。

## 主要功能

- 比賽創建和管理
- 參賽者登記與編組
- 徑賽計時和記錄
- 田賽成績記錄
- 接力賽管理
- 成績統計和排名
- 成績單導出

## 技術架構

- 前端：Flutter
- 後端：Firebase (Firestore, Authentication)
- 狀態管理：GlobalDataManager 集中數據管理
- 數據緩存：本地緩存提升性能

## 最近更新

### 全局數據管理器整合

我們最近對應用程序進行了重要的架構改進，引入了全局數據管理器 (`GlobalDataManager`)，以集中管理所有比賽相關數據。這一改進解決了之前直接訪問 Firestore 的碎片化問題，提高了代碼的可維護性和一致性。

已完成的整合工作包括：

- 成績結果頁面 (`event_result_screen.dart`)
- 田賽記錄頁面
- 徑賽計時頁面
- 接力賽計時頁面

詳細的整合文檔可以在 [docs/global_data_manager_integration.md](docs/global_data_manager_integration.md) 中找到。

## 開始使用

### 環境要求

- Flutter 3.0+
- Dart 2.17+
- Firebase 專案設定

### 安裝與設定

1. 克隆專案
```bash
git clone https://github.com/yourusername/sbaaa.git
cd sbaaa
```

2. 安裝依賴
```bash
flutter pub get
```

3. 連接 Firebase
```bash
flutterfire configure
```

4. 執行應用程序
```bash
flutter run
```

## 開發團隊

- HaroldDev - 主要開發者

## 許可證

This project is licensed under the MIT License - see the LICENSE file for details.
