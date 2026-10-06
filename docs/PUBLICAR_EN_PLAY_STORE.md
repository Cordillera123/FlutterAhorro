# Publicar PiggyFy en Google Play (y monetizar con AdMob)

ID de la app (definitivo): `com.piggyfy.app`

> Regla de oro: **nunca compartas** el archivo `.jks`, el archivo
> `android/key.properties` ni sus contraseñas (ni por WhatsApp, ni por correo,
> ni en capturas). Tampoco se las pegues a ningún asistente.

---

## 1. Crear la clave de firma (una sola vez)

Play App Signing (activado por defecto) guarda la clave definitiva de Google;
la que creas aquí es la **clave de subida**. Aun así, guárdala bien.

1. Crea una carpeta fuera del proyecto, por ejemplo `C:\Users\Josue\claves-piggyfy`.
2. Abre PowerShell y ejecuta (te pedirá inventar una contraseña y algunos datos;
   el nombre/organización pueden ser tu nombre):

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v `
  -keystore "C:\Users\Josue\claves-piggyfy\piggyfy-upload.jks" `
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

3. **Haz copia** de `piggyfy-upload.jks` y anota la contraseña en tu gestor de
   contraseñas (o en un lugar offline). Si pierdes ambas, Play puede restablecer
   la clave de subida, pero es un trámite largo.
4. Crea el archivo `android\key.properties` (ya está ignorado por git) con:

```properties
storePassword=LA_CONTRASEÑA_QUE_ELEGISTE
keyPassword=LA_CONTRASEÑA_QUE_ELEGISTE
keyAlias=upload
storeFile=C:/Users/Josue/claves-piggyfy/piggyfy-upload.jks
```

(Usa `/` en la ruta, no `\`.)

## 2. Generar el paquete para subir

```powershell
flutter build appbundle --release
```

Resultado: `build\app\outputs\bundle\release\app-release.aab`. **Ese** es el
archivo que se sube a Play (no el `.apk`). Si al compilar aparece el aviso
"no existe android/key.properties", todavía se está firmando con la clave de
depuración y Play lo rechazará.

Cada vez que subas una versión nueva, aumenta el número después del `+` en
`pubspec.yaml` (`version: 1.0.0+1` → `1.0.1+2`). Ese número no puede repetirse.

## 3. Cuenta de Play Console

1. https://play.google.com/console → crear cuenta de desarrollador
   (pago único de ~25 USD, verificación de identidad con documento).
2. Crear app → nombre **PiggyFy**, idioma español, tipo *App*, *Gratuita*.
3. **Cuentas personales nuevas:** Google suele exigir una **prueba cerrada** con
   un grupo de testers durante ~14 días antes de poder pedir "Acceso a
   producción". Confirma el requisito actual en el panel (Pruebas → Prueba
   cerrada). Mientras tanto puedes usar la "Prueba interna" para probar rápido.

## 4. Política de privacidad (obligatoria)

- Borrador listo en `docs/politica-de-privacidad.md`. Completa tu correo de
  contacto y publícala en una **URL pública** (la forma más fácil y gratuita:
  GitHub Pages, Google Sites o Notion público).
- Pega esa URL en Play Console → Contenido de la app → Política de privacidad.

## 5. Formularios de "Contenido de la app" en Play Console

- **Seguridad de los datos (Data safety):**
  - Los datos financieros que escribe el usuario **se quedan en el dispositivo**
    (no se envían a ningún servidor tuyo).
  - Con AdMob, declara que la app **recopila/comparte** con Google: *ID de
    dispositivo o de publicidad*, *interacciones con anuncios*, *diagnósticos* y
    *ubicación aproximada* (finalidad: **publicidad**). Los datos de AdMob son
    procesados por Google; declara que se comparten con terceros.
- **Anuncios:** marca "Sí, mi app contiene anuncios".
- **Público objetivo:** mayores de 18 / no dirigida a niños (así evitas las
  reglas estrictas de "Familias").
- **Clasificación de contenido:** responde el cuestionario (app de finanzas
  personales, sin contenido sensible).
- **Categoría:** Finanzas. Declara que **no** es una app de préstamos ni
  de banca (solo registra gastos).

## 6. Ficha de la tienda

- Ícono 512×512, gráfico de funciones 1024×500, y mínimo 2 capturas de
  teléfono (idealmente 4–8).
- Textos sugeridos en `docs/ficha-play-store.md`.

## 7. AdMob (anuncios)

1. https://admob.google.com → crear cuenta con tu cuenta Google.
2. *Aplicaciones → Añadir aplicación* → Android → "Todavía no está publicada"
   (o vincúlala cuando ya esté en Play).
3. Copia el **ID de la app** (`ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`).
4. *Bloques de anuncios → Banner* → copia el **ID del bloque**
   (`ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ`).
5. Completa en AdMob los datos de pago e impuestos (obligatorio para cobrar).
6. En AdMob → *Privacidad y mensajes* crea el mensaje de **consentimiento
   (GDPR)** para usuarios del EEE/Reino Unido; la app lo muestra con el SDK de
   consentimiento (UMP).
7. **Nunca** hagas clic en tus propios anuncios reales: AdMob puede suspender la
   cuenta. Mientras pruebas, la app usa IDs de prueba de Google.

### Dónde pegar tus IDs reales (son DOS y deben ser de la misma cuenta)

| ID | Archivo | Qué cambiar |
|---|---|---|
| De la **app** (`ca-app-pub-…~…`) | `android/app/build.gradle.kts` | el valor de `val admobAppId = "…"` |
| Del **banner** (`ca-app-pub-…/…`) | `lib/config/ad_config.dart` | el valor de `_realBannerUnitId = ''` |

Mientras `_realBannerUnitId` esté vacío, **todas** las versiones (incluida la de
release) muestran anuncios de prueba de Google; así puedes probar sin riesgo.
Una prueba automática (`test/ads_test.dart`) falla si pegas un ID de banner real
pero dejas el ID de app de prueba (o de otra cuenta).

Dónde se ve el banner: abajo, debajo de la barra de navegación, solo en
**Inicio** e **Historial**. No aparece en formularios. El botón "Agregar" queda
siempre por encima del banner. Si no hay internet o el usuario no da su
consentimiento, el banner simplemente no ocupa espacio.

### Consentimiento (GDPR / UMP)

La app pide el consentimiento al abrir (solo a usuarios de Europa/Reino Unido
que lo requieren) y, en esos casos, muestra en Configuración → "Privacidad de
anuncios" para que lo cambien. Debes crear el mensaje en AdMob → *Privacidad y
mensajes*; sin mensaje publicado, el formulario no aparece.

## Pendiente en tu computador (opcional pero recomendado)

`flutter doctor` marca la cadena de herramientas de Android con una advertencia
(falta "Android SDK Command-line Tools" y aceptar licencias). El `.aab` se genera
igual, pero Flutter avisa de que no pudo limpiar los símbolos de depuración
de las librerías nativas. Para arreglarlo:
1. Android Studio → *Settings → Languages & Frameworks → Android SDK → SDK Tools*
   → marca **Android SDK Command-line Tools (latest)** → Apply.
2. En PowerShell: `flutter doctor --android-licenses` y acepta con `y`.

## 8. Lista de verificación antes de subir

- [ ] `android/key.properties` creado y el build ya no muestra el aviso de firma
- [ ] `flutter build appbundle --release` genera el `.aab`
- [ ] IDs de AdMob reales colocados (no los de prueba)
- [ ] Política de privacidad publicada y URL pegada en Play Console
- [ ] Data safety, anuncios, público objetivo y clasificación completados
- [ ] Capturas e ícono subidos
- [ ] Probado el `.aab` en un celular real desde "Prueba interna"
