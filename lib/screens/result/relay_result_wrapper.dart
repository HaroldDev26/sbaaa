import 'package:flutter/material.dart';
import 'event_result_screen.dart';

class RelayResultWrapper extends StatelessWidget {
  final String competitionId;
  final String competitionName;
  final String eventName;
  final Map<String, dynamic> eventResults;

  const RelayResultWrapper({
    Key? key,
    required this.competitionId,
    required this.competitionName,
    required this.eventName,
    required this.eventResults,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 直接返回 EventResultScreen
    return EventResultScreen(
      competitionId: competitionId,
      competitionName: competitionName,
      eventName: eventName,
      eventResults: eventResults,
    );
  }
}
