import 'package:flutter/material.dart';
import 'dashboard_enums.dart';
import 'dashboard_message.dart';
import 'message_trace.dart';

class DashboardForecast extends DashboardMessage {
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
  final PredictionConfidence confidence;
  final double? projectedAmount;
  final int? projectedDays;
  final double? projectedPercentage;

  DashboardForecast({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    required this.trace,
    required this.confidence,
    this.projectedAmount,
    this.projectedDays,
    this.projectedPercentage,
  });

  @override
  MessageCategory get category => MessageCategory.forecast;
}
