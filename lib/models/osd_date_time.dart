import 'package:flutter/foundation.dart';

@immutable
class OSDDateTime {
  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final int notificationId;

  OSDDateTime({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.notificationId,
  });

  Map<String, int> toMap() => {
        'year': year,
        'month': month,
        'day': day,
        'hour': hour,
        'minute': minute,
        'notificationId': notificationId,
      };

  factory OSDDateTime.fromJson(Map<String, dynamic> json) {
    return OSDDateTime(
      year: json['year'],
      month: json['month'],
      day: json['day'],
      hour: json['hour'],
      minute: json['minute'],
      notificationId: json['notificationId'],
    );
  }

  @override
  String toString() {
    return {
      'year': year,
      'month': month,
      'day': day,
      'hour': hour,
      'minute': minute,
      'notificationId': notificationId,
    }.toString();
  }
}
