import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../models/region.dart';
import '../services/region_service.dart';

class FormatUtils {
  // Formatear dinero según la región activa (locale y símbolo de moneda)
  static String formatMoney(double amount) {
    final region = RegionService().current;
    final formatter = NumberFormat.currency(
      locale: region.localeCode,
      symbol: region.currencySymbol,
      decimalDigits: 2, // CAMBIADO: de 0 a 2 para mostrar decimales
    );
    return formatter.format(amount);
  }

  /// Monto abreviado (ej. "20 M $") para espacios muy reducidos, como el
  /// centro del gráfico circular. Respeta el locale y la moneda de la región.
  static String formatMoneyShort(double amount) {
    final region = RegionService().current;
    return NumberFormat.compactCurrency(
      locale: region.localeCode,
      symbol: region.currencySymbol,
      decimalDigits: 1,
    ).format(amount);
  }

  // Formatear fecha en formato corto (ej: "15 Ene")
  static String formatDateShort(DateTime date) {
    final months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  // Formatear fecha completa (ej: "15 de Enero, 2024")
  static String formatDateFull(DateTime date) {
    final months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
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
        'Ene',
        'Feb',
        'Mar',
        'Abr',
        'May',
        'Jun',
        'Jul',
        'Ago',
        'Sep',
        'Oct',
        'Nov',
        'Dic',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }

  // Obtener el color según el tipo de transacción
  static String getTransactionColor(bool isIncome) {
    return isIncome
        ? '#4CAF50'
        : '#F44336'; // Verde para ingresos, rojo para gastos
  }

  /// Valor absoluto a partir del cual un porcentaje se muestra como `>999%`
  /// o `<-999%`. Es solo de presentación: el valor calculado no se modifica.
  static const double maxDisplayedPercentage = 999;

  // Formatear porcentaje
  static String formatPercentage(double percentage) {
    return formatPercentageCapped(percentage);
  }

  /// Formatea un porcentaje de forma segura para la UI: `—` si no es un
  /// número finito y `>999%` / `<-999%` cuando el valor es tan grande que
  /// no aporta información (p. ej. una tasa de ahorro con ingresos casi 0).
  static String formatPercentageCapped(
    double percentage, {
    bool signed = false,
  }) {
    if (!percentage.isFinite) return '—';

    final limit = maxDisplayedPercentage.toStringAsFixed(0);
    if (percentage > maxDisplayedPercentage) return '>$limit%';
    if (percentage < -maxDisplayedPercentage) return '<-$limit%';

    final rounded = double.parse(percentage.toStringAsFixed(1));
    if (rounded == 0) return '0.0%';
    final sign = signed && rounded > 0 ? '+' : '';
    return '$sign${rounded.toStringAsFixed(1)}%';
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

    final parsed = double.tryParse(cleanAmount);
    // "NaN" / "Infinity" también se interpretan como double: nunca deben
    // llegar a un cálculo de balance.
    return (parsed != null && parsed.isFinite) ? parsed : 0.0;
  }

  // NUEVO: Formatear porcentaje con signo
  static String formatPercentageWithSign(double percentage) {
    return formatPercentageCapped(percentage, signed: true);
  }

  // NUEVO: Calcular porcentaje de crecimiento
  //
  // Se conserva con su comportamiento histórico (devuelve 100 cuando el
  // período anterior es 0) porque lo consumen los analizadores del dashboard.
  // Para mostrar una variación al usuario usa [tryCalculateGrowthPercentage].
  static double calculateGrowthPercentage(
    double currentValue,
    double previousValue,
  ) {
    if (previousValue == 0) {
      return currentValue > 0 ? 100.0 : 0.0;
    }
    return ((currentValue - previousValue) / previousValue.abs()) * 100;
  }

  /// Variación porcentual entre dos períodos, o `null` cuando no hay una base
  /// comparable (período anterior en 0 o con menos de un centavo, o valores
  /// no finitos). Evita mostrar un `+100%` falso o porcentajes absurdos
  /// cuando se divide entre casi cero; la UI decide qué mostrar ("Nuevo", "—").
  static double? tryCalculateGrowthPercentage(
    double currentValue,
    double previousValue,
  ) {
    if (!currentValue.isFinite || !previousValue.isFinite) return null;
    if (previousValue.abs() < 0.005) return null;
    return ((currentValue - previousValue) / previousValue.abs()) * 100;
  }

  /// Texto corto de una variación para chips: porcentaje con signo,
  /// `Nuevo` si no había base y ahora sí hay valor, o `—` si no hay nada
  /// que comparar.
  static String formatGrowthLabel(double? growth, {required double current}) {
    if (growth != null) return formatPercentageCapped(growth, signed: true);
    return current.abs() >= 0.005 ? 'Nuevo' : '—';
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
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return months[month - 1];
  }

  // NUEVO: Obtener nombre del mes corto
  static String getShortMonthName(int month) {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
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
