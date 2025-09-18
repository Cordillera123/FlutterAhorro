import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../services/stats_service.dart';
import '../utils/format_utils.dart';

class PieChartWidget extends StatefulWidget {
  final List<CategoryStats> categoryStats;
  final double size;
  final bool showLegend;
  final Function(CategoryStats?)? onCategorySelected;

  const PieChartWidget({
    super.key,
    required this.categoryStats,
    this.size = 200,
    this.showLegend = true,
    this.onCategorySelected,
  });

  @override
  State<PieChartWidget> createState() => _PieChartWidgetState();
}

class _PieChartWidgetState extends State<PieChartWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _animation;
  late Animation<double> _pulseAnimation;
  
  CategoryStats? _selectedCategory;
  int? _hoveredIndex;

  // Colores vibrantes y atractivos para el gráfico
  static const List<Color> pieColors = [
    Color(0xFFFF6B6B), // Rojo coral
    Color(0xFF4ECDC4), // Turquesa
    Color(0xFF45B7D1), // Azul cielo
    Color(0xFF96CEB4), // Verde menta
    Color(0xFFFECA57), // Amarillo dorado
    Color(0xFFFF9FF3), // Rosa fucsia
    Color(0xFF54A0FF), // Azul brillante
    Color(0xFF5F27CD), // Púrpura
    Color(0xFFFF9F43), // Naranja
    Color(0xFF00D2D3), // Cian
    Color(0xFFFF6348), // Rojo tomate
    Color(0xFF2ED573), // Verde lime
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categoryStats.isEmpty) {
      return _buildEmptyChart();
    }

    return Column(
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return GestureDetector(
              onTapDown: _handleTapDown,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _selectedCategory != null ? _pulseAnimation.value : 1.0,
                      child: CustomPaint(
                        painter: PieChartPainter(
                          categoryStats: widget.categoryStats,
                          animationValue: _animation.value,
                          selectedIndex: _selectedCategory != null 
                              ? widget.categoryStats.indexOf(_selectedCategory!)
                              : -1,
                          hoveredIndex: _hoveredIndex,
                          colors: pieColors,
                        ),
                        size: Size(widget.size, widget.size),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
        if (widget.showLegend) ...[
          const SizedBox(height: 24),
          _buildLegend(),
        ],
        if (_selectedCategory != null) ...[
          const SizedBox(height: 16),
          _buildSelectedCategoryInfo(),
        ],
      ],
    );
  }

  Widget _buildEmptyChart() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.withOpacity(0.1),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pie_chart_outline_rounded,
              size: 40,
              color: Colors.grey,
            ),
            SizedBox(height: 8),
            Text(
              'Sin datos',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: widget.categoryStats.asMap().entries.map((entry) {
        final index = entry.key;
        final category = entry.value;
        final color = pieColors[index % pieColors.length];
        final isSelected = _selectedCategory == category;

        return GestureDetector(
          onTap: () => _selectCategory(category),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? color : color.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  category.categoryIcon,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 4),
                Text(
                  category.categoryName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? color : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectedCategoryInfo() {
    if (_selectedCategory == null) return const SizedBox.shrink();

    final color = pieColors[widget.categoryStats.indexOf(_selectedCategory!) % pieColors.length];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _selectedCategory!.categoryIcon,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Text(
                _selectedCategory!.categoryName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoItem(
                'Monto',
                FormatUtils.formatMoney(_selectedCategory!.amount),
                color,
              ),
              Container(
                width: 1,
                height: 30,
                color: color.withOpacity(0.3),
              ),
              _buildInfoItem(
                'Porcentaje',
                '${_selectedCategory!.percentage.toStringAsFixed(1)}%',
                color,
              ),
              Container(
                width: 1,
                height: 30,
                color: color.withOpacity(0.3),
              ),
              _buildInfoItem(
                'Transacciones',
                '${_selectedCategory!.transactionCount}',
                color,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  void _handleTapDown(TapDownDetails details) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final tapPosition = details.localPosition;
    final distance = (tapPosition - center).distance;
    
    // Verificar si el tap está dentro del círculo
    if (distance <= widget.size / 2) {
      final angle = math.atan2(
        tapPosition.dy - center.dy,
        tapPosition.dx - center.dx,
      );
      
      // Convertir ángulo a porcentaje del círculo
      double normalizedAngle = (angle + math.pi / 2) % (2 * math.pi);
      if (normalizedAngle < 0) normalizedAngle += 2 * math.pi;
      
      double currentAngle = 0;
      for (int i = 0; i < widget.categoryStats.length; i++) {
        final category = widget.categoryStats[i];
        final segmentAngle = (category.percentage / 100) * 2 * math.pi;
        
        if (normalizedAngle >= currentAngle && normalizedAngle <= currentAngle + segmentAngle) {
          _selectCategory(category);
          // Vibración háptica para feedback
          HapticFeedback.mediumImpact();
          break;
        }
        
        currentAngle += segmentAngle;
      }
    }
  }

  void _selectCategory(CategoryStats? category) {
    setState(() {
      _selectedCategory = _selectedCategory == category ? null : category;
    });

    if (_selectedCategory != null) {
      _pulseController.reset();
      _pulseController.repeat(reverse: true);
      // Vibración háptica para selección
      HapticFeedback.lightImpact();
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }

    widget.onCategorySelected?.call(_selectedCategory);
  }
}

class PieChartPainter extends CustomPainter {
  final List<CategoryStats> categoryStats;
  final double animationValue;
  final int selectedIndex;
  final int? hoveredIndex;
  final List<Color> colors;

  PieChartPainter({
    required this.categoryStats,
    required this.animationValue,
    required this.selectedIndex,
    this.hoveredIndex,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Dibujar sombra del círculo con múltiples capas para mayor profundidad
    final shadowPaint1 = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    final shadowPaint2 = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    
    canvas.drawCircle(center.translate(0, 4), radius * 0.95, shadowPaint2);
    canvas.drawCircle(center.translate(0, 2), radius * 0.98, shadowPaint1);

    double startAngle = -math.pi / 2; // Comenzar desde arriba
    
    for (int i = 0; i < categoryStats.length; i++) {
      final category = categoryStats[i];
      final sweepAngle = (category.percentage / 100) * 2 * math.pi * animationValue;
      final color = colors[i % colors.length];
      
      // Determinar si este segmento está seleccionado o hover
      final isSelected = i == selectedIndex;
      final isHovered = i == hoveredIndex;
      final effectiveRadius = isSelected ? radius * 1.08 : radius;
      
      // Crear gradiente radial para cada segmento
      final paint = Paint()
        ..style = PaintingStyle.fill;
      
      // Gradiente más dramático para segmentos seleccionados
      if (isSelected || isHovered) {
        paint.shader = RadialGradient(
          center: Alignment.center,
          colors: [
            Colors.white.withOpacity(0.3),
            color.withOpacity(0.9),
            color,
            color.withOpacity(0.8),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: effectiveRadius));
      } else {
        paint.shader = RadialGradient(
          center: Alignment.center,
          colors: [
            color.withOpacity(0.7),
            color,
            color.withOpacity(0.9),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: effectiveRadius));
      }

      final rect = Rect.fromCircle(center: center, radius: effectiveRadius);
      
      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Dibujar highlight brillante en la parte superior del segmento
      if (animationValue > 0.7) {
        final highlightPaint = Paint()
          ..color = Colors.white.withOpacity(0.4)
          ..style = PaintingStyle.fill;
        
        final highlightRect = Rect.fromCircle(center: center, radius: effectiveRadius * 0.7);
        canvas.drawArc(
          highlightRect,
          startAngle,
          sweepAngle * 0.3,
          true,
          highlightPaint,
        );
      }

      // Dibujar borde brillante entre segmentos
      if (animationValue > 0.8) {
        final borderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 3 : 2;
        
        canvas.drawArc(
          rect,
          startAngle,
          sweepAngle,
          true,
          borderPaint,
        );
      }

      // Dibujar el ícono de la categoría en el centro del segmento
      if (animationValue > 0.9 && sweepAngle > 0.3) {
        final iconAngle = startAngle + sweepAngle / 2;
        final iconRadius = effectiveRadius * 0.7;
        final iconCenter = Offset(
          center.dx + math.cos(iconAngle) * iconRadius,
          center.dy + math.sin(iconAngle) * iconRadius,
        );

        _drawCategoryIcon(canvas, iconCenter, category.categoryIcon, color, isSelected);
      }

      startAngle += sweepAngle;
    }

    // Dibujar círculo central con información
    if (animationValue > 0.7) {
      _drawCenterInfo(canvas, center, radius * 0.3);
    }
  }

  void _drawCategoryIcon(Canvas canvas, Offset center, String icon, Color color, [bool isSelected = false]) {
    final iconSize = isSelected ? 18.0 : 16.0;
    final backgroundRadius = isSelected ? 16.0 : 14.0;
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: icon,
        style: TextStyle(
          fontSize: iconSize,
          color: Colors.white,
          shadows: [
            Shadow(
              color: color.withOpacity(0.8),
              blurRadius: isSelected ? 4 : 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    
    // Dibujar fondo circular para el ícono con gradiente
    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.95),
          Colors.white.withOpacity(0.85),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: backgroundRadius));
    
    canvas.drawCircle(center, backgroundRadius, backgroundPaint);
    
    // Dibujar borde del fondo con gradiente
    final borderPaint = Paint()
      ..color = isSelected ? color : color.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 3 : 2;
    
    canvas.drawCircle(center, backgroundRadius, borderPaint);

    // Dibujar highlight si está seleccionado
    if (isSelected) {
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(center.translate(-4, -4), 4, highlightPaint);
    }

    textPainter.paint(
      canvas,
      center.translate(-textPainter.width / 2, -textPainter.height / 2),
    );
  }

  void _drawCenterInfo(Canvas canvas, Offset center, double radius) {
    // Sombra del círculo central con múltiples capas
    final shadowPaint1 = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    final shadowPaint2 = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    
    canvas.drawCircle(center.translate(0, 2), radius, shadowPaint2);
    canvas.drawCircle(center.translate(0, 1), radius, shadowPaint1);
    
    // Fondo del círculo central con gradiente
    final centerPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        colors: [
          Colors.white,
          const Color(0xFFF8FAFC),
          Colors.white.withOpacity(0.95),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    
    canvas.drawCircle(center, radius, centerPaint);
    
    // Borde del círculo central con gradiente
    final borderPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF7C3AED).withOpacity(0.3),
          const Color(0xFF3B82F6).withOpacity(0.3),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawCircle(center, radius, borderPaint);

    // Highlight en la parte superior
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center.translate(-radius * 0.3, -radius * 0.3), radius * 0.2, highlightPaint);

    // Texto del total
    final totalAmount = categoryStats.fold(0.0, (sum, cat) => sum + cat.amount);
    
    final titlePainter = TextPainter(
      text: const TextSpan(
        text: 'Total',
        style: TextStyle(
          fontSize: 12,
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    final amountPainter = TextPainter(
      text: TextSpan(
        text: FormatUtils.formatMoney(totalAmount),
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    titlePainter.layout();
    amountPainter.layout();

    titlePainter.paint(
      canvas,
      center.translate(-titlePainter.width / 2, -titlePainter.height - 4),
    );

    amountPainter.paint(
      canvas,
      center.translate(-amountPainter.width / 2, 4),
    );
  }

  @override
  bool shouldRepaint(PieChartPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.selectedIndex != selectedIndex ||
           oldDelegate.hoveredIndex != hoveredIndex;
  }
}