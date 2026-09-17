import 'package:flutter/material.dart';
import '../../models/dashboard/dashboard_message.dart';
import 'dashboard_theme.dart';
import 'message_trace_sheet.dart';

class DashboardMessageTile extends StatelessWidget {
  final DashboardMessage message;
  final String? badge;
  final Color? accentColor;

  const DashboardMessageTile({
    super.key,
    required this.message,
    this.badge,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? DashboardTheme.primaryBlue;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: DashboardTheme.cardDecoration(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(message.icon, color: color, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                message.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: DashboardTheme.textDark,
                  fontSize: 14,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            message.message,
            style: TextStyle(color: DashboardTheme.textMedium, height: 1.35),
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.info_outline_rounded, color: DashboardTheme.textMedium, size: 20),
          onPressed: () => MessageTraceSheet.show(
            context,
            title: message.title,
            trace: message.trace,
          ),
        ),
      ),
    );
  }
}
