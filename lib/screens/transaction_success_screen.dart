import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../utils/format_utils.dart';

class TransactionSuccessScreen extends StatefulWidget {
  final Transaction transaction;
  final bool isEdit;

  const TransactionSuccessScreen({
    super.key,
    required this.transaction,
    this.isEdit = false,
  });

  @override
  State<TransactionSuccessScreen> createState() => _TransactionSuccessScreenState();
}

class _TransactionSuccessScreenState extends State<TransactionSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _loadingController;
  late AnimationController _successController;
  late Animation<double> _checkAnimation;
  late Animation<double> _scaleAnimation;

  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimation();
  }

  void _initAnimations() {
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _successController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _checkAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _successController,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    ));
  }

  void _startAnimation() async {
    // Mostrar loading
    _loadingController.repeat();

    // Simular procesamiento
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() {
        _showSuccess = true;
      });

      _loadingController.stop();
      _successController.forward();

      // Navegar de vuelta después del éxito
      await Future.delayed(const Duration(milliseconds: 1200));

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = widget.transaction.type == TransactionType.income;
    final primaryColor = isIncome
        ? const Color(0xFF059669)
        : const Color(0xFFDC2626);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animación de carga o éxito
              SizedBox(
                width: 120,
                height: 120,
                child: _showSuccess
                    ? _buildSuccessAnimation(primaryColor)
                    : _buildLoadingAnimation(primaryColor),
              ),

              const SizedBox(height: 32),

              // Título
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _showSuccess
                      ? (widget.isEdit ? '¡Transacción actualizada!' : '¡Transacción guardada!')
                      : (widget.isEdit ? 'Actualizando transacción...' : 'Guardando transacción...'),
                  key: ValueKey(_showSuccess),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _showSuccess ? primaryColor : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 16),

              // Subtítulo
              if (_showSuccess) ...[
                Text(
                  '${isIncome ? 'Ingreso' : 'Gasto'} de ${FormatUtils.formatMoney(widget.transaction.amount)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.transaction.description,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Text(
                  'Actualizando tu balance...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingAnimation(Color color) {
    return AnimatedBuilder(
      animation: _loadingController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.3),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Círculo de fondo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),

              // Loading spinner
              Center(
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),

              // Icono central
              Center(
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: color,
                  size: 32,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuccessAnimation(Color color) {
    return AnimatedBuilder(
      animation: _successController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: AnimatedBuilder(
                animation: _checkAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(60, 60),
                    painter: CheckmarkPainter(
                      progress: _checkAnimation.value,
                      color: color,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  CheckmarkPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();

    // Checkmark path
    final p1 = Offset(size.width * 0.2, size.height * 0.5);
    final p2 = Offset(size.width * 0.45, size.height * 0.7);
    final p3 = Offset(size.width * 0.8, size.height * 0.3);

    if (progress <= 0.5) {
      // First line (from p1 to p2)
      final currentProgress = progress * 2;
      final currentEnd = Offset.lerp(p1, p2, currentProgress)!;
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(currentEnd.dx, currentEnd.dy);
    } else {
      // Complete first line and animate second line
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);

      final currentProgress = (progress - 0.5) * 2;
      final currentEnd = Offset.lerp(p2, p3, currentProgress)!;
      path.lineTo(currentEnd.dx, currentEnd.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}