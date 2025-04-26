# 競賽管理應用數據庫

這個目錄包含了競賽管理應用的SQLite數據庫文件和創建腳本。

## 文件說明

- `competition_app.db`：SQLite數據庫文件，可以直接用DB Browser for SQLite打開
- `create_empty_db.sql`：用於創建空數據庫的SQL腳本

## 數據庫結構

數據庫包含以下表：

### 比賽表 (competitions)

| 欄位名 | 資料類型 | 說明 |
|--------|----------|------|
| id | TEXT | 主鍵 |
| name | TEXT | 比賽名稱 |
| description | TEXT | 比賽描述 |
| venue | TEXT | 比賽場地 |
| start_date | TEXT | 開始日期 |
| end_date | TEXT | 結束日期 |
| status | TEXT | 狀態 |
| created_by | TEXT | 創建者 |
| created_at | TEXT | 創建時間 |

### 參與者表 (participants)

| 欄位名 | 資料類型 | 說明 |
|--------|----------|------|
| id | TEXT | 主鍵 |
| competition_id | TEXT | 外鍵，關聯比賽 |
| name | TEXT | 參與者姓名 |
| email | TEXT | 電子郵件 |
| phone | TEXT | 電話號碼 |
| school | TEXT | 學校/單位 |

## 如何使用

### 使用DB Browser for SQLite查看數據庫

1. 下載並安裝 [DB Browser for SQLite](https://sqlitebrowser.org/)
2. 打開DB Browser for SQLite
3. 點擊「打開數據庫」或使用菜單「File > Open Database」
4. 選擇 `competition_app.db` 文件

### 使用命令行查詢數據庫

```bash
# 查詢所有比賽
sqlite3 db_files/competition_app.db "SELECT * FROM competitions;"

# 查詢所有參與者
sqlite3 db_files/competition_app.db "SELECT * FROM participants;"

# 加入新的比賽
sqlite3 db_files/competition_app.db "INSERT INTO competitions VALUES ('comp_1', '2024校際籃球賽', '年度籃球比賽', '中央體育館', '2024-09-10', '2024-09-15', '計劃中', 'admin', '2024-04-05T13:00:00.000Z');"
```

### 如需重新創建空數據庫

如果需要重新創建空數據庫，可以使用以下命令：

```bash
sqlite3 db_files/competition_app.db < db_files/create_empty_db.sql
```

### 特別說明

此數據庫目前是空的，沒有預設的樣本數據。您可以通過應用添加新的比賽和參與者數據，再用DB Browser for SQLite查看添加的數據。 

```bash
sqlite3 db_files/competition_app.db "SELECT count(*) FROM competitions;"
``` 