import 'package:flutter/material.dart';

/// Origen de un recordatorio: de qué parte de la app viene el dato.
enum ReminderType { recurringExpense, goalDeadline, goalOffTrack }

/// Qué tan urgente es el recordatorio — controla color y orden.
enum ReminderUrgency { tomorrow, thisWeek, upcoming }

/// Aviso dentro de la app sobre algo que requiere atención pronto: un gasto
/// recurrente próximo a ejecutarse, o una meta de ahorro con fecha cercana
/// o atrasada de ritmo. Se recalcula cada vez que se abre la app — no se
/// persiste ni depende de notificaciones del sistema operativo.
class Reminder {
  final String id;
  final ReminderType type;
  final String title;
  final String message;
  final IconData icon;
  final ReminderUrgency urgency;
  final DateTime dueDate;

  /// ID del gasto recurrente o de la meta al que hace referencia.
  final String referenceId;

  const Reminder({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.icon,
    required this.urgency,
    required this.dueDate,
    required this.referenceId,
  });

  Color get accentColor {
    switch (urgency) {
      case ReminderUrgency.tomorrow:
        return const Color(0xFFDC2626);
      case ReminderUrgency.thisWeek:
        return const Color(0xFFF59E0B);
      case ReminderUrgency.upcoming:
        return const Color(0xFF3B82F6);
    }
  }
}
