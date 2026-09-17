import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/account.dart';
import '../services/account_service.dart';
import '../theme/app_colors.dart';

/// Widget selector de cuentas que se muestra en el AppBar de HomeScreen.
/// Permite cambiar rápidamente la cuenta activa.
class AccountSelectorButton extends StatelessWidget {
  final VoidCallback? onTap;

  const AccountSelectorButton({super.key, this.onTap});

  static const Color textDark = AppColors.textDark;

  @override
  Widget build(BuildContext context) {
    final accountService = AccountService();
    final account = accountService.activeAccount;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap!();
        } else {
          showAccountSelectorSheet(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              account.emoji,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                account.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// Muestra un bottom sheet para seleccionar la cuenta activa
void showAccountSelectorSheet(BuildContext context) {
  final accountService = AccountService();

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return _AccountSelectorSheet(accountService: accountService);
    },
  );
}

class _AccountSelectorSheet extends StatelessWidget {
  final AccountService accountService;

  const _AccountSelectorSheet({required this.accountService});

  static const Color primaryBlue = AppColors.primaryBlue;
  static const Color textDark = AppColors.textDark;
  static const Color textMedium = AppColors.textMedium;
  static const Color borderLight = AppColors.borderLight;
  static const Color successGreen = AppColors.primaryGreen;

  @override
  Widget build(BuildContext context) {
    final accounts = accountService.accounts;
    final activeId = accountService.activeAccountId;

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
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [primaryBlue, Color(0xFF1D4ED8)],
                    ),
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seleccionar Cuenta',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Cambia entre tus cuentas financieras',
                        style: TextStyle(
                          fontSize: 14,
                          color: textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Lista de cuentas
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: accounts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  final isActive = account.id == activeId;

                  return _buildAccountTile(
                    context,
                    account: account,
                    isActive: isActive,
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Botón para gestionar cuentas
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/manage-accounts');
                },
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Gestionar Cuentas'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryBlue,
                  side: BorderSide(color: primaryBlue.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountTile(
    BuildContext context, {
    required Account account,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        if (!isActive) {
          await accountService.setActiveAccount(account.id);
        }
        if (context.mounted) Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive
              ? account.color.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? account.color.withValues(alpha: 0.3)
                : borderLight,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Emoji
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: account.color.withValues(alpha: 0.12),
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

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isActive ? account.color : textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    account.typeName,
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive
                          ? account.color.withValues(alpha: 0.7)
                          : textMedium,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Check de activo
            if (isActive)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: account.color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),

            // Indicador por defecto
            if (account.isDefault && !isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Principal',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
