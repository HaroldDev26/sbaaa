/// 獎牌類型枚舉
enum MedalType {
  gold, // 金牌
  silver, // 銀牌
  bronze, // 銅牌
  none // 無獎牌
}

/// 將字符串轉換為MedalType枚舉
MedalType stringToMedalType(String type) {
  switch (type.toLowerCase()) {
    case 'gold':
      return MedalType.gold;
    case 'silver':
      return MedalType.silver;
    case 'bronze':
      return MedalType.bronze;
    default:
      return MedalType.none;
  }
}

/// 將MedalType枚舉轉換為字符串
String medalTypeToString(MedalType type) {
  switch (type) {
    case MedalType.gold:
      return 'gold';
    case MedalType.silver:
      return 'silver';
    case MedalType.bronze:
      return 'bronze';
    case MedalType.none:
      return 'none';
  }
}
