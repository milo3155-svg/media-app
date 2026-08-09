import 'package:flutter/material.dart';

void main() {
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
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.deepPurple,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aplicación Multimedia'),
        backgroundColor: Colors.black,
      ),
      body: const Center(
        child: Text(
          '¡Bienvenido a tu App!',
          style: TextStyle(fontSize: 20, color: Colors.white),
        ),
      ),
    );
  }
}
