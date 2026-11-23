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

## 4. Pendiente Técnico Activo (Bug Abierto)
* **Problema:** Al apagar el permiso `musica` o revocar el token en tiempo real, la interfaz sí expulsa al usuario, pero el audio no se corta definitivamente (se traba/adelanta unos segundos y al pulsar pausa/reproducir desde la notificación vuelve a sonar).
* **Siguiente paso exacto:** Revisar las **líneas 1 a 35** de `media-app/lib/main.dart` para localizar `MyAudioHandler` y corregir su método `stop()` para que detenga y limpie la fuente de audio y la notificación.
