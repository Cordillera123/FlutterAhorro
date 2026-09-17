import 'package:flutter/material.dart';
import 'dashboard_enums.dart';
import 'dashboard_message.dart';
import 'message_trace.dart';

class DashboardAlert extends DashboardMessage {
  @override
  final String id;
  @override
  final String title;
  @override
  final String message;
  @override
  final IconData icon;
  @override
  final MessageTrace trace;
  final AlertSeverity severity;

  DashboardAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    required this.trace,
    required this.severity,
  });

  @override
  MessageCategory get category => MessageCategory.alert;

  int get sortOrder => severity == AlertSeverity.critical ? 0 : 1;
}
