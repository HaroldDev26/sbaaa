import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

pickImage(ImageSource source) async {
  final ImagePicker imagePicker = ImagePicker();
  XFile? file = await imagePicker.pickImage(source: source);
  if (file != null) {
    return await file.readAsBytes();
  }
}

/// 計算年齡
///
/// [birthday] 可以是ISO8601格式的日期字符串或DateTime對象
///
/// 返回計算出的年齡，如果輸入無效則返回null
int? calculateAge(dynamic birthday) {
  if (birthday == null) return null;

  DateTime birthDate;

  // 如果輸入是字符串，嘗試解析為DateTime
  if (birthday is String) {
    try {
      birthDate = DateTime.parse(birthday);
    } catch (e) {
      debugPrint('解析生日出錯: $e');
      return null;
    }
  }
  // 如果輸入已經是DateTime
  else if (birthday is DateTime) {
    birthDate = birthday;
  }
  // 如果輸入不是支持的類型
  else {
    return null;
  }

  // 獲取當前日期
  final DateTime today = DateTime.now();

  // 計算年齡，考慮月份和日期
  int age = today.year - birthDate.year;

  // 如果當前日期的月份小於出生月份，或者月份相同但日期小於出生日期，則年齡減1
  if (today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day)) {
    age--;
  }

  return age > 0 ? age : 0; // 確保年齡不為負數
}
