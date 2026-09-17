import 'package:flutter/material.dart';
import 'dashboard_enums.dart';
import 'dashboard_message.dart';
import 'message_trace.dart';

class DashboardObservation extends DashboardMessage {
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
  final ObservationDimension dimension;
  final double? numericValue;

  DashboardObservation({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    required this.trace,
    required this.dimension,
    this.numericValue,
  });

  @override
  MessageCategory get category => MessageCategory.observation;

  String get dimensionLabel {
    switch (dimension) {
      case ObservationDimension.trend:
        return 'Tendencia';
      case ObservationDimension.pattern:
        return 'Patrón';
      case ObservationDimension.habit:
        return 'Hábito';
      case ObservationDimension.category:
        return 'Categoría';
      case ObservationDimension.budget:
        return 'Presupuesto';
      case ObservationDimension.goal:
        return 'Meta';
      case ObservationDimension.monthly:
        return 'Mensual';
    }
  }
}
