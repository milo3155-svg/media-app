import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  // Aseguramos que Flutter esté listo
  WidgetsFlutterBinding.ensureInitialized();
  
  // (El servicio de audio está pausado temporalmente para no buscar el ícono)
  
  // Arrancamos la interfaz gráfica
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
