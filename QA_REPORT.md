# QA Report — FlutterAhorro (ahorro_app)

**Fecha:** 2026-09-17
**Alcance:** 25 pantallas (`lib/screens/`), widgets reutilizables (`lib/widgets/`), servicios de dashboard/analizadores, y utilidades de formato/exportación. Revisión de código guiada por los patrones de riesgo pedidos (overflow, hardcodeos, SafeArea, contraste/consistencia de color, estados de carga/vacío, validación de formularios, refresco de estado) + validación visual en vivo (Flutter Web, viewport 375×812) para las pantallas de mayor tráfico (Inicio, Agregar Transacción, Logros).
**Verificación de fixes previos:** de los 3 documentos de correcciones previas (overflow en gráficos, reinicio automático de presupuestos, múltiples presupuestos/pausados, integración de gastos recurrentes), **2 de 3 siguen intactos** y **1 tiene una regresión activa** (ver Crítico #3).

---

## Checklist priorizada

### 🔴 Crítico
- [x] 1. `parseAmount`/prefill de edición no manejaban el formato de moneda (es_CO) → fallaba al **editar** presupuestos/metas/gastos recurrentes ≥ $1.000 — **corregido** (ver diagnóstico actualizado abajo)
- [x] 2. `showDatePicker` podía **crashear** al editar un gasto recurrente con fecha de inicio > 30 días — **corregido**
- [x] 3. Gráfico de barras de `monthly_history_screen.dart` podía desbordar su contenedor — **corregido**
- [x] 4. Eliminar una cuenta **no borraba sus transacciones/presupuestos/metas** — **corregido** (ahora sí se borran, según tu decisión)
- [x] 5. El FAB "Agregar" tapaba contenido interactivo en Inicio — **corregido** (Historial ya tenía suficiente espacio, no tenía el bug)
- [x] 6. La flecha de retroceso se superponía al título en "Agregar/Editar Ingreso/Gasto" — **corregido**

### 🟡 Moderado
- [x] 7. Etiqueta "Presupuestos" truncada a "Presupues…" en el nav inferior — **corregido** (ahora se auto-ajusta con `FittedBox`)
- [x] 8. `MessageTraceSheet` podía desbordar horizontalmente — **corregido**
- [x] 9. Reinicio automático de presupuestos solo se disparaba el día exacto del reinicio — **corregido** (según tu decisión)
- [x] 10. Doble-tap podía duplicar un aporte a una meta — **corregido**
- [x] 11. Contador de metas ("X/15") no coincidía con el límite real de creación — **corregido** (según tu decisión)
- [x] 12. Gastos recurrentes con categoría personalizada generaban falsos positivos de "impacto en presupuesto" — **corregido**
- [x] 13. Límite de monto de presupuesto/gasto ($999.999,99) poco realista para COP — **corregido** (según tu decisión, ahora $999.999.999,99; extendido también a transacciones normales por consistencia)
- [x] 14. `excel_formatter.dart` podía lanzar `RangeError` si un monto es `NaN`/`Infinity` — **corregido**
- [x] 15. Fondo de pantalla (`backgroundLight`) inconsistente entre pestañas del nav inferior — **corregido**
- [x] 16. Botón "Crear categoría" sin estado de carga — **corregido**
- [x] 17. Botón "Ver todas" (transacciones recientes, Inicio) no hacía nada — **corregido**
- [x] 18. Vista previa de monto en Agregar Transacción no usaba el formateador de la app — **corregido**
- [ ] 19. Cabecera de Historial: 4 íconos fijos pueden dejar sin espacio al título "Historial" en phones pequeños — **no corregido** (requiere rediseñar la cabecera; ver recomendación)
- [x] 20. Monto de transacción en Historial sin protección de overflow — **corregido**
- [x] 21. Cabecera de `monthly_history_screen.dart` podía desbordar en dispositivos con notch grande — **corregido** (más margen de aire)
- [x] 22. Estado de error de Logros indistinguible del estado "sin logros" — **corregido**
- [x] 23. Exportar no mostraba confirmación de éxito al terminar — **corregido**
- [x] 24. Confirmación de "pausar meta" implementada pero nunca conectada (código muerto) — **corregido** (eliminado el código muerto; el botón real sigue sin confirmación, no lo cambié por ser una decisión de UX no consultada)
- [x] 25. `main_screen.dart` duplicado huérfano — **eliminado** (según tu decisión)

### 🟢 Cosmético
- [ ] 26. Verde de Inicio/Splash (#4CAF50) distinto al verde del resto de la app (#059669) — **no corregido**, ver recomendación
- [x] 27. Color de "gasto" distinto entre Inicio (#FF7043) e Historial (#DC2626) — **corregido**
- [x] 28. Colores sueltos fuera de la paleta (settings, manage_categories, create_budget) — **corregido**
- [x] 29. Insignia "Nivel 0/6" confusa en logros bloqueados — **corregido**
- [x] 30. `borderLight` distinto en `monthly_history_screen.dart` — **corregido**
- [ ] 31. Secciones del dashboard sin mensaje cuando están vacías — **no corregido**, ver recomendación
- [x] 32. Monto en `calendar_day_sheet.dart` sin `Flexible` — **corregido**
- [x] 33. Columna de monto/porcentaje por categoría en Estadísticas sin protección de overflow — **corregido**
- [x] 34. `Budget.getStatus` sin guarda para monto = 0 — **corregido**
- [ ] 35. Colores de marca redeclarados en 15+ archivos en vez de un tema compartido — **no corregido** (cambio arquitectónico, requiere tu aprobación explícita — no toqué la arquitectura general)
- [ ] 36. Logs de depuración (`print` con emojis) en getters llamados en cada rebuild — **no corregido**, ver recomendación

---

## Detalle de hallazgos

### 🔴 Crítico

#### 1. ~~`parseAmount` no puede leer el formato que produce `formatMoney`~~ — [FIX APLICADO ✅]
- **Archivo:** [lib/utils/format_utils.dart](lib/utils/format_utils.dart), [lib/screens/create_budget_screen.dart:124](lib/screens/create_budget_screen.dart#L124), [lib/screens/add_recurring_expense_screen.dart:79,122-126](lib/screens/add_recurring_expense_screen.dart#L79), [lib/screens/create_goal_screen.dart:157](lib/screens/create_goal_screen.dart#L157)
- **Categoría:** funcional
- **Diagnóstico inicial vs. real:** mi primera hipótesis fue que `parseAmount()` (que quita `$`, `,` y espacios) no invertía correctamente el formato de `formatMoney()` (es_CO: `.` miles, `,` decimal). **Al investigar más, encontré que ese "fix" habría roto el flujo de creación**: el campo de monto usa un `inputFormatter` (`RegExp(r'^\d*\.?\d{0,2}')`) que solo acepta escritura en formato plano US (`.` como decimal, sin agrupar miles) — nunca se escribe en formato es_CO. El bug real es más específico: al **editar** un presupuesto/gasto recurrente existente, el campo se pre-rellenaba con `FormatUtils.formatMoney(budget.amount)` (formato es_CO agrupado, ej. `"$1.234.567,89"`), que ni el parser ni el formateador de escritura en vivo pueden interpretar → el monto se guardaba como `$0.00` o se rechazaba la validación.
- **Fix aplicado:** dejé `parseAmount()` intacto (evita romper la creación) y corregí los 3 puntos donde se pre-rellenaba el campo, para que usen texto plano (`budget.amount.toStringAsFixed(2)`) en vez de `formatMoney()`. También corregí el hint de metas ("Ej. 1.500.000" → "Ej. 1500000"), ya que su propio parser (`_parseNumber`) tampoco podía leer el formato agrupado que sugería.

#### 2. Selector de fecha puede crashear al editar un gasto recurrente antiguo
- **Archivo:** [lib/screens/add_recurring_expense_screen.dart:1085-1112](lib/screens/add_recurring_expense_screen.dart#L1085)
- **Categoría:** funcional
- **Descripción:** `_selectStartDate()` fija `firstDate: DateTime.now().subtract(Duration(days: 30))` pero usa `initialDate: _startDate`. Si se edita un gasto recurrente cuya fecha de inicio es de hace más de 30 días (el caso normal para una suscripción antigua), `initialDate` queda antes que `firstDate`, lo que viola la precondición de `showDatePicker` y lanza un assertion error.
- **Fix sugerido:**
  ```dart
  firstDate: _startDate.isBefore(DateTime.now().subtract(const Duration(days: 30)))
      ? _startDate
      : DateTime.now().subtract(const Duration(days: 30)),
  ```

#### 3. Gráfico mensual de ingresos/gastos puede desbordar su contenedor
- **Archivo:** [lib/screens/monthly_history_screen.dart:399-436](lib/screens/monthly_history_screen.dart#L399)
- **Categoría:** regresión
- **Descripción:** Esta es la misma clase de bug documentada como "resuelta" en `CORRECCIONES_OVERFLOW_FINAL.md`, pero ese documento describe cambios en `stats_screen.dart`, mientras que el gráfico de barras dobles (ingreso + gasto apiladas) hoy vive en `monthly_history_screen.dart` y **no tiene el fix**. `_buildMonthBar` apila una barra de ingreso (0-100px) + gap + barra de gasto (0-100px) + gap + etiqueta, todo dentro de un `SizedBox(height: 140)`. Cuando ambos valores de un mes están cerca del máximo del set de datos (común: el mes de mayor ingreso suele tener también gasto alto), la suma puede llegar a ~220px contra un presupuesto de 140px → overflow visible.
- **Fix sugerido:** escalar ambas barras proporcionalmente para que su suma nunca exceda el alto disponible:
  ```dart
  const chartHeight = 140.0, labelHeight = 14.0, gaps = 9.0;
  final budget = chartHeight - labelHeight - gaps;
  final rawIncome = maxAmount > 0 ? (month.income / maxAmount) * budget : 0.0;
  final rawExpense = maxAmount > 0 ? (month.expenses / maxAmount) * budget : 0.0;
  final scale = (rawIncome + rawExpense) > budget ? budget / (rawIncome + rawExpense) : 1.0;
  final incomeHeight = rawIncome * scale;
  final expenseHeight = rawExpense * scale;
  ```

#### 4. Eliminar una cuenta no elimina sus transacciones (contradice el aviso al usuario)
- **Archivo:** [lib/screens/manage_accounts_screen.dart:804-818](lib/screens/manage_accounts_screen.dart#L804), [lib/services/account_service.dart:225-251](lib/services/account_service.dart#L225)
- **Categoría:** funcional
- **Descripción:** El diálogo de confirmación advierte "Los datos asociados (transacciones, presupuestos, metas) se perderán permanentemente", pero `AccountService.deleteAccount` solo quita la cuenta de la lista — nunca llama a `TransactionService.clearTransactionsForAccount` (que existe en `transaction_service.dart:207` pero no se invoca desde ningún lado). Las transacciones de la cuenta eliminada quedan huérfanas y terminan reasignándose silenciosamente a la cuenta activa en la siguiente carga, inflando su saldo sin que el usuario lo note.
- **Necesita decisión de producto antes de aplicar el fix** (ver sección de preguntas al final): ¿el comportamiento correcto es borrar esas transacciones (como promete el diálogo) o reasignarlas a otra cuenta (como se hace hoy con categorías eliminadas)?

#### 5. El FAB "Agregar" tapa contenido interactivo en Inicio e Historial
- **Archivo:** [lib/screens/home_screen.dart:229](lib/screens/home_screen.dart#L229) (y el mismo patrón en [lib/screens/history_screen.dart:241](lib/screens/history_screen.dart#L241))
- **Categoría:** visual — **confirmado visualmente** (capturas adjuntas en la conversación)
- **Descripción:** El `FloatingActionButton.extended` se define en el `Scaffold` padre (`main_navigation_screen.dart`, `floatingActionButtonLocation: centerFloat`) y flota sobre el `PageView` completo. `home_screen.dart` no sabe que ese FAB existe: su `Padding` de contenido usa `EdgeInsets.fromLTRB(20, 8, 20, 24)` — solo 24px de aire al final —, insuficiente para los ~90-100px que ocupa el FAB + su margen. Resultado: la última fila de "Acciones Rápidas" (tarjeta "Exportar", y "Estadísticas") queda parcialmente tapada permanentemente por el botón, incluso hecho scroll hasta el final.
- **Fix sugerido:** aumentar el padding inferior del contenido a ~100px en ambas pantallas cuando el FAB está visible:
  ```dart
  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
  ```

#### 6. La flecha de retroceso se superpone al título en Agregar/Editar Transacción
- **Archivo:** [lib/screens/add_transaction_screen.dart:192-275](lib/screens/add_transaction_screen.dart#L192)
- **Categoría:** visual — **confirmado visualmente**
- **Descripción:** El `SliverAppBar` no define `leading` ni `automaticallyImplyLeading: false`, así que Flutter inserta automáticamente una flecha de retroceso en la esquina superior izquierda. El contenido personalizado del header (título "Agregar Ingreso"/"Agregar Gasto") empieza con solo 16px de padding superior dentro del `SafeArea`, en la misma franja donde Flutter dibuja la flecha automática — el resultado es que la flecha queda literalmente encima de la "A" del título. El resto de la app (`manage_accounts_screen.dart`, `export_screen.dart`, `create_goal_screen.dart`, etc.) resuelve esto definiendo un `leading` explícito y bajando el contenido ~56px.
- **Fix sugerido:** aplicar el mismo patrón ya usado en el resto de la app.

---

### 🟡 Moderado (resumen — ver también el detalle completo en el análisis de cada agente)

| # | Pantalla/archivo | Descripción | Sugerencia |
|---|---|---|---|
| 7 | `main_navigation_screen.dart` (`_buildNavItem`) | "Presupuestos" se trunca a "Presupues…" a 11sp en una pestaña de 5 | Reducir a "Presup." o bajar a 9-10sp solo para esa etiqueta, o permitir 2 líneas |
| 8 | `lib/widgets/dashboard/message_trace_sheet.dart:82-95` | Filas label/valor sin `Expanded`/`Flexible` → overflow con montos largos; se usa desde todas las alertas/logros | Envolver label en `Expanded`, valor en `Flexible` + ellipsis |
| 9 | `lib/models/budget.dart:179-209` | Reinicio solo se evalúa si `now.weekday==Monday`/`now.day==1` exactamente ese día | Cambiar a `DateTime.now().isAfter(endDate)` |
| 10 | `lib/screens/goals_screen.dart:1218-1267` | Sin estado de carga en "Aportar" → doble-tap duplica el aporte | Flag `isSubmitting` + deshabilitar botón |
| 11 | `lib/screens/goals_screen.dart:604-613` vs `goal_service.dart:34` | Contador visible excluye completadas/canceladas; el límite real las cuenta | Unificar el criterio de conteo |
| 12 | `lib/services/recurring_expense_service.dart:146-289` | Categorías personalizadas no se excluyen del match presupuesto↔gasto recurrente | Excluir presupuestos con `hasCustomCategory` |
| 13 | `create_budget_screen.dart:492`, `add_recurring_expense_screen.dart:281` | Tope de $999.999,99 poco realista en COP | Subir el tope (ej. $999.999.999) |
| 14 | `lib/utils/excel_formatter.dart:163-182` | `RangeError` si el monto es `NaN`/`Infinity` | Guard `if (!amount.isFinite) return '\$0.00';` |
| 15 | `budget_screen.dart:39`, `goals_screen.dart:38`, `manage_accounts_screen.dart:30`, `home_screen.dart:208` vs el resto | Fondo `F8FAFC` en 4 pantallas vs `F1F5F9` en el resto — salto de color visible al deslizar entre pestañas | Unificar a `0xFFF1F5F9` en todas |
| 16 | `add_transaction_screen.dart:1255-1308` | "Crear categoría" sin estado de carga → doble-tap duplica categorías | Flag `isCreating` + deshabilitar botón |
| 17 | `home_screen.dart:1518-1523` | "Ver todas" solo da feedback háptico, no navega (TODO pendiente) | Navegar a `HistoryScreen` |
| 18 | `add_transaction_screen.dart:1617-1624` | Preview usa `toStringAsFixed(2)` en vez de `FormatUtils.formatMoney` | Usar el formateador compartido |
| 19 | `history_screen.dart:241-307` | 4 íconos fijos (200px+) dejan poco espacio al título en phones de 320-360px | Mover acciones secundarias a un menú, o usar `LayoutBuilder` |
| 20 | `history_screen.dart:901-914` | Monto sin `FittedBox` (sí lo tiene en `home_screen.dart`) | Envolver en `FittedBox(fit: BoxFit.scaleDown)` |
| 21 | `monthly_history_screen.dart:139,171-176` | `expandedHeight:140` + padding superior fijo de 70px puede no alcanzar con notch grande | Reducir el padding fijo (SafeArea ya cubre el notch) |
| 22 | `achievements_screen.dart:55-69,120-131` | Error de carga se muestra igual que "sin logros" | Agregar estado de error con botón "Reintentar" (como `financial_insights_screen.dart`) |
| 23 | `export_screen.dart:215-236` | Sin SnackBar de éxito tras exportar | Mostrar confirmación al finalizar sin error |
| 24 | `goals_screen.dart:1274-1398` | `_pauseGoal()` (con confirmación) existe pero nunca se llama; el botón real no confirma nada | Conectar el diálogo o eliminar el método muerto |
| 25 | `lib/screens/main_screen.dart` (archivo completo) | Duplicado huérfano de `main_navigation_screen.dart`, no importado, con lógica de FAB ya divergente | Eliminar el archivo |

---

### 🟢 Cosmético (resumen)

| # | Archivo | Descripción |
|---|---|---|
| 26 | `splash_screen.dart`, `home_screen.dart` | Verde `#4CAF50` distinto al `primaryGreen` (`#059669`) usado en el resto de la app |
| 27 | `home_screen.dart` vs `history_screen.dart` | Color de "gasto" distinto (`#FF7043` vs `#DC2626`) para el mismo dato |
| 28 | `settings_screen.dart:90`, `manage_categories_screen.dart:812-846`, `create_budget_screen.dart:62` | Colores sueltos fuera de la paleta slate/blue/green/purple |
| 29 | `lib/widgets/dashboard/achievement_card.dart:71,125-146` | Insignia "Nivel 0/6" en logros por niveles bloqueados (confuso) |
| 30 | `monthly_history_screen.dart:23` | `borderLight` (`#E2E8F0`) distinto al resto (`#E5E7EB`) |
| 31 | `alerts_section.dart`, `forecasts_section.dart`, `observations_section.dart`, `opportunities_section.dart` | Sin mensaje cuando no hay datos — el dashboard puede verse "roto" si todas están vacías a la vez |
| 32 | `lib/widgets/calendar/calendar_day_sheet.dart:326-334` | Monto sin `Flexible` (bajo riesgo) |
| 33 | `stats_screen.dart:903-924` | Columna de monto/% sin protección de overflow (sí la tiene en `charts_screen.dart`) |
| 34 | `lib/models/budget.dart:255-262` | `getStatus` sin guarda para `amount == 0` (inconsistente con `dashboard_snapshot.dart:81-84`) |
| 35 | 15+ archivos | Colores de marca redeclarados por archivo en vez de un tema compartido — causa raíz de los ítems 15, 26-28, 30 |
| 36 | Toda la app (getters de `TransactionService`) | `print()` con emojis en getters llamados en cada rebuild — ruido de consola |

---

## Verificación de fixes previamente documentados

| Fix documentado | Archivo(s) originales | Estado actual |
|---|---|---|
| Overflow 212px en info de categoría seleccionada | `pie_chart_widget.dart` | ✅ **Sigue resuelto**, aunque por un mecanismo distinto al documentado: hoy es un `showModalBottomSheet` con `SingleChildScrollView` + `FittedBox`, no los métodos `_buildCompactInfoItem()` que describía el documento (no existen en el código actual) |
| Overflow 1.8px en gráfico mensual | `stats_screen.dart` | ⚠️ **`_buildMonthlyChart`/`_buildMonthBar` ya no existen en `stats_screen.dart`** — esa funcionalidad se movió a `monthly_history_screen.dart`, donde el problema de fondo (barras que pueden exceder su contenedor) **no está resuelto** (ver Crítico #3) |
| Reinicio automático de presupuestos | `budget.dart`, `budget_service.dart` | ✅ **Sigue resuelto** para el cálculo de fechas (fin de mes, año bisiesto, diciembre→enero), pero con un gap de comportamiento (ver Moderado #9) |
| Múltiples presupuestos + pausados visibles | `budget_service.dart`, `budget_screen.dart` | ✅ **Sigue resuelto** — `activeBudgets` devuelve todos los no pausados y los pausados se muestran atenuados, no ocultos |
| Integración gastos recurrentes ↔ presupuestos | `recurring_expense_service.dart`, `recurring_expenses_screen.dart` | ✅ **Sigue resuelto** a nivel de superficie (existe `getBudgetImpactSummary()` y se muestra la sección), con una brecha en categorías personalizadas (ver Moderado #12) |

---

## Preguntas antes de tocar lógica de negocio

Antes de aplicar los fixes que cambian comportamiento (no solo visual/UX), necesito tu decisión en estos puntos:

1. **Eliminar cuenta (Crítico #4):** ¿borro las transacciones de la cuenta eliminada (como promete el diálogo actual), o las reasigno a otra cuenta (como se hace hoy con categorías eliminadas)?
2. **Reinicio de presupuestos (Moderado #9):** ¿cambio la condición a "si ya pasó la fecha de fin" (se corrige apenas se abra la app, cualquier día) en vez de exigir que se abra exactamente el lunes/día 1?
3. **Límite de metas (Moderado #11):** ¿el límite de 15 debe contar solo metas activas/pausadas (lo que ya se le muestra al usuario), o todas incluyendo completadas/canceladas (el comportamiento actual del check)?
4. **Tope de monto (Moderado #13):** ¿a cuánto subo el máximo permitido en presupuestos/gastos recurrentes? (hoy es $999.999,99, poco realista en COP)
5. **`main_screen.dart` (Moderado #25):** ¿confirmo que puedo eliminar este archivo? (no está importado por ningún otro archivo, así que no debería romper nada, pero es una eliminación de archivo completo)

Todo lo demás (crítico #1, #2, #3, #5, #6, y todo lo moderado/cosmético restante) son fixes de UI/UX o correcciones de bugs de formato sin ambigüedad de producto — los aplico directamente a continuación y te resumo los cambios.
