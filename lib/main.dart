import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'providers/music_provider.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de segundo plano requerida por just_audio_background
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.milo.media_app.channel.audio',
      androidNotificationChannelName: 'Reproducción de Música',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    debugPrint('Error inicializando notificaciones: $e');
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
