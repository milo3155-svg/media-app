import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';

// Importamos solo el provider que SÍ existe
import 'providers/music_provider.dart';

// Importamos la pantalla que SÍ existe en tu captura
import 'screens/home_screen.dart';      

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Motor de segundo plano de Android
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.milo.media_app.channel.audio',
      androidNotificationChannelName: 'Reproducción de Música',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    debugPrint("Error inicializando notificación: $e");
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
        // ¡Aquí llamamos a la pantalla correcta!
        home: const HomeScreen(),
      ),
    );
  }
}
