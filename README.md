# 🎧 Spotify Killer VIP (Media App)

Aplicación móvil personalizada de streaming y reproducción de audio construida en Flutter, diseñada para operar de forma independiente con rendimiento optimizado en dispositivos móviles.

## ✨ Características Principales

* **Bóveda de Caché Local (`LockCachingAudioSource`):** Descarga y almacena en caché localmente cada pista reproducida, permitiendo la reproducción fluida incluso ante interrupciones de red o en modo avión.
* **Eliminador de Silencios Activo:** Integración con `just_audio` para omitir automáticamente los espacios muertos y baches de audio en tiempo real.
* **Metadatos Blindados:** Sincronización estricta de duración y títulos para evitar el error de visualización en "Live" o tiempos en `00:00`.
* **Gestión de Historial y Favoritos:** Almacenamiento local ultrarrápido mediante Hive para conservar el historial de reproducción y pistas favoritas.
* **Sistema de Playlists y Búsqueda:** Exploración de contenido impulsada por `youtube_explode_dart` con creación de listas personalizadas y categorías temáticas.
* **Temporizador de Apagado (Sleep Timer):** Control configurable para pausar automáticamente la reproducción tras un tiempo determinado.

## 🛠️ Stack Tecnológico

* **Framework:** Flutter (Dart)
* **Reproductor de Audio:** `just_audio` & `audio_service`
* **Extracción de Contenido:** `youtube_explode_dart`
* **Base de Datos NoSQL:** `hive` & `hive_flutter`
* **CI/CD:** Automatización de despliegue y compilación mediante Codemagic.

## 📱 Despliegue

El proyecto está configurado para compilación directa en entornos de integración continua (Codemagic) orientados a la plataforma Android.
# 🎧 Spotify Killer VIP (Media App)

Aplicación móvil personalizada de streaming y reproducción de audio construida en Flutter, diseñada para operar de forma independiente con rendimiento optimizado en dispositivos móviles.

## ✨ Características Principales

* **Bóveda de Caché Local (`LockCachingAudioSource`):** Descarga y almacena en caché localmente cada pista reproducida, permitiendo la reproducción fluida incluso ante interrupciones de red o en modo avión.
* **Eliminador de Silencios Activo:** Integración con `just_audio` para omitir automáticamente los espacios muertos y baches de audio en tiempo real.
* **Metadatos Blindados:** Sincronización estricta de duración y títulos para evitar el error de visualización en "Live" o tiempos en `00:00`.
* **Gestión de Historial y Favoritos:** Almacenamiento local ultrarrápido mediante Hive para conservar el historial de reproducción y pistas favoritas.
* **Sistema de Playlists y Búsqueda:** Exploración de contenido impulsada por `youtube_explode_dart` con creación de listas personalizadas y categorías temáticas.
* **Temporizador de Apagado (Sleep Timer):** Control configurable para pausar automáticamente la reproducción tras un tiempo determinado.

## 📂 Estructura de Rutas y Directorios

El proyecto centraliza toda su lógica, servicios de audio, pantallas de interfaz y diseño visual dentro del archivo principal y la estructura estándar de Flutter:

```text
media-app/
├── android/                         # Configuración nativa de Android y recursos de notificaciones
│   └── app/src/main/res/drawable/   # Iconos y recursos visuales (ej. ic_notification)
├── lib/
│   └── main.dart                    # Núcleo absoluto de la app (Motor de audio, UI, Hive, Widgets y Pantallas)
├── .github/                         # Configuraciones del repositorio
├── codemagic.yaml                   # Automatización de CI/CD para compilación de APKs
├── pubspec.yaml                     # Dependencias, paquetes externos y versiones
└── README.md                        # Documentación técnica del proyecto
Stack Tecnológico y Dependencias Clave
Framework: Flutter / Dart (>=3.0.0 <4.0.0)
Audio y Notificaciones: just_audio (^0.9.36), audio_service (^0.18.13), audio_session (^0.1.18)
Extracción Multimedia: youtube_explode_dart (any)
Persistencia Local (NoSQL): hive (^2.2.3), hive_flutter (^1.1.0)
Utilidades: permission_handler (^11.3.1)
CI/CD: Codemagic
## Estado del Proyecto
* *CI/CD:* Pipeline de Codemagic configurado y compilando exitosamente el APK en Android (Release).
* *Refactorización:* Estructura de clases de main.dart saneada para aislar la pantalla de búsqueda, el MiniPlayer y el FullScreenPlayer.
* *Próximos pasos (Pendientes):* 
  * Reubicación de la interfaz del reproductor (contador de cola "1/20", botón de favoritos).
  * Redirección de descargas .m4a de la ruta interna al almacenamiento público de Android
## Bitácora de Desarrollo - 20 de septiembre de 2026

*Estado actual:* Módulo de descarga de audios bloqueado por medidas anti-bot de YouTube.
*Problema:* Las peticiones HTTP directas son interceptadas por los servidores de Google.

*Estrategias intentadas y resultados:*
*   *Petición HTTP Directa (Stream):* Fallida. YouTube detecta la falta de entorno web y aplica "Tarpitting" (conexión abierta sin envío de datos, congelando el progreso en 0.0%).
*   *Servidores Puente (API Cobalt / Piped):* Inestable. Los servidores externos bloquean las peticiones automatizadas de Dart devolviendo errores 403 Forbidden, incluso inyectando cabeceras (User-Agent) de Google Chrome, debido a la protección de Cloudflare Turnstile.
*   *Descarga Fraccionada (Chunked Downloading) con Auto-Recuperación:* Parcialmente exitosa. Se lograron descargar fragmentos usando peticiones de Rango (Range: bytes=...) de 1 MB. Sin embargo, YouTube corta irreversiblemente la conexión de red (Timeout/403) alrededor del 30% al detectar descargas rápidas y secuenciales desde una misma IP.

*Próximos pasos (Siguiente Sprint):*
1. Implementar estrangulamiento de red (Throttling): Reducir los bloques HTTP a 256 KB e introducir retardos aleatorios entre descargas para emular el buffering de un reproductor humano.
2. Investigar la migración de la lógica de descarga manual en Dart hacia una delegación al sistema operativo mediante flutter_downloader (Native Android Download Manager) para aprovechar su resiliencia ante micro-cortes.

## Bitácora de Desarrollo - Día 2 (Descargas Offline)
**Estado:** Bloqueo por cifrado (2do día sin éxito en pistas oficiales).

**Ajustes Implementados:**
* **Migración a Memoria:** Se reemplazó el flujo directo (`.pipe`) por empaquetado en memoria RAM (`.fold`) para eliminar los choques de sistema de archivos (`StreamSink`).
* **Depuración de Compilación:** Se resolvieron los errores de variables duplicadas en el *scope* que detenían el pipeline en Codemagic.
* **Ajuste de Red:** Se eliminó el límite de tiempo (`timeout`) en la extracción de bytes para compensar el estrangulamiento de velocidad (*throttling*) impuesto por YouTube.
* **Preparación Visual:** Se estructuró la carpeta `assets` para la inyección del logo personalizado mediante `flutter_launcher_icons`.

**Obstáculos Activos (Roadblocks):**
* **Firmas de Seguridad (VEVO/Oficial):** Las pistas de disqueras comerciales (Linkin Park, Nirvana) devuelven el error `VideoUnavailableException`. La librería está chocando contra la protección anti-bots actualizada de YouTube.
* **Deadlock en la UI:** Si la extracción del audio falla por culpa del cifrado, el código actual no atrapa la excepción en la interfaz. Esto provoca que el diálogo "Descargando pista" nunca reciba la orden de cerrarse, dejando la app en un estado de carga infinita sin notificar al usuario.

**Siguientes Pasos (Día 3):**
1. Ejecutar `flutter pub upgrade youtube_explode_dart` en la terminal para forzar la descarga del último parche de evasión de firmas.
2. Envolver la lógica del diálogo de carga en un `try/catch` estricto que destruya la ventana emergente y muestre un *SnackBar* rojo si el video está protegido.
3. Retomar pruebas de flujo de datos exclusivamente con pistas sin copyright (NCS) para confirmar la estabilidad de escritura antes de volver a intentar con música comercial.

## Arquitectura de Reproducción (Actualizada)
* *Conexión Directa:* Se eliminó el servidor proxy intermediario en Render para evitar los bloqueos persistentes de YouTube (Errores 403 y 429) y los límites de memoria.
* *Extracción de Audio:* La aplicación ahora utiliza llamadas asíncronas mediante el paquete http hacia instancias públicas de la API de Piped (/streams/$videoId), obteniendo la URL directa del flujo de audio (audioStreams) sin pasar por servidores externos.
* *Reproducción:* El enlace directo se integra de manera nativa en el reproductor just_audio dentro de la aplicación en el dispositivo.
*Bitácora de Desarrollo Técnico
Registro de Actualizaciones
23 de Septiembre de 2026
Estado: Se ha actualizado la arquitectura de descarga. Después de abandonar el proxy en Render y comprobar que las instancias públicas de Piped (como kavin.rocks y adminforge.de) están bloqueadas o fallan incluso con pistas sin copyright (NCS), se ha descartado el uso del paquete http para extracción.
Siguiente paso: Reemplazar el bloque inestable de obtenerAudioDirecto por una implementación nativa utilizando youtube_explode_dart. Esta librería romperá el cifrado directamente en el dispositivo (Pixel 10 Pro) para obtener el enlace y pasarlo al FlutterDownloader.

