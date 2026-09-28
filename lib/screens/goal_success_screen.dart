import 'package:flutter/material.dart';
import '../models/financial_goal.dart';
import '../utils/format_utils.dart';
import '../theme/app_colors.dart';
import '../widgets/common/common.dart';

class GoalSuccessScreen extends StatefulWidget {
  final FinancialGoal goal;
  final bool isEdit;

  const GoalSuccessScreen({super.key, required this.goal, this.isEdit = false});

  @override
  State<GoalSuccessScreen> createState() => _GoalSuccessScreenState();
}

class _GoalSuccessScreenState extends State<GoalSuccessScreen> {
  bool _showSuccess = false;

  static const Color primaryBlue = AppColors.primaryBlue;
  static const Color successGreen = AppColors.primaryGreen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppSuccessAnimation(
                loadingColor: AppColors.primaryPurple,
                successColor: successGreen,
                icon: Icons.flag_rounded,
                onShowSuccess: () => setState(() => _showSuccess = true),
                onComplete: () => Navigator.of(context).pop(true),
              ),

              const SizedBox(height: 32),

              // Título
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _showSuccess
                      ? widget.isEdit
                            ? '¡Meta actualizada!'
                            : '¡Meta creada!'
                      : widget.isEdit
                      ? 'Actualizando meta...'
                      : 'Creando tu meta...',
                  key: ValueKey(_showSuccess),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _showSuccess ? successGreen : AppColors.textMedium,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 16),

              // Subtítulo
              if (_showSuccess) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.goal.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.goal.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Meta: ${FormatUtils.formatMoney(widget.goal.targetAmount)}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textMedium,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.goal.typeName} • ${widget.goal.priorityName}',
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.goal.priorityColor,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: primaryBlue.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.goal.contributionSuggestion.cadence ==
                                GoalContributionCadence.weekly
                            ? 'Tu sugerencia actual es semanal'
                            : 'Tu sugerencia actual es mensual',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${FormatUtils.formatMoney(widget.goal.contributionSuggestion.amount)} por ${widget.goal.contributionSuggestion.cadenceLabel}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'durante ${widget.goal.contributionSuggestion.periodsRemaining} ${widget.goal.contributionSuggestion.cadenceLabelPlural}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMedium,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Esta guía se recalcula sola cuando aportas dinero o cambias la meta.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMedium,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (widget.goal.autoSave && widget.goal.autoSaveAmount > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: successGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Ahorro automático: ${FormatUtils.formatMoney(widget.goal.autoSaveAmount)}/mes',
                      style: const TextStyle(
                        fontSize: 12,
                        color: successGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ] else ...[
                Text(
                  widget.isEdit
                      ? 'Guardando cambios...'
                      : 'Configurando tu objetivo financiero...',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
