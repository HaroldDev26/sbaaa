import '../utils/sorting_function.dart';

/// Athletic competition scoring service
/// Provides scoring calculation and ranking functionalities for various event types
class ScoringService {
  /// Singleton implementation
  static final ScoringService _instance = ScoringService._internal();

  factory ScoringService() {
    return _instance;
  }

  ScoringService._internal();

  /// Calculate score based on ranking
  ///
  /// [rank] Athlete's ranking position
  /// [isRelay] Whether it's a relay event
  ///
  /// Returns the calculated score
  int calculateScoreByRank(int rank, {bool isRelay = false}) {
    // Assign base score according to ranking
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

    // Double the score for relay events
    return isRelay ? baseScore * 2 : baseScore;
  }

  /// Sort and calculate scores for field event athletes
  ///
  /// [athletes] List of athletes, each as Map<String, dynamic>
  /// [isRelayEvent] Whether it's a relay event
  ///
  /// Returns the sorted list of athletes with ranking and scores
  List<Map<String, dynamic>> sortAndRankFieldEventAthletes(
      List<Map<String, dynamic>> athletes,
      {bool isRelayEvent = false}) {
    if (athletes.isEmpty) return [];

    // Use sortByScore function from sorting_function.dart to sort athletes by best result
    // For field events, higher results are better, so use ascending=false (descending order)
    final List<Map<String, dynamic>> result =
        sortByScore(athletes, 'bestResult', ascending: false);

    // Update ranking and calculate scores
    for (int i = 0; i < result.length; i++) {
      // Handle tie situations
      if (i > 0 &&
          (result[i]['bestResult'] as double? ?? 0.0) ==
              (result[i - 1]['bestResult'] as double? ?? 0.0)) {
        // Tie, use the same ranking
        result[i]['rank'] = result[i - 1]['rank'];
        result[i]['score'] = result[i - 1]['score'];
      } else {
        // Not a tie, use current index+1 as ranking
        result[i]['rank'] = i + 1;
        result[i]['score'] = calculateScoreByRank(i + 1, isRelay: isRelayEvent);
      }
    }

    return result;
  }

  /// Sort and calculate scores for track/relay event athletes
  ///
  /// [athletes] List of athletes, each as Map<String, dynamic>
  /// [isRelayEvent] Whether it's a relay event
  ///
  /// Returns the sorted list of athletes with ranking and scores
  List<Map<String, dynamic>> sortAndRankTrackEventAthletes(
      List<Map<String, dynamic>> athletes,
      {bool isRelayEvent = false}) {
    if (athletes.isEmpty) return [];

    // Use quickSort from sorting_function.dart for more efficient sorting
    // For track events, lower times are better
    final List<Map<String, dynamic>> result = quickSort(athletes, (a, b) {
      final timeA = a['time'] as int? ?? 0;
      final timeB = b['time'] as int? ?? 0;
      return timeA.compareTo(timeB);
    });

    // Update ranking and calculate scores
    for (int i = 0; i < result.length; i++) {
      // Handle tie situations
      if (i > 0 &&
          (result[i]['time'] as int? ?? 0) ==
              (result[i - 1]['time'] as int? ?? 0)) {
        // Tie, use the same ranking
        result[i]['rank'] = result[i - 1]['rank'];
        result[i]['score'] = result[i - 1]['score'];
      } else {
        // Not a tie, use current index+1 as ranking
        result[i]['rank'] = i + 1;
        result[i]['score'] = calculateScoreByRank(i + 1, isRelay: isRelayEvent);
      }
    }

    return result;
  }

  /// Automatically select appropriate sorting and scoring method based on event type
  ///
  /// [athletes] List of athletes
  /// [eventType] Event type (track/field)
  /// [eventName] Event name, used to determine if it's a relay event
  ///
  /// Returns sorted and scored list of athletes
  List<Map<String, dynamic>> rankAthletesByEventType(
      List<Map<String, dynamic>> athletes, String eventType, String eventName) {
    // Support both English "relay" and Chinese "接力" keywords for relay events
    final bool isRelayEvent = eventName.toLowerCase().contains('relay') ||
        eventName.toLowerCase().contains('接力');

    // Support both English "field" and Chinese "田賽" event types
    if (eventType.toLowerCase() == 'field' ||
        eventType.toLowerCase() == 'field event') {
      return sortAndRankFieldEventAthletes(athletes,
          isRelayEvent: isRelayEvent);
    } else {
      // Default to track or relay events
      return sortAndRankTrackEventAthletes(athletes,
          isRelayEvent: isRelayEvent);
    }
  }

  /// Sort athletes by their name alphabetically
  ///
  /// [athletes] List of athletes
  ///
  /// Returns sorted list of athletes by name
  List<Map<String, dynamic>> sortAthletesByName(
      List<Map<String, dynamic>> athletes) {
    return sortByAlphabet(athletes, 'name');
  }

  /// Sort athletes by school name
  ///
  /// [athletes] List of athletes
  ///
  /// Returns sorted list of athletes by school
  List<Map<String, dynamic>> sortAthletesBySchool(
      List<Map<String, dynamic>> athletes) {
    return sortBySchool(athletes);
  }

  /// Sort athletes by age group
  ///
  /// [athletes] List of athletes
  ///
  /// Returns sorted list of athletes by age group
  List<Map<String, dynamic>> sortAthletesByAgeGroup(
      List<Map<String, dynamic>> athletes) {
    return sortByAgeGroup(athletes);
  }

  /// Get scoring explanation text
  ///
  /// [isRelayEvent] Whether it's a relay event
  ///
  /// Returns description text of scoring rules
  String getScoringDescription({required bool isRelayEvent}) {
    if (isRelayEvent) {
      return 'Scoring system: 1st place (22 pts), 2nd place (18 pts), 3rd place (14 pts), 4th place (10 pts), 5th place (8 pts), 6th place (6 pts), 7th place (4 pts), 8th place (2 pts)';
    }
    return 'Scoring system: 1st place (11 pts), 2nd place (9 pts), 3rd place (7 pts), 4th place (5 pts), 5th place (4 pts), 6th place (3 pts), 7th place (2 pts), 8th place (1 pt)';
  }
}
