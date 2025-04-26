# 模型資料夾（Models）

這個資料夾包含應用程式中使用的主要數據模型類別，用於管理和操作資料。每個模型類別都提供了與 Firebase Firestore 交互的方法。

## 主要模型類別

### UserModel (user.dart)
管理用戶資訊，包括：
- 基本個人資料（電子郵件、用戶名、角色等）
- 可選資訊（電話、性別、生日、學校等）
- 與團隊和比賽的關聯

### TeamModel (team.dart)
管理團隊資訊，包括：
- 團隊基本資料（名稱、描述、標誌等）
- 團隊成員列表
- 參與的比賽列表
- 相關學校/機構

### CompetitionModel (competition.dart)
管理比賽資訊，包括：
- 比賽詳情（名稱、描述、場地、日期等）
- 參賽者/團隊
- 比賽結果
- 比賽項目和類別

## 模型使用範例

### 創建新用戶

```dart
UserModel newUser = UserModel(
  uid: firebaseUser.uid,
  email: 'user@example.com',
  username: 'UserName',
  role: '運動員',
  createdAt: DateTime.now().toIso8601String(),
);

// 轉換為 Map 並存儲到 Firestore
await firestore.collection('users').doc(newUser.uid).set(newUser.toMap());
```

### 從 Firestore 獲取用戶

```dart
DocumentSnapshot doc = await firestore.collection('users').doc(uid).get();
if (doc.exists) {
  UserModel user = UserModel.fromDoc(doc);
  print(user.username);
}
```

### 更新用戶資料

```dart
// 使用 copyWith 方法創建帶有更新字段的新實例
UserModel updatedUser = existingUser.copyWith(
  phone: '0912345678',
  gender: '男',
);

// 更新到 Firestore
await firestore.collection('users').doc(updatedUser.uid).update(updatedUser.toMap());
```

### 序列化和反序列化

所有模型都支援 JSON 序列化和反序列化：

```dart
// 序列化為 JSON 字符串
String json = user.toJson();

// 從 JSON 字符串創建模型
UserModel userFromJson = UserModel.fromJson(json);
``` 