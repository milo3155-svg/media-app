import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';

// Importamos tus providers
import 'providers/music_provider.dart';
import 'providers/home_provider.dart';  // Asegúrate de que este archivo exista en tu carpeta providers
import 'providers/vault_provider.dart'; // Asegúrate de que este archivo exista en tu carpeta providers

// Importamos tu pantalla principal
import 'screens/main_screen.dart';      // Asegúrate de que la ruta coincida con tu carpeta de pantallas

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
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => VaultProvider()),
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
        // ¡Aquí regresa tu interfaz real!
        home: const MainScreen(),
      ),
    );
  }
}
