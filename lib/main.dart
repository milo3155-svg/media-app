import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'screens/home_screen.dart';
import 'services/audio_handler.dart';

// Variable global para controlar el audio desde cualquier pantalla
late AudioHandler audioHandler;

Future<void> main() async {
  // Aseguramos que Flutter esté listo antes de arrancar servicios nativos
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializamos el servicio de audio en segundo plano
  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.milo.media_app.channel.audio',
      androidNotificationChannelName: 'Reproducción de Audio',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(const MediaApp());
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Media App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const HomeScreen(),
    );
  }
}
