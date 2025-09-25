import 'package:flutter/material.dart';
import 'widgets/app_logo.dart';

void main() {
  runApp(const LogoTestApp());
}

class LogoTestApp extends StatelessWidget {
  const LogoTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prueba del Logo',
      home: const LogoTestScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LogoTestScreen extends StatelessWidget {
  const LogoTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prueba del Widget AppLogo'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Logo Pequeño (sin texto)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            AppLogo.small(),
            
            SizedBox(height: 32),
            Divider(),
            SizedBox(height: 32),
            
            Text(
              'Logo Mediano (con texto)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            AppLogo.medium(),
            
            SizedBox(height: 32),
            Divider(),
            SizedBox(height: 32),
            
            Text(
              'Logo Grande (animado)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            AppLogo.large(),
            
            SizedBox(height: 32),
            Divider(),
            SizedBox(height: 32),
            
            Text(
              'Logo para Splash (con fondo)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: AppLogo.splash(),
            ),
            
            SizedBox(height: 32),
            Divider(),
            SizedBox(height: 32),
            
            Text(
              'Logo Loading (con animaciones)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: AppLogoLoading(),
            ),
          ],
        ),
      ),
    );
  }
}