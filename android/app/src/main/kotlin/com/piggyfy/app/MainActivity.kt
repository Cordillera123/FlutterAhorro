package com.piggyfy.app

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (no FlutterActivity) es requerido por local_auth
// para poder mostrar el diálogo nativo de biometría/PIN del sistema.
class MainActivity : FlutterFragmentActivity()
