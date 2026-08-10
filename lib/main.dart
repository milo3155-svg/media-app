import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MediaApp(),
    ),
  );
}

// ==========================================
// PROVEEDOR DE TEMAS Y COLORES DINÁMICOS
// ==========================================
class ThemeProvider extends ChangeNotifier {
  Color _primaryColor = Colors.deepPurple;
  bool _isDarkMode = true;

  Color get primaryColor => _primaryColor;
  bool get isDarkMode => _isDarkMode;

  void setPrimaryColor(Color color) {
    _primaryColor = color;
    notifyListeners();
  }

  void toggleThemeMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}

// ==========================================
// APLICACIÓN PRINCIPAL
// ==========================================
class MediaApp extends StatelessWidget {
  const MediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Media App',
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: themeProvider.primaryColor,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: themeProvider.primaryColor,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

// ==========================================
// NAVEGACIÓN PRINCIPAL (4 PESTAÑAS)
// ==========================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    SportsTab(),
    SearchTab(),
    VaultTab(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sports_soccer_outlined),
            selectedIcon: Icon(Icons.sports_soccer),
            label: 'Deportes',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Buscar',
          ),
          NavigationDestination(
            icon: Icon(Icons.thumb_up_alt_outlined),
            selectedIcon: Icon(Icons.thumb_up_alt),
            label: 'Bóveda',
          ),
          NavigationDestination(
            icon: Icon(Icons.palette_outlined),
            selectedIcon: Icon(Icons.palette),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PESTAÑA 1: DEPORTES Y EVENTOS EN VIVO
// ==========================================
class SportsTab extends StatelessWidget {
  const SportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚽ Deportes en Vivo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.radio),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Modo Radio activado')),
              );
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            color: primaryColor.withOpacity(0.15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
                        label: const Text('EN VIVO'),
                        backgroundColor: Colors.red.withOpacity(0.2),
                      ),
                      const Text('Champions League', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text('Real Madrid', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('2 - 1', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text('FC Barcelona', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 45),
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {},
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Escuchar Transmisión (Modo Radio)'),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Próximos Eventos - Liga MX', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.sports_soccer)),
            title: const Text('América vs Guadalajara'),
            subtitle: const Text('Hoy 21:00 hrs | Estadio Azteca'),
            trailing: IconButton(
              icon: const Icon(Icons.play_circle_outline),
              onPressed: () {},
            ),
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.sports_soccer)),
            title: const Text('Cruz Azul vs Pumas'),
            subtitle: const Text('Mañana 19:00 hrs'),
            trailing: IconButton(
              icon: const Icon(Icons.radio_button_checked),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PESTAÑA 2: BUSCADOR MULTIMEDIA
// ==========================================
class SearchTab extends StatelessWidget {
  const SearchTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔍 Buscador YouTube'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Buscar canciones, videos o partidos...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.play_arrow),
                      ),
                      title: Text('Resultado de búsqueda #${index + 1}'),
                      subtitle: const Text('Canal Multimedia • 3.2M vistas'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.thumb_up_outlined), onPressed: () {}),
                          IconButton(icon: const Icon(Icons.download_outlined), onPressed: () {}),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// PESTAÑA 3: BÓVEDA DE FAVORITOS & PLAYLISTS
// ==========================================
class VaultTab extends StatelessWidget {
  const VaultTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('👍 Mi Bóveda'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.thumb_up), text: 'Me Gusta'),
              Tab(icon: Icon(Icons.playlist_play), text: 'Mis Listas'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView.builder(
              itemCount: 3,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.music_note, color: Colors.amber),
                  title: Text('Audio Favorito #${index + 1}'),
                  subtitle: const Text('Guardado en la bóveda'),
                  trailing: const Icon(Icons.play_arrow),
                );
              },
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.playlist_add, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No tienes listas personalizadas aún'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Crear Nueva Lista'),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// PESTAÑA 4: AJUSTES Y PERSONALIZACIÓN DE COLOR
// ==========================================
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  final List<Color> _availableColors = const [
    Colors.deepPurple,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.pink,
    Colors.teal,
    Colors.red,
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎨 Personalización y Ajustes'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SwitchListTile(
            title: const Text('Modo Oscuro'),
            value: themeProvider.isDarkMode,
            onChanged: (val) => themeProvider.toggleThemeMode(),
          ),
          const Divider(),
          const SizedBox(height: 12),
          const Text('Selecciona el Color Principal de la App:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _availableColors.map((color) {
              final isSelected = themeProvider.primaryColor == color;
              return GestureDetector(
                onTap: () => themeProvider.setPrimaryColor(color),
                child: CircleAvatar(
                  backgroundColor: color,
                  radius: 24,
                  child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                ),
              );
            }).toList(),
          ),
          const Divider(height: 40),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Compartir App'),
            subtitle: const Text('Envía el enlace o la APK a tus amigos'),
            onTap: () {
              Share.share('¡Prueba mi nueva aplicación multimedia hecha en Flutter!');
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_done),
            title: const Text('Gestor de Descargas'),
            subtitle: const Text('Ver archivos guardados en el almacenamiento'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
