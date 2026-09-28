import 'package:flutter/material.dart';

/// Animación compartida de "procesando -> listo" para las pantallas de
/// éxito (transacción, presupuesto, meta): un círculo con spinner que se
/// transforma en un check animado. Maneja su propio temporizador y llama a
/// [onShowSuccess] al pasar al estado de éxito y a [onComplete] quince
/// segundos después, para que la pantalla decida cómo cerrarse.
class AppSuccessAnimation extends StatefulWidget {
  final Color loadingColor;
  final Color successColor;
  final IconData icon;
  final VoidCallback? onShowSuccess;
  final VoidCallback onComplete;

  const AppSuccessAnimation({
    super.key,
    required this.loadingColor,
    required this.successColor,
    required this.icon,
    this.onShowSuccess,
    required this.onComplete,
  });

  @override
  State<AppSuccessAnimation> createState() => _AppSuccessAnimationState();
}

class _AppSuccessAnimationState extends State<AppSuccessAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _loadingController;
  late final AnimationController _successController;
  late final Animation<double> _checkAnimation;
  late final Animation<double> _scaleAnimation;

  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

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

    _run();
  }

  Future<void> _run() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _showSuccess = true);
    widget.onShowSuccess?.call();
    _loadingController.stop();
    _successController.forward();

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: _showSuccess ? _buildSuccess() : _buildLoading(),
    );
  }

  Widget _buildLoading() {
    return AnimatedBuilder(
      animation: _loadingController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                widget.loadingColor.withValues(alpha: 0.1),
                widget.loadingColor.withValues(alpha: 0.3),
              ],
            ),
          ),
          child: Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
              Center(
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.loadingColor,
                    ),
                  ),
                ),
              ),
              Center(
                child: Icon(widget.icon, color: widget.loadingColor, size: 32),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuccess() {
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
                  color: widget.successColor.withValues(alpha: 0.3),
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
                    painter: _CheckmarkPainter(
                      progress: _checkAnimation.value,
                      color: widget.successColor,
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

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CheckmarkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();

    final p1 = Offset(size.width * 0.2, size.height * 0.5);
    final p2 = Offset(size.width * 0.45, size.height * 0.7);
    final p3 = Offset(size.width * 0.8, size.height * 0.3);

    if (progress <= 0.5) {
      final currentProgress = progress * 2;
      final currentEnd = Offset.lerp(p1, p2, currentProgress)!;
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(currentEnd.dx, currentEnd.dy);
    } else {
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);

      final currentProgress = (progress - 0.5) * 2;
      final currentEnd = Offset.lerp(p2, p3, currentProgress)!;
      path.lineTo(currentEnd.dx, currentEnd.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
