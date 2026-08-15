import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.mediaapp.channel.audio',
    androidNotificationChannelName: 'Reproducción 2do Plano',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'drawable/ic_notification',
  );
  runApp(const MediaApp());
}

class MediaApp extends StatefulWidget {
  const MediaApp({super.key});
  @override
  State<MediaApp> createState() => _MediaAppState();
}

class _MediaAppState extends State<MediaApp> {
  Color _primaryColor = Colors.purpleAccent;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: _primaryColor,
        colorScheme: ColorScheme.dark(primary: _primaryColor),
      ),
      home: MainNavigation(
        primaryColor: _primaryColor,
        onColorChange: (color) => setState(() => _primaryColor = color),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final Color primaryColor;
  final Function(Color) onColorChange;
  const MainNavigation({super.key, required this.primaryColor, required this.onColorChange});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // Lista de pantallas para los 4 iconos de la barra inferior
  final List<Widget> _pages = [
    const Center(child: Text("Inicio (Tendencias)")),
    const Center(child: Text("Top Musical 🔝")),
    const Center(child: Text("Listas de Reproducción")),
    const Center(child: Text("Deportes")),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- MENÚ LATERAL ---
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1E1E),
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text("Usuario"),
              accountEmail: const Text("Bienvenido"),
              decoration: BoxDecoration(color: widget.primaryColor.withOpacity(0.3)),
            ),
            const Divider(),
            // Selector de Color de Tema
            ListTile(
              title: const Text("Color de Tema"),
              trailing: PopupMenuButton<Color>(
                icon: Icon(Icons.palette, color: widget.primaryColor),
                onSelected: widget.onColorChange,
                itemBuilder: (context) => [
                  const PopupMenuItem(value: Colors.purpleAccent, child: Text('Púrpura')),
                  const PopupMenuItem(value: Colors.blueAccent, child: Text('Azul')),
                  const PopupMenuItem(value: Colors.tealAccent, child: Text('Verde')),
                  const PopupMenuItem(value: Colors.redAccent, child: Text('Rojo')),
                ],
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(title: const Text("Media App")),
      body: IndexedStack(index: _currentIndex, children: _pages),
      
      // --- BARRA INFERIOR ---
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: widget.primaryColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF1F1F1F),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Top 🔝'),
          BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Listas'),
          BottomNavigationBarItem(icon: Icon(Icons.sports_soccer), label: 'Deportes'),
        ],
      ),
    );
  }
}
