# 🎧 Media App VIP (Spotify Killer)

Aplicación móvil de streaming musical de alto rendimiento desarrollada en Flutter. Este proyecto funciona como un motor de extracción de audio que permite la reproducción en segundo plano y gestión de listas de reproducción sin interrupciones, ofreciendo una experiencia premium y ultra ligera.

## 🚀 Características Principales

* **Reproducción en Segundo Plano:** Integración nativa con los controles de medios del sistema operativo (pantalla de bloqueo y notificaciones).
* **Motor Ultra Ligero:** Extracción exclusiva de los fragmentos de audio puro (`manifest.audioOnly`) para reducir drásticamente el uso de ancho de banda.
* **Ahorro de Datos VIP:** Interruptor integrado para alternar en tiempo real entre resoluciones HD (~160 kbps) y SD (~48 kbps).
* **Bóveda Local Autónoma:** Gestión de historiales, listas personalizadas y métricas de reproducción directamente en el dispositivo sin depender de servidores externos.
* **Interfaz Neón Dinámica:** Interfaz reactiva con diseño *Glassmorphism*, modo bucle y un "latido" visual para el seguimiento de la pista.

## 🛠️ Stack Tecnológico

* **Core & UI:** Flutter y Dart.
* **Motor Multimedia:** `just_audio` orquestado mediante `audio_service` para persistencia en *foreground*.
* **Extracción de Datos:** `youtube_explode_dart` para el parseo seguro de *streams*.
* **Base de Datos Local:** `hive_flutter` (Base de datos NoSQL clave-valor de ultra alta velocidad).

## ⚙️ Arquitectura y Despliegue

La aplicación sigue una arquitectura orientada a la eficiencia de recursos móviles. No utiliza un *backend* centralizado tradicional, sino que delega el procesamiento de la información al lado del cliente mediante una conexión segura. El empaquetado y la integración continua (CI/CD) se gestionan directamente a través de Codemagic para compilar los artefactos APK (Android) listos para su distribución directa.

---
*Desarrollado y mantenido por Osiris Aramis Alvarez Silva.*
