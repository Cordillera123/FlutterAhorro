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
