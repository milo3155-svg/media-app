import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_service/audio_service.dart';
import 'providers/music_provider.dart';
import 'screens/home_screen.dart';

// Instancia global segura para el manejador de audio
late AudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización obligatoria para evitar el LateInitializationError
  try {
    audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandler(), // Asegúrate de que esta clase gestione tu reproductor
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.milo.media_app.channel.audio',
        androidNotificationChannelName: 'Reproducción de Música',
        androidNotificationOngoing: true,
      ),
    );
  } catch (e) {
    debugPrint('Error al inicializar AudioService: $e');
  }

  runApp(const MediaApp());
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MusicProvider()),
      ],
      child: MaterialApp(
        title: 'Media App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF121212),
          primaryColor: Colors.purpleAccent,
          colorScheme: const ColorScheme.dark(
            primary: Colors.purpleAccent,
            secondary: Colors.purpleAccent,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
