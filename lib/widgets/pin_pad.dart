import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Indicador de progreso del PIN: `length` círculos, `filled` de ellos
/// rellenos. En rojo cuando `error` es `true` (feedback de PIN incorrecto).
class PinDots extends StatelessWidget {
  final int length;
  final int filled;
  final bool error;
  final Color color;

  const PinDots({
    super.key,
    required this.length,
    required this.filled,
    this.error = false,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = error ? AppColors.dangerRed : color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(length, (index) {
        final isFilled = index < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? dotColor : Colors.transparent,
            border: Border.all(color: dotColor, width: 1.5),
          ),
        );
      }),
    );
  }
}

/// Teclado numérico 0-9 con borrar y un slot opcional para biometría.
/// Widget "tonto": no mantiene el PIN internamente, solo reporta toques.
class NumericKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometricTap;
  final bool enabled;
  final Color textColor;
  final Color digitBackgroundColor;
  final Color iconColor;

  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onBiometricTap,
    this.enabled = true,
    this.textColor = Colors.white,
    this.digitBackgroundColor = const Color(0x14FFFFFF), // white @ 8%
    this.iconColor = Colors.white70,
  });

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map(_buildDigitButton).toList(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIconButton(
                icon: Icons.fingerprint,
                onTap: onBiometricTap,
                visible: onBiometricTap != null,
              ),
              _buildDigitButton('0'),
              _buildIconButton(
                icon: Icons.backspace_outlined,
                onTap: enabled ? onBackspace : null,
                visible: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDigitButton(String digit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: digitBackgroundColor,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onDigit(digit);
                }
              : null,
          child: SizedBox(
            width: 68,
            height: 68,
            child: Center(
              child: Text(
                digit,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool visible,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        width: 68,
        height: 68,
        child: visible
            ? Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap == null
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          onTap();
                        },
                  child: Icon(icon, color: iconColor, size: 26),
                ),
              )
            : null,
      ),
    );
  }
}
