import 'package:intl/intl.dart';

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

  // Convertir string a double de manera segura
  static double parseAmount(String amount) {
    // Remover símbolos y espacios
    String cleanAmount = amount.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleanAmount) ?? 0.0;
  }
}