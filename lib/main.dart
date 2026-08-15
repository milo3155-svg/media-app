import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MediaApp());
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Prueba de Estabilidad',
      theme: ThemeData.dark(),
      home: const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.greenAccent, size: 80),
              SizedBox(height: 20),
              Text(
                "App Estable - Paso 1 ✅",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                "Si puedes leer esto, no hay errores graves.",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
