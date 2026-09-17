/// Trazabilidad de un mensaje del dashboard para explicabilidad.
class MessageTrace {
  final String reason;
  final List<DataPoint> inputs;
  final String formula;
  final String? impactDescription;

  const MessageTrace({
    required this.reason,
    required this.inputs,
    required this.formula,
    this.impactDescription,
  });
}

class DataPoint {
  final String label;
  final String value;

  const DataPoint({required this.label, required this.value});
}
