import 'package:flutter/services.dart';

/// Formateador de campos de monto: solo dígitos y hasta 2 decimales, con un
/// tope superior configurable.
///
/// Reemplaza las 4 copias casi idénticas que existían por pantalla
/// (transacciones, presupuestos, gastos recurrentes, transferencias) y
/// cubre el hueco que tenía el formulario de metas, que no validaba nada.
class AmountInputFormatter extends TextInputFormatter {
  final double maxValue;

  const AmountInputFormatter({this.maxValue = 999999999.99});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(newValue.text)) {
      return oldValue;
    }

    final amount = double.tryParse(newValue.text);
    if (amount != null && amount > maxValue) {
      return oldValue;
    }

    return newValue;
  }
}
