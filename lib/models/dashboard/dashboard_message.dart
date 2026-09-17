import 'package:flutter/material.dart';
import 'dashboard_enums.dart';
import 'message_trace.dart';

/// Clase base para todos los mensajes generados por el dashboard.
abstract class DashboardMessage {
  String get id;
  MessageCategory get category;
  String get title;
  String get message;
  IconData get icon;
  MessageTrace get trace;
}
