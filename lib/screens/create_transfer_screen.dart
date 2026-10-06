import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/account.dart';
import '../services/account_service.dart';
import '../services/transaction_service.dart';
import '../theme/app_colors.dart';
import '../utils/format_utils.dart';
import '../widgets/common/common.dart';
import 'manage_accounts_screen.dart';

/// Pantalla para crear una transferencia contable entre dos cuentas propias.
///
/// NO es banca electrónica: solo mueve el registro contable dentro de la
/// app (-monto en origen, +monto en destino). No cuenta como ingreso ni
/// gasto — ver [TransactionService.createTransfer].
class CreateTransferScreen extends StatefulWidget {
  const CreateTransferScreen({super.key});

  @override
  State<CreateTransferScreen> createState() => _CreateTransferScreenState();
}

class _CreateTransferScreenState extends State<CreateTransferScreen> {
  final AccountService _accountService = AccountService();
  final TransactionService _transactionService = TransactionService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late String _fromAccountId;
  String? _toAccountId;
  bool _isSubmitting = false;
  String? _errorMessage;

  static const Color primaryBlue = AppColors.primaryBlue;
  static const Color textDark = AppColors.textDark;
  static const Color textMedium = AppColors.textMedium;
  static const Color backgroundLight = AppColors.backgroundLight;
  static const Color borderLight = AppColors.borderLight;
  static const Color dangerRed = AppColors.dangerRed;

  @override
  void initState() {
    super.initState();
    _fromAccountId = _accountService.activeAccountId;
    final others = _accountService.accounts
        .where((a) => a.id != _fromAccountId)
        .toList();
    _toAccountId = others.isNotEmpty ? others.first.id : null;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Account? get _fromAccount => _accountService.getAccountById(_fromAccountId);
  Account? get _toAccount => _toAccountId != null
      ? _accountService.getAccountById(_toAccountId!)
      : null;

  bool get _hasEnoughAccounts => _accountService.accounts.length >= 2;

  void _swapAccounts() {
    if (_toAccountId == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      final oldFrom = _fromAccountId;
      _fromAccountId = _toAccountId!;
      _toAccountId = oldFrom;
      _errorMessage = null;
    });
  }

  Future<void> _pickAccount({required bool isFrom}) async {
    final excludeId = isFrom ? _toAccountId : _fromAccountId;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AccountPickerSheet(
        accounts: _accountService.accounts,
        excludeId: excludeId,
        selectedId: isFrom ? _fromAccountId : _toAccountId,
        title: isFrom ? 'Transferir desde' : 'Transferir hacia',
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _fromAccountId = selected;
        if (_toAccountId == selected) _toAccountId = null;
      } else {
        _toAccountId = selected;
      }
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final toId = _toAccountId;
    if (toId == null) {
      setState(() => _errorMessage = 'Selecciona la cuenta de destino.');
      return;
    }
    if (toId == _fromAccountId) {
      setState(
        () => _errorMessage =
            'La cuenta de origen y destino no pueden ser la misma.',
      );
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0;

    HapticFeedback.mediumImpact();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _transactionService.createTransfer(
        fromAccountId: _fromAccountId,
        toAccountId: toId,
        amount: amount,
        date: DateTime.now(),
        note: _noteController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const AppBackButton(),
        title: const Text(
          'Nueva transferencia',
          style: TextStyle(color: textDark, fontWeight: FontWeight.w700),
        ),
      ),
      body: _hasEnoughAccounts ? _buildForm() : _buildNotEnoughAccounts(),
    );
  }

  Widget _buildNotEnoughAccounts() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_outlined,
              size: 56,
              color: textMedium.withOpacity(0.5),
            ),
            const SizedBox(height: 20),
            const Text(
              'Necesitas al menos 2 cuentas',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Una transferencia mueve dinero entre dos cuentas propias. '
              'Crea otra cuenta para poder transferir.',
              style: TextStyle(fontSize: 14, color: textMedium, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: 'Gestionar cuentas',
              icon: Icons.add,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageAccountsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildErrorBanner(),
          _buildSectionLabel('Desde'),
          const SizedBox(height: 10),
          _buildAccountCard(
            account: _fromAccount,
            balance: _transactionService.balanceForAccount(_fromAccountId),
            onTap: () => _pickAccount(isFrom: true),
          ),
          Center(
            child: IconButton(
              onPressed: _swapAccounts,
              icon: const Icon(Icons.swap_vert_rounded),
              color: primaryBlue,
              style: IconButton.styleFrom(
                backgroundColor: primaryBlue.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          _buildSectionLabel('Hacia'),
          const SizedBox(height: 10),
          _buildAccountCard(
            account: _toAccount,
            balance: _toAccountId != null
                ? _transactionService.balanceForAccount(_toAccountId!)
                : null,
            onTap: () => _pickAccount(isFrom: false),
            placeholder: 'Selecciona la cuenta destino',
          ),
          const SizedBox(height: 24),
          _buildSectionLabel('Monto a transferir'),
          const SizedBox(height: 10),
          _buildAmountField(),
          const SizedBox(height: 24),
          _buildSectionLabel('Nota (opcional)'),
          const SizedBox(height: 10),
          TextFormField(
            controller: _noteController,
            maxLength: 60,
            decoration: InputDecoration(
              hintText: 'Ej. Ahorro del mes',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: primaryBlue, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textMedium,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    if (_errorMessage == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: dangerRed.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dangerRed.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: dangerRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 13,
                color: dangerRed,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard({
    required Account? account,
    required double? balance,
    required VoidCallback onTap,
    String placeholder = 'Selecciona una cuenta',
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: account == null
            ? Row(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    color: textMedium.withOpacity(0.6),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    placeholder,
                    style: const TextStyle(color: textMedium, fontSize: 14),
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: account.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        account.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (balance != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Saldo: ${FormatUtils.formatMoney(balance)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: textMedium,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: textMedium),
                ],
              ),
      ),
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        // Primero: convierte la coma decimal en punto (ver su doc).
        const AmountInputFormatter(),
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
        LengthLimitingTextInputFormatter(13),
      ],
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: primaryBlue,
      ),
      decoration: InputDecoration(
        hintText: FormatUtils.amountHint(),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.all(18),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Ingresa un monto';
        final amount = double.tryParse(value);
        if (amount == null || !amount.isFinite || amount <= 0) {
          return 'El monto debe ser mayor a ${FormatUtils.amountHint()}';
        }
        if (amount > 999999999.99)
          return 'El monto máximo es ${FormatUtils.currencySymbol}999.999.999,99';
        return null;
      },
    );
  }

  Widget _buildSubmitButton() {
    return AppPrimaryButton(
      label: 'Transferir',
      icon: Icons.swap_horiz_rounded,
      loading: _isSubmitting,
      onPressed: _isSubmitting ? null : _submit,
    );
  }
}

class _AccountPickerSheet extends StatelessWidget {
  final List<Account> accounts;
  final String? excludeId;
  final String? selectedId;
  final String title;

  const _AccountPickerSheet({
    required this.accounts,
    required this.excludeId,
    required this.selectedId,
    required this.title,
  });

  static const Color textDark = AppColors.textDark;
  static const Color borderLight = AppColors.borderLight;

  @override
  Widget build(BuildContext context) {
    final options = accounts.where((a) => a.id != excludeId).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textDark,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final account = options[index];
                  final isSelected = account.id == selectedId;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context, account.id);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? account.color.withOpacity(0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? account.color.withOpacity(0.4)
                              : borderLight,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: account.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                account.emoji,
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              account.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: account.color,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
