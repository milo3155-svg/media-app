import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'providers/music_provider.dart';
// TODO: Descomenta e importa tus otras pantallas y providers aquí
// import 'screens/main_screen.dart'; 
// import 'providers/home_provider.dart';
// import 'providers/vault_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización crítica para que la música no muera con la pantalla apagada
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
        // TODO: Agrega aquí tus otros providers si los tienes separados
        // ChangeNotifierProvider(create: (_) => HomeProvider()),
        // ChangeNotifierProvider(create: (_) => VaultProvider()),
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
        // TODO: Cambia este Scaffold por la llamada a tu pantalla de inicio real (ej. MainScreen())
        home: const Scaffold(
          body: Center(child: Text("Cargando interfaz...")),
        ),
      ),
    );
  }
}
