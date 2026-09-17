import 'package:flutter/material.dart';
import '../../models/dashboard/message_trace.dart';
import 'dashboard_theme.dart';

class MessageTraceSheet extends StatelessWidget {
  final String title;
  final MessageTrace trace;

  const MessageTraceSheet({
    super.key,
    required this.title,
    required this.trace,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required MessageTrace trace,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MessageTraceSheet(title: title, trace: trace),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DashboardTheme.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '¿Cómo lo calculamos?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: DashboardTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(color: DashboardTheme.textMedium, fontSize: 14),
          ),
          const SizedBox(height: 20),
          _section('Por qué se generó', trace.reason),
          const SizedBox(height: 16),
          _section('Fórmula', trace.formula),
          if (trace.inputs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Datos utilizados',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: DashboardTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            ...trace.inputs.map(
              (dp) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(dp.label, style: TextStyle(color: DashboardTheme.textMedium)),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        dp.value,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: DashboardTheme.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (trace.impactDescription != null) ...[
            const SizedBox(height: 16),
            _section('Impacto esperado', trace.impactDescription!),
          ],
        ],
      ),
    );
  }

  Widget _section(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: DashboardTheme.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: DashboardTheme.textMedium, height: 1.4)),
      ],
    );
  }
}
