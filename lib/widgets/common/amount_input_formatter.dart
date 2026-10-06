import 'package:flutter/services.dart';

/// Formateador de campos de monto: solo dígitos y hasta 2 decimales, con un
/// tope superior configurable.
///
/// Reemplaza las 4 copias casi idénticas que existían por pantalla
/// (transacciones, presupuestos, gastos recurrentes, transferencias) y
/// cubre el hueco que tenía el formulario de metas, que no validaba nada.
///
/// Acepta la coma como separador decimal y la convierte en punto: los
/// teclados en español la muestran en lugar del punto, y antes la coma se
/// descartaba en silencio ("10,50" quedaba como 1050). Como los campos no
/// usan separador de miles, una coma solo puede ser el decimal. Debe ir
/// PRIMERO en la lista de formateadores, antes de cualquier filtro que no
/// conozca la coma.
class AmountInputFormatter extends TextInputFormatter {
  final double maxValue;

  const AmountInputFormatter({this.maxValue = 999999999.99});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    // Mismo largo: la selección/cursor no se mueve.
    final text = newValue.text.replaceAll(',', '.');

    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(text)) {
      return oldValue;
    }

    final amount = double.tryParse(text);
    if (amount != null && amount > maxValue) {
      return oldValue;
    }

    return text == newValue.text ? newValue : newValue.copyWith(text: text);
  }
}
