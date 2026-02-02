import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/custom_category.dart';
import '../models/transaction.dart';
import '../services/category_service.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen>
    with TickerProviderStateMixin {
  final CategoryService _categoryService = CategoryService();
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  bool _isLoading = true;

  // Colores consistentes
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color successGreen = Color(0xFF059669);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color secondaryGray = Color(0xFF64748B);
  static const Color backgroundGray = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadData();
    _categoryService.addListener(_onCategoryChanged);
  }

  void _onCategoryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
  }

  Future<void> _loadData() async {
    await _categoryService.loadCategories();
    setState(() {
      _isLoading = false;
    });
    _animationController.forward();
  }

  @override
  void dispose() {
    _categoryService.removeListener(_onCategoryChanged);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGray,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildModernAppBar(),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeInAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Categorías del sistema'),
                      const SizedBox(height: 12),
                      _buildSystemCategories(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Categorías personalizadas'),
                      const SizedBox(height: 12),
                      _buildCustomCategories(),
                      const SizedBox(height: 100), // Espacio para FAB
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildModernFAB(),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: Color(0xFF1E293B),
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: const Text(
          'Categorías',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF8FAFC)],
            ),
          ),
        ),
      ),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryBlue.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.info_outline,
              color: primaryBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Categorías personalizadas',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Crea categorías para organizar mejor tus gastos y presupuestos',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: secondaryGray,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSystemCategories() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: ExpenseCategory.values.map((category) {
          final isLast = category == ExpenseCategory.values.last;
          return _buildCategoryTile(
            emoji: _getSystemCategoryEmoji(category),
            name: _getSystemCategoryName(category),
            isSystem: true,
            showDivider: !isLast,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCustomCategories() {
    final customCategories = _categoryService.customCategories;

    if (customCategories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.add_circle_outline,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sin categorías personalizadas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toca el botón + para crear tu primera categoría',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: customCategories.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;
          final isLast = index == customCategories.length - 1;
          return _buildCategoryTile(
            emoji: category.emoji,
            name: category.name,
            isSystem: false,
            showDivider: !isLast,
            onEdit: () => _showEditCategoryDialog(category),
            onDelete: () => _confirmDeleteCategory(category),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryTile({
    required String emoji,
    required String name,
    required bool isSystem,
    bool showDivider = true,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSystem ? 'Del sistema' : 'Personalizada',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSystem ? secondaryGray : primaryBlue,
                        fontWeight: isSystem ? FontWeight.normal : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isSystem) ...[
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: Colors.grey.shade500,
                  ),
                  onPressed: onEdit,
                  tooltip: 'Editar',
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: dangerRed,
                  ),
                  onPressed: onDelete,
                  tooltip: 'Eliminar',
                ),
              ],
              if (isSystem)
                Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 76,
            color: Colors.grey.shade200,
          ),
      ],
    );
  }

  Widget _buildModernFAB() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(),
        backgroundColor: primaryBlue,
        elevation: 0,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nueva categoría',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showAddCategoryDialog() {
    _showCategoryDialog(
      title: 'Nueva categoría',
      confirmText: 'Crear',
      onConfirm: (name, emoji) async {
        try {
          await _categoryService.addCategory(name: name, emoji: emoji);
          if (mounted) {
            Navigator.pop(context);
            _showSuccessSnackBar('Categoría "$name" creada');
          }
        } catch (e) {
          _showErrorSnackBar(e.toString());
        }
      },
    );
  }

  void _showEditCategoryDialog(CustomCategory category) {
    _showCategoryDialog(
      title: 'Editar categoría',
      confirmText: 'Guardar',
      initialName: category.name,
      initialEmoji: category.emoji,
      onConfirm: (name, emoji) async {
        try {
          await _categoryService.updateCategory(
            id: category.id,
            name: name,
            emoji: emoji,
          );
          if (mounted) {
            Navigator.pop(context);
            _showSuccessSnackBar('Categoría actualizada');
          }
        } catch (e) {
          _showErrorSnackBar(e.toString());
        }
      },
    );
  }

  void _showCategoryDialog({
    required String title,
    required String confirmText,
    String? initialName,
    String? initialEmoji,
    required Function(String name, String emoji) onConfirm,
  }) {
    final nameController = TextEditingController(text: initialName);
    String selectedEmoji = initialEmoji ?? '📁';
    final formKey = GlobalKey<FormState>();

    final emojis = [
      '🏋️', '🐕', '🐱', '💅', '🎮', '🎨', '🎵', '📷',
      '✈️', '🏖️', '☕', '🍺', '🛒', '💊', '📱', '💻',
      '🏠', '🚗', '🎓', '💼', '🎁', '💰', '📦', '⭐',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Título
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      initialName != null 
                          ? 'Modifica los datos de tu categoría'
                          : 'Crea una categoría personalizada para tus gastos',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Sección Emoji
                    const Text(
                      'Selecciona un emoji',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: emojis.length,
                      itemBuilder: (context, index) {
                        final emoji = emojis[index];
                        final isSelected = emoji == selectedEmoji;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedEmoji = emoji;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryBlue.withOpacity(0.15)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? primaryBlue : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                emoji,
                                style: TextStyle(fontSize: isSelected ? 22 : 18),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // Sección Nombre
                    const Text(
                      'Nombre de la categoría',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameController,
                      autofocus: initialName == null,
                      decoration: InputDecoration(
                        hintText: 'Ej: Mascotas, Gimnasio, Streaming...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: primaryBlue, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: dangerRed, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            selectedEmoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa un nombre para la categoría';
                        }
                        if (value.trim().length < 2) {
                          return 'El nombre es muy corto (mín. 2 caracteres)';
                        }
                        if (value.trim().length > 20) {
                          return 'El nombre es muy largo (máx. 20 caracteres)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    // Botones
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                onConfirm(nameController.text.trim(), selectedEmoji);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  initialName != null ? Icons.save : Icons.add,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  confirmText,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteCategory(CustomCategory category) async {
    // Verificar si tiene presupuestos
    final hasBudgets = await _categoryService.categoryHasBudgets(category.id);
    final hasTransactions = await _categoryService.categoryHasTransactions(category.id);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: dangerRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: dangerRed,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Eliminar categoría',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Eliminar "${category.emoji} ${category.name}"?',
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1E293B),
              ),
            ),
            if (hasBudgets || hasTransactions) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasBudgets)
                      const Row(
                        children: [
                          Icon(Icons.pie_chart_outline, size: 16, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Se eliminarán los presupuestos de esta categoría',
                              style: TextStyle(fontSize: 13, color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    if (hasBudgets && hasTransactions)
                      const SizedBox(height: 8),
                    if (hasTransactions)
                      const Row(
                        children: [
                          Icon(Icons.receipt_outlined, size: 16, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Las transacciones pasarán a "Otros"',
                              style: TextStyle(fontSize: 13, color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteCategory(category, deleteBudgets: hasBudgets);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Eliminar',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(CustomCategory category, {bool deleteBudgets = false}) async {
    try {
      final result = await _categoryService.deleteCategory(
        category.id,
        deleteBudgets: deleteBudgets,
      );
      if (mounted) {
        _showSuccessSnackBar(result.summary);
      }
    } on CategoryHasBudgetsException catch (e) {
      _showErrorSnackBar(e.message);
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: dangerRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _getSystemCategoryName(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.transport:
        return 'Transporte';
      case ExpenseCategory.food:
        return 'Alimentación';
      case ExpenseCategory.utilities:
        return 'Servicios Básicos';
      case ExpenseCategory.health:
        return 'Salud';
      case ExpenseCategory.education:
        return 'Educación';
      case ExpenseCategory.entertainment:
        return 'Entretenimiento';
      case ExpenseCategory.clothing:
        return 'Ropa y Calzado';
      case ExpenseCategory.home:
        return 'Hogar y Muebles';
      case ExpenseCategory.technology:
        return 'Tecnología';
      case ExpenseCategory.savings:
        return 'Ahorros e Inversión';
      case ExpenseCategory.gifts:
        return 'Regalos y Donaciones';
      case ExpenseCategory.other:
        return 'Otros';
    }
  }

  String _getSystemCategoryEmoji(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.transport:
        return '🚗';
      case ExpenseCategory.food:
        return '🍕';
      case ExpenseCategory.utilities:
        return '💡';
      case ExpenseCategory.health:
        return '🏥';
      case ExpenseCategory.education:
        return '📚';
      case ExpenseCategory.entertainment:
        return '🎬';
      case ExpenseCategory.clothing:
        return '👕';
      case ExpenseCategory.home:
        return '🏠';
      case ExpenseCategory.technology:
        return '📱';
      case ExpenseCategory.savings:
        return '💰';
      case ExpenseCategory.gifts:
        return '🎁';
      case ExpenseCategory.other:
        return '📦';
    }
  }
}
