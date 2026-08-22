import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Importamos la librería
import 'screens/home_screen.dart';
import 'providers/music_provider.dart'; // Importamos tu nuevo gestor

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    // Envolvemos la app para inyectar el estado global
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MusicProvider()),
      ],
      child: const MediaApp(),
    ),
  );
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
