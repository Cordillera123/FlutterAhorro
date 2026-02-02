import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../utils/format_utils.dart';

class BudgetSuccessScreen extends StatefulWidget {
  final Budget budget;
  final bool isEdit;

  const BudgetSuccessScreen({
    super.key,
    required this.budget,
    this.isEdit = false,
  });

  @override
  State<BudgetSuccessScreen> createState() => _BudgetSuccessScreenState();
}

class _BudgetSuccessScreenState extends State<BudgetSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _loadingController;
  late AnimationController _successController;
  late Animation<double> _checkAnimation;
  late Animation<double> _scaleAnimation;

  bool _showSuccess = false;

  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color successGreen = Color(0xFF059669);

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

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
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
                    ? _buildSuccessAnimation()
                    : _buildLoadingAnimation(),
              ),

              const SizedBox(height: 32),

              // Título
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _showSuccess
                      ? widget.isEdit
                            ? '¡Presupuesto actualizado!'
                            : '¡Presupuesto creado!'
                      : widget.isEdit
                      ? 'Actualizando presupuesto...'
                      : 'Creando presupuesto...',
                  key: ValueKey(_showSuccess),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _showSuccess ? successGreen : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 16),

              // Subtítulo
              if (_showSuccess) ...[
                Text(
                  '${widget.budget.categoryName} - ${widget.budget.periodName}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Límite: ${FormatUtils.formatMoney(widget.budget.amount)}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.budget.name,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Text(
                  widget.isEdit
                      ? 'Guardando cambios...'
                      : 'Configurando tu control de gastos...',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingAnimation() {
    return AnimatedBuilder(
      animation: _loadingController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                primaryBlue.withOpacity(0.1),
                primaryBlue.withOpacity(0.3),
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
                    valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                  ),
                ),
              ),

              // Icono central
              Center(
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: primaryBlue,
                  size: 32,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuccessAnimation() {
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
                  color: successGreen.withOpacity(0.3),
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
                      color: successGreen,
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

  CheckmarkPainter({required this.progress, required this.color});

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
