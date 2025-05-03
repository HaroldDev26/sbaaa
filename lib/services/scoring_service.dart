/// 體育賽事積分計算服務
/// 提供各種比賽項目的積分計算和排名功能
class ScoringService {
  /// 單例模式實現
  static final ScoringService _instance = ScoringService._internal();

  factory ScoringService() {
    return _instance;
  }

  ScoringService._internal();

  /// 根據排名計算積分
  ///
  /// [rank] 選手排名
  /// [isRelay] 是否為接力項目
  ///
  /// 返回計算後的積分
  int calculateScoreByRank(int rank, {bool isRelay = false}) {
    // 根據排名分配基礎積分
    int baseScore = 0;

    switch (rank) {
      case 1:
        baseScore = 11;
        break;
      case 2:
        baseScore = 9;
        break;
      case 3:
        baseScore = 7;
        break;
      case 4:
        baseScore = 5;
        break;
      case 5:
        baseScore = 4;
        break;
      case 6:
        baseScore = 3;
        break;
      case 7:
        baseScore = 2;
        break;
      case 8:
        baseScore = 1;
        break;
      default:
        baseScore = 0;
        break;
    }

    // 如果是接力項目，積分翻倍
    return isRelay ? baseScore * 2 : baseScore;
  }

  /// 對田賽選手進行排序和積分計算
  ///
  /// [athletes] 選手列表，每個選手為 Map<String, dynamic>
  /// [isRelayEvent] 是否為接力項目
  ///
  /// 返回排序後的選手列表，包含排名和積分
  List<Map<String, dynamic>> sortAndRankFieldEventAthletes(
      List<Map<String, dynamic>> athletes,
      {bool isRelayEvent = false}) {
    // 創建新列表避免修改原始數據
    final List<Map<String, dynamic>> result = List.from(athletes);

    // 按最佳成績排序 (越大越好)
    result.sort((a, b) {
      final resultA = a['bestResult'] as double? ?? 0.0;
      final resultB = b['bestResult'] as double? ?? 0.0;
      // 降序排列，所以是 b 比較 a
      return resultB.compareTo(resultA);
    });

    // 更新排名和計算積分
    for (int i = 0; i < result.length; i++) {
      // 處理平局情況
      if (i > 0 &&
          (result[i]['bestResult'] as double? ?? 0.0) ==
              (result[i - 1]['bestResult'] as double? ?? 0.0)) {
        // 平局，使用相同排名
        result[i]['rank'] = result[i - 1]['rank'];
        result[i]['score'] = result[i - 1]['score'];
      } else {
        // 不是平局，使用當前索引+1作為排名
        result[i]['rank'] = i + 1;
        result[i]['score'] = calculateScoreByRank(i + 1, isRelay: isRelayEvent);
      }
    }

    return result;
  }

  /// 對徑賽/接力賽選手進行排序和積分計算
  ///
  /// [athletes] 選手列表，每個選手為 Map<String, dynamic>
  /// [isRelayEvent] 是否為接力項目
  ///
  /// 返回排序後的選手列表，包含排名和積分
  List<Map<String, dynamic>> sortAndRankTrackEventAthletes(
      List<Map<String, dynamic>> athletes,
      {bool isRelayEvent = false}) {
    // 創建新列表避免修改原始數據
    final List<Map<String, dynamic>> result = List.from(athletes);

    // 按時間排序 (越小越好)
    result.sort((a, b) {
      final timeA = a['time'] as int? ?? 0;
      final timeB = b['time'] as int? ?? 0;
      return timeA.compareTo(timeB);
    });

    // 更新排名和計算積分
    for (int i = 0; i < result.length; i++) {
      // 處理平局情況
      if (i > 0 &&
          (result[i]['time'] as int? ?? 0) ==
              (result[i - 1]['time'] as int? ?? 0)) {
        // 平局，使用相同排名
        result[i]['rank'] = result[i - 1]['rank'];
        result[i]['score'] = result[i - 1]['score'];
      } else {
        // 不是平局，使用當前索引+1作為排名
        result[i]['rank'] = i + 1;
        result[i]['score'] = calculateScoreByRank(i + 1, isRelay: isRelayEvent);
      }
    }

    return result;
  }

  /// 根據項目類型自動選擇適當的排序和積分計算方法
  ///
  /// [athletes] 選手列表
  /// [eventType] 項目類型（徑賽/田賽）
  /// [eventName] 項目名稱，用於判斷是否為接力賽
  ///
  /// 返回排序和計分後的選手列表
  List<Map<String, dynamic>> rankAthletesByEventType(
      List<Map<String, dynamic>> athletes, String eventType, String eventName) {
    final bool isRelayEvent = eventName.toLowerCase().contains('接力');

    if (eventType.toLowerCase() == '田賽') {
      return sortAndRankFieldEventAthletes(athletes,
          isRelayEvent: isRelayEvent);
    } else {
      // 默認為徑賽或接力賽
      return sortAndRankTrackEventAthletes(athletes,
          isRelayEvent: isRelayEvent);
    }
  }

  /// 獲取積分說明文本
  ///
  /// [isRelayEvent] 是否為接力項目
  ///
  /// 返回積分規則的描述文本
  String getScoringDescription({required bool isRelayEvent}) {
    if (isRelayEvent) {
      return '積分分配：第1名（22分) 第2名(18分) 第3名(14分) 第4名(10分) 第5名(8分) 第6名(6分) 第7名(4分) 第8名(2分)';
    }
    return '積分分配：第1名(11分) 第2名(9分) 第3名(7分) 第4名(5分) 第5名(4分) 第6名(3分) 第7名(2分) 第8名(1分)';
  }
}
