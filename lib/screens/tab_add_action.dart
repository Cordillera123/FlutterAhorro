import 'package:flutter/material.dart';

/// Pestaña principal que sabe crear "lo suyo" (un presupuesto, una meta, un
/// gasto automático...) cuando se toca el botón flotante "Agregar".
///
/// El botón flotante vive en `MainNavigationScreen` y es el mismo en las
/// cinco pestañas; cada pestaña que implementa esto conserva su propio flujo
/// de creación (validación de límites, pantalla de alta y refresco posterior)
/// y el botón solo se lo pide.
abstract interface class TabAddActionHost {
  /// Inicia la creación propia de la pestaña.
  void onAddPressed();
}

/// Marca el contenido de las pestañas de `MainNavigationScreen`.
///
/// Metas, Gastos automáticos e Historial también se abren como pantallas
/// sueltas (menú lateral, recordatorios, "Ver todo"). Ahí no existe el botón
/// flotante global ni la barra inferior, así que cada pantalla pregunta con
/// [isHosted] si debe mostrar su propio botón "Agregar" y su flecha de volver.
class TabHostScope extends InheritedWidget {
  const TabHostScope({super.key, required super.child});

  /// `true` si [context] está dentro de una pestaña de la navegación
  /// principal; `false` si la pantalla se abrió por su cuenta.
  static bool isHosted(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TabHostScope>() != null;

  @override
  bool updateShouldNotify(TabHostScope oldWidget) => false;
}
