import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/manage_accounts_screen.dart';
import 'screens/splash_screen.dart';
import 'services/account_service.dart';
import 'services/onboarding_service.dart';
import 'services/security_service.dart';
import 'services/region_service.dart';
import 'models/region.dart';
import 'theme/app_colors.dart';
import 'utils/app_info.dart';

void main() async {
  try {
    // Asegurar que los bindings estén inicializados
    WidgetsFlutterBinding.ensureInitialized();

    // Configurar orientación de pantalla
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // Configurar la barra de estado
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // Inicializar sistema de cuentas y migrar datos existentes
    final accountService = AccountService();
    await accountService.loadAccounts();
    await accountService.migrateExistingData();

    // Cargar preferencias de seguridad (bloqueo, biometría, saldos ocultos)
    await SecurityService().init();

    // Cargar región/moneda activa (Ecuador por defecto)
    await RegionService().load();

    // Saber si ya se vio el tutorial de bienvenida (solo primera apertura)
    await OnboardingService().load();

    runApp(const AhorroApp());
  } catch (e) {
    // En caso de error, ejecutar la app básica
    runApp(const AhorroApp());
  }
}

class AhorroApp extends StatelessWidget {
  const AhorroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RegionService(),
      builder: (context, child) {
        final region = RegionService().current;
        return MaterialApp(
          title: AppInfo.name,
          debugShowCheckedModeBanner: false,

          // Configuración de localización
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es', 'EC'), // Español Ecuador
            Locale('es', 'CO'), // Español Colombia
            Locale('es', 'ES'), // Español España
            Locale('en', 'US'), // Inglés (fallback)
          ],
          locale: Locale(region.languageCode, region.countryCode),

          theme: ThemeData(
            // Colores principales
            primarySwatch: Colors.blue,
            primaryColor: AppColors.primaryBlue,

            // Configuración de colores
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primaryBlue,
              brightness: Brightness.light,
            ),

            // Tipografía mejorada
            textTheme: const TextTheme(
              headlineLarge: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
                letterSpacing: -0.5,
              ),
              headlineMedium: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
                letterSpacing: -0.5,
              ),
              titleLarge: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
              bodyLarge: TextStyle(fontSize: 16, color: AppColors.textDark),
              bodyMedium: TextStyle(fontSize: 14, color: AppColors.textMedium),
            ),

            // AppBar personalizado
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              systemOverlayStyle: SystemUiOverlayStyle.light,
            ),

            // Botones modernos — mismo radio/alto/peso de texto que
            // AppPrimaryButton (lib/widgets/common/app_primary_button.dart),
            // para que un ElevatedButton "de fábrica" ya salga consistente.
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),

            // Cards modernas
            cardTheme: const CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Colors.white,
            ),

            // Inputs modernos
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: AppColors.backgroundCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
              ),
              contentPadding: const EdgeInsets.all(20),
            ),

            // SnackBar moderna
            snackBarTheme: SnackBarThemeData(
              backgroundColor: AppColors.textDark,
              contentTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              behavior: SnackBarBehavior.floating,
            ),

            useMaterial3: true,
          ),
          home: const SplashScreen(),
          routes: {
            '/manage-accounts': (context) => const ManageAccountsScreen(),
          },
        );
      },
    );
  }
}
