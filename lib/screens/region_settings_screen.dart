import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/region.dart';
import '../services/region_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_refresh.dart';
import '../utils/format_utils.dart';
import '../widgets/common/common.dart';

/// Pantalla de Configuración > Región y moneda: elige el país que define
/// el formato de números del sistema y la moneda usada en toda la app. No
/// afecta los montos guardados — solo cómo se muestran (no se convierten).
class RegionSettingsScreen extends StatefulWidget {
  const RegionSettingsScreen({super.key});

  @override
  State<RegionSettingsScreen> createState() => _RegionSettingsScreenState();
}

class _RegionSettingsScreenState extends State<RegionSettingsScreen> {
  final RegionService _regionService = RegionService();

  /// Monto de ejemplo con el que cada fila muestra cómo se verán los números.
  static const double _sampleAmount = 1234.5;

  Future<void> _onSelectRegion(Region region) async {
    final current = _regionService.current;
    if (region == current) return;

    // Cambiar a otra MONEDA (no solo de país con la misma moneda) puede
    // confundir si no se sabe que los montos no se convierten: se avisa.
    if (region.currencyCode != current.currencyCode) {
      final confirmed = await showAppConfirmDialog(
        context,
        title: '¿Cambiar a ${region.currencyName}?',
        message:
            'Los montos que ya registraste NO se convierten: un gasto de '
            '10 pasará a mostrarse como '
            '${FormatUtils.formatMoneyIn(region, 10)}. '
            'Cambia solo cómo se ven los montos.',
        confirmLabel: 'Cambiar',
        icon: Icons.currency_exchange_rounded,
        accentColor: AppColors.primaryBlue,
      );
      if (confirmed != true || !mounted) return;
    }

    HapticFeedback.selectionClick();
    await _regionService.setRegion(region);
    // Refresca las pantallas ya construidas para que muestren la nueva moneda.
    rebuildEntireApp();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final current = _regionService.current;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const AppBackButton(),
        title: const Text(
          'Región y moneda',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Define la moneda y cómo se escriben los montos en toda la app. '
            'No cambia el dinero que ya registraste ni lo convierte, solo '
            'su formato.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              children: Region.values.map((region) {
                final isLast = region == Region.values.last;
                final selected = region == current;
                return AppListTile(
                  emoji: region.flagEmoji,
                  title: region.displayName,
                  subtitle:
                      '${region.currencyName} (${region.currencyCode}) · '
                      '${FormatUtils.formatMoneyIn(region, _sampleAmount)}',
                  onTap: () => _onSelectRegion(region),
                  trailing: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    color: selected
                        ? AppColors.primaryBlue
                        : Colors.grey.shade300,
                    size: 24,
                  ),
                  showDivider: !isLast,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
