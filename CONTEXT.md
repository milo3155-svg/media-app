# 🧠 AI Context & State - Spotify Killer VIP

> **Nota para la IA:** Este archivo contiene el estado técnico actual, arquitectura y contexto operativo de la aplicación para retomar cualquier desarrollo de forma inmediata sin pérdida de información.

## 1. Arquitectura y Stack Tecnológico
* **Core:** Flutter / Dart (Estructura centralizada en `lib/main.dart`).
* **Audio Engine:** `just_audio` + `audio_service` (Manejo de segundo plano y notificaciones nativas).
* **Caché y Resiliencia:** `LockCachingAudioSource` implementado para almacenamiento local por pista (Soporte offline / Modo Avión).
* **Optimización de Audio:** `_player.setSkipSilenceEnabled(true)` activo para omitir silencios.
* **Extracción:** `youtube_explode_dart` para resolución de streams de audio de YouTube.
* **Persistencia NoSQL:** `hive` y `hive_flutter` (Cajas activas: `history`, `favorites`, `search_history`, `playlists`).

## 2. Decisiones Críticas y Parches Aplicados (No romper)
* **Bug "Live" / Duración 00:00:** Solucionado inyectando `duration: video.duration ?? Duration.zero` tanto en la fuente de caché como en el `mediaItem` global.
* **UI e Interfaz:** La interfaz (incluyendo vistas de inicio, buscador, bóveda, sección de deportes y el logo personalizado `_OsirisEyePainter`) vive íntegramente en `lib/main.dart`. No debe sobrescribirse a ciegas sin respetar la estructura visual del usuario.

## 3. Estado Actual del Proyecto
* **Build:** Estable y verificado mediante compilación automatizada en Codemagic para Android.
* **Fase Actual:** Post-estabilización de motor de audio. Listos para futuras expansiones o nuevas funcionalidades.
