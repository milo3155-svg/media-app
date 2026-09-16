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
