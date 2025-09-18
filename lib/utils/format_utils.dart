import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class FormatUtils {
  // Formatear dinero en pesos colombianos con decimales
  static String formatMoney(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 2, // CAMBIADO: de 0 a 2 para mostrar decimales
    );
    return formatter.format(amount);
  }

  // Formatear fecha en formato corto (ej: "15 Ene")
  static String formatDateShort(DateTime date) {
    final months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  // Formatear fecha completa (ej: "15 de Enero, 2024")
  static String formatDateFull(DateTime date) {
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${date.day} de ${months[date.month - 1]}, ${date.year}';
  }

  // Formatear fecha para mostrar en listas (ej: "Hoy", "Ayer", "15 Ene")
  static String formatDateForList(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Hoy';
    } else if (dateOnly == yesterday) {
      return 'Ayer';
    } else if (dateOnly.year == now.year) {
      // Mismo año, mostrar solo día y mes
      return formatDateShort(date);
    } else {
      // Año diferente, mostrar día, mes y año
      final months = [
        'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }

  // Obtener el color según el tipo de transacción
  static String getTransactionColor(bool isIncome) {
    return isIncome ? '#4CAF50' : '#F44336'; // Verde para ingresos, rojo para gastos
  }

  // Formatear porcentaje
  static String formatPercentage(double percentage) {
    return '${percentage.toStringAsFixed(1)}%';
  }

  // Obtener saludo según la hora del día
  static String getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Buenos días';
    } else if (hour < 18) {
      return 'Buenas tardes';
    } else {
      return 'Buenas noches';
    }
  }

  // Formatear fecha estándar (ej: "15 de Enero, 2024")
  static String formatDate(DateTime date) {
    return formatDateFull(date);
  }

  // MEJORADO: Convertir string a double de manera segura
  static double parseAmount(String amount) {
    if (amount.isEmpty) return 0.0;
    
    // Remover símbolos de moneda, comas y espacios
    String cleanAmount = amount
        .replaceAll('\$', '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .trim();
    
    return double.tryParse(cleanAmount) ?? 0.0;
  }

  // NUEVO: Formatear porcentaje con signo
  static String formatPercentageWithSign(double percentage) {
    final sign = percentage >= 0 ? '+' : '';
    return '$sign${percentage.toStringAsFixed(1)}%';
  }

  // NUEVO: Calcular porcentaje de crecimiento
  static double calculateGrowthPercentage(double currentValue, double previousValue) {
    if (previousValue == 0) {
      return currentValue > 0 ? 100.0 : 0.0;
    }
    return ((currentValue - previousValue) / previousValue.abs()) * 100;
  }

  // NUEVO: Formatear duración
  static String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} día${duration.inDays != 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hora${duration.inHours != 1 ? 's' : ''}';
    } else {
      return '${duration.inMinutes} minuto${duration.inMinutes != 1 ? 's' : ''}';
    }
  }

  // NUEVO: Obtener color según el crecimiento
  static Color getGrowthColor(double percentage) {
    if (percentage > 0) {
      return const Color(0xFF059669); // Verde para crecimiento positivo
    } else if (percentage < 0) {
      return const Color(0xFFDC2626); // Rojo para crecimiento negativo
    } else {
      return const Color(0xFF64748B); // Gris para sin cambios
    }
  }

  // NUEVO: Obtener icono según el crecimiento
  static IconData getGrowthIcon(double percentage) {
    if (percentage > 0) {
      return Icons.trending_up_rounded;
    } else if (percentage < 0) {
      return Icons.trending_down_rounded;
    } else {
      return Icons.trending_flat_rounded;
    }
  }

  // NUEVO: Formatear números grandes de manera compacta
  static String formatCompactNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toStringAsFixed(0);
    }
  }

  // NUEVO: Obtener mensaje de crecimiento descriptivo
  static String getGrowthMessage(double percentage) {
    if (percentage > 10) {
      return 'Tu dinero está creciendo muy bien';
    } else if (percentage > 0) {
      return 'Tu dinero está creciendo';
    } else if (percentage == 0) {
      return 'Tu dinero se mantiene estable';
    } else if (percentage > -10) {
      return 'Tienes una pequeña disminución';
    } else {
      return 'Tu dinero está disminuyendo';
    }
  }

  // NUEVO: Obtener nombre del mes
  static String getMonthName(int month) {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return months[month - 1];
  }

  // NUEVO: Obtener nombre del mes corto
  static String getShortMonthName(int month) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return months[month - 1];
  }

  // NUEVO: Formatear dinero sin decimales para cantidades grandes
  static String formatMoneyCompact(double amount) {
    if (amount >= 1000000) {
      return '\$${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(0)}K';
    } else {
      return formatMoney(amount);
    }
  }

  // NUEVO: Calcular días entre fechas
  static int daysBetween(DateTime from, DateTime to) {
    from = DateTime(from.year, from.month, from.day);
    to = DateTime(to.year, to.month, to.day);
    return (to.difference(from).inHours / 24).round();
  }

  // NUEVO: Verificar si es el mismo mes
  static bool isSameMonth(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month;
  }

  // NUEVO: Obtener el primer día del mes
  static DateTime getFirstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  // NUEVO: Obtener el último día del mes
  static DateTime getLastDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }
}