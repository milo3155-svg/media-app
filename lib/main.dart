import 'package:flutter/material.dart';

void main() {
  // Asegura que los servicios de Flutter se inicialicen antes de runApp
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MediaApp());
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aplicación Multimedia',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Multimedia'),
          centerTitle: true,
        ),
        body: const Center(
          child: Text(
            '¡App Iniciada Correctamente!',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
