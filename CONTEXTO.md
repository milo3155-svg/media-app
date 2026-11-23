# CONTEXTO DEL PROYECTO — media-app (Spotify Killer VIP)

## 1. Arquitectura y Entorno
* **App cliente:** `media-app` (Flutter, compilación vía GitHub Actions `flutter build apk --release`).
* **Panel administrador:** `the-apex-admin` (Mesa de Control).
* **Base de datos en tiempo real:** Firebase / Cloud Firestore.
  * Colección: `tokens` (documentos por ID numérico, ej. `9414`).
  * Campos verificados: `musica` (bool), `creado` (Timestamp), `dias` (int).
* **Almacenamiento local:** Hive (cajas: `auth`, `favorites`, `history`).
* **Flujo de trabajo:** Edición directa en GitHub y compilación en la nube (usuario sin conocimientos de programación; dar siempre ruta exacta, nombre de archivo y líneas).

## 2. Archivos Clave Verificados
* `android/app/build.gradle`: Incluye `id "com.google.gms.google-services"` en el bloque `plugins`.
* `lib/main.dart`: Inicializa `Firebase.initializeApp()`, `Hive.initFlutter()`, abre cajas `auth`, `favorites`, `history` y expone `audioHandler`.
* `lib/screens/token_gate_screen.dart`:
  * Normaliza tokens (`TKN-XXXX` o `XXXX`).
  * Valida existencia, permiso `musica == true` y expiración (`creado` + `dias`).
  * Escucha cambios en tiempo real mediante `StreamSubscription? _tokenSub` y `StreamBuilder`.
  * Ejecuta `_logoutToken(reason)` llamando a `await audioHandler.stop()`, borrando `token` de Hive y expulsando a la pantalla de acceso restringido.

## 3. Estado Actual (Verificado)
* [x] Compilación APK en verde en GitHub Actions.
* [x] Conexión Firebase/Firestore operativa (error `FirebaseOptions` resuelto).
* [x] Validación de acceso por token al iniciar la app.
* [x] Kill Switch en tiempo real expulsa a la pantalla **ACCESO RESTRINGIDO** con mensaje rojo al revocar token o apagar `musica`.
* [x] App enviada a pruebas UAT (reproducción, segundo plano, radio, favoritos, historial, cola, temporizador, color).

## 4. Historial de Resolución Reciente
* [x] **Kill Switch en tiempo real completado:** Se agregó `StreamSubscription? _tokenSub` en `lib/screens/token_gate_screen.dart` y el método `@override Future<void> stop()` en `lib/services/audio_handler.dart`. Verificado en dispositivo: al desactivar `musica` en la Mesa de Control, el audio se detiene al instante y expulsa a la pantalla de acceso.

## 5. Estado Actual
* Sin bugs bloqueantes abiertos. En espera de resultados de pruebas UAT.
