import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/account.dart';
import '../services/account_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common/common.dart';

/// Pantalla para gestionar las cuentas del usuario.
/// Permite crear, editar y eliminar cuentas financieras.
class ManageAccountsScreen extends StatefulWidget {
  const ManageAccountsScreen({super.key});

  @override
  State<ManageAccountsScreen> createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState extends State<ManageAccountsScreen>
    with TickerProviderStateMixin {
  final AccountService _accountService = AccountService();
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;

  // Colores consistentes
  static const Color primaryBlue = AppColors.primaryBlue;
  static const Color darkBlue = AppColors.darkBlue;
  static const Color deepBlue = AppColors.deepBlue;
  static const Color successGreen = AppColors.primaryGreen;
  static const Color warningYellow = AppColors.warningYellow;
  static const Color dangerRed = AppColors.dangerRed;
  static const Color textDark = AppColors.textDark;
  static const Color textMedium = AppColors.textMedium;
  static const Color backgroundLight = AppColors.backgroundLight;
  static const Color borderLight = AppColors.borderLight;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _accountService.addListener(_onAccountChanged);
  }

  void _onAccountChanged() {
    if (mounted) setState(() {});
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

    _animationController.forward();
  }

  @override
  void dispose() {
    _accountService.removeListener(_onAccountChanged);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildModernAppBar(),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeInAnimation,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAccountsSummary(),
                    const SizedBox(height: 24),
                    _buildAccountsList(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _accountService.canCreateMoreAccounts
          ? _buildAddFAB()
          : null,
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 160, // antes: 140 -> causaba overflow de 1px
      floating: false,
      pinned: true,
      backgroundColor: primaryBlue,
      elevation: 0,
      leading: const AppBackButton(light: true),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryBlue, darkBlue, deepBlue],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Mis Cuentas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height:
                          1.0, // evita altura extra del line-height por defecto
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gestiona tus cuentas financieras',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountsSummary() {
    final total = _accountService.accountCount;
    final remaining = _accountService.remainingAccountSlots;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: borderLight),
      ),
      child: Row(
        children: [
          _buildSummaryItem(
            icon: Icons.account_balance_rounded,
            color: primaryBlue,
            value: '$total',
            label: 'Cuentas',
          ),
          Container(
            width: 1,
            height: 40,
            color: borderLight,
            margin: const EdgeInsets.symmetric(horizontal: 20),
          ),
          _buildSummaryItem(
            icon: Icons.add_circle_outline_rounded,
            color: remaining > 0 ? successGreen : textMedium,
            value: '$remaining',
            label: 'Disponibles',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: textMedium,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsList() {
    final accounts = _accountService.accounts;
    final activeId = _accountService.activeAccountId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tus cuentas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textDark,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        ...accounts.map((account) {
          final isActive = account.id == activeId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildAccountCard(account, isActive),
          );
        }),
      ],
    );
  }

  Widget _buildAccountCard(Account account, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? account.color.withValues(alpha: 0.3) : borderLight,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isActive ? account.color : Colors.black).withValues(
              alpha: 0.06,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Emoji
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: account.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(account.emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        account.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isActive ? account.color : textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: account.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Activa',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: account.color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      account.typeName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: textMedium,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (account.isDefault) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.star_rounded, size: 14, color: warningYellow),
                      const SizedBox(width: 2),
                      const Text(
                        'Principal',
                        style: TextStyle(
                          fontSize: 11,
                          color: warningYellow,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Acciones
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: textMedium, size: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            itemBuilder: (context) {
              final items = <PopupMenuEntry<String>>[];

              if (!isActive) {
                items.add(
                  const PopupMenuItem(
                    value: 'activate',
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: successGreen,
                        ),
                        SizedBox(width: 10),
                        Text('Activar cuenta'),
                      ],
                    ),
                  ),
                );
              }

              items.add(
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: primaryBlue),
                      SizedBox(width: 10),
                      Text('Editar'),
                    ],
                  ),
                ),
              );

              if (!account.isDefault) {
                items.add(
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: dangerRed),
                        SizedBox(width: 10),
                        Text('Eliminar', style: TextStyle(color: dangerRed)),
                      ],
                    ),
                  ),
                );
              }

              return items;
            },
            onSelected: (value) {
              switch (value) {
                case 'activate':
                  _activateAccount(account);
                  break;
                case 'edit':
                  _showEditAccountDialog(account);
                  break;
                case 'delete':
                  _showDeleteConfirmation(account);
                  break;
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddFAB() {
    return FloatingActionButton.extended(
      onPressed: _showAddAccountDialog,
      backgroundColor: primaryBlue,
      foregroundColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: const Icon(Icons.add_rounded, size: 20),
      label: const Text(
        'Nueva Cuenta',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }

  Future<void> _activateAccount(Account account) async {
    try {
      await _accountService.setActiveAccount(account.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cuenta "${account.name}" activada'),
            backgroundColor: successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackbar(e.toString());
    }
  }

  void _showAddAccountDialog() {
    _showAccountFormDialog(
      title: 'Nueva Cuenta',
      subtitle: 'Crea una nueva cuenta financiera',
      confirmLabel: 'Crear Cuenta',
      onConfirm: (name, type, emoji, color) async {
        await _accountService.addAccount(
          name: name,
          type: type,
          emoji: emoji,
          color: color,
        );
      },
    );
  }

  void _showEditAccountDialog(Account account) {
    _showAccountFormDialog(
      title: 'Editar Cuenta',
      subtitle: 'Modifica los datos de tu cuenta',
      confirmLabel: 'Guardar Cambios',
      initialName: account.name,
      initialType: account.type,
      initialEmoji: account.emoji,
      initialColor: account.color,
      onConfirm: (name, type, emoji, color) async {
        await _accountService.updateAccount(
          id: account.id,
          name: name,
          type: type,
          emoji: emoji,
          color: color,
        );
      },
    );
  }

  void _showAccountFormDialog({
    required String title,
    required String subtitle,
    required String confirmLabel,
    required Future<void> Function(
      String name,
      AccountType type,
      String emoji,
      Color color,
    )
    onConfirm,
    String? initialName,
    AccountType? initialType,
    String? initialEmoji,
    Color? initialColor,
  }) {
    final nameController = TextEditingController(text: initialName ?? '');
    AccountType selectedType = initialType ?? AccountType.personal;
    String selectedEmoji =
        initialEmoji ?? Account.defaultEmojiForType(selectedType);
    Color selectedColor =
        initialColor ?? Account.defaultColorForType(selectedType);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: borderLight,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: selectedColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                selectedEmoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: textMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Nombre
                        const Text(
                          'Nombre de la cuenta',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: 'Ej: Ahorro vacaciones',
                            hintStyle: TextStyle(
                              color: textMedium.withValues(alpha: 0.6),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: borderLight),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: selectedColor,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          maxLength: 30,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 16),

                        // Tipo de cuenta
                        const Text(
                          'Tipo de cuenta',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: AccountType.values.map((type) {
                            final isSelected = type == selectedType;
                            final typeColor = Account.defaultColorForType(type);
                            final typeEmoji = Account.defaultEmojiForType(type);
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setSheetState(() {
                                  selectedType = type;
                                  // Auto-actualizar emoji y color si no fueron personalizados
                                  if (initialEmoji == null ||
                                      selectedEmoji ==
                                          Account.defaultEmojiForType(
                                            initialType ?? AccountType.personal,
                                          )) {
                                    selectedEmoji = Account.defaultEmojiForType(
                                      type,
                                    );
                                  }
                                  if (initialColor == null ||
                                      selectedColor ==
                                          Account.defaultColorForType(
                                            initialType ?? AccountType.personal,
                                          )) {
                                    selectedColor = Account.defaultColorForType(
                                      type,
                                    );
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? typeColor.withValues(alpha: 0.12)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? typeColor.withValues(alpha: 0.4)
                                        : borderLight,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      typeEmoji,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _getTypeName(type),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? typeColor
                                            : textMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        // Botón confirmar
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                _showErrorSnackbar(
                                  'Ingresa un nombre para la cuenta',
                                );
                                return;
                              }

                              try {
                                await onConfirm(
                                  name,
                                  selectedType,
                                  selectedEmoji,
                                  selectedColor,
                                );
                                if (context.mounted) Navigator.pop(context);
                                _showSuccessSnackbar('$title exitoso');
                              } catch (e) {
                                _showErrorSnackbar(
                                  e.toString().replaceFirst('Exception: ', ''),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: Text(confirmLabel),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(Account account) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '¿Eliminar cuenta?',
      message:
          'Se eliminará la cuenta "${account.name}". Los datos asociados '
          '(transacciones, presupuestos, metas y gastos automáticos) se '
          'perderán permanentemente.',
      icon: Icons.warning_amber_rounded,
    );
    if (confirmed != true) return;

    try {
      await _accountService.deleteAccount(account.id);
      _showSuccessSnackbar('Cuenta "${account.name}" eliminada');
    } catch (e) {
      _showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _getTypeName(AccountType type) {
    switch (type) {
      case AccountType.main:
        return 'Principal';
      case AccountType.savings:
        return 'Ahorros';
      case AccountType.investment:
        return 'Inversiones';
      case AccountType.work:
        return 'Trabajo';
      case AccountType.personal:
        return 'Personal';
      case AccountType.business:
        return 'Negocio';
      case AccountType.emergency:
        return 'Emergencia';
      case AccountType.education:
        return 'Educación';
      case AccountType.family:
        return 'Familia';
      case AccountType.other:
        return 'Otro';
    }
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: dangerRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
