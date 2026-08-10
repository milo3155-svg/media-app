import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

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
// NAVEGACIÓN PRINCIPAL (5 PESTAÑAS)
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
    PodcastsTab(),
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
            icon: Icon(Icons.podcasts_outlined),
            selectedIcon: Icon(Icons.podcasts),
            label: 'Podcasts',
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
// PESTAÑA 1: DEPORTES REDISEÑADO
// ==========================================
class SportsTab extends StatelessWidget {
  const SportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚽ Deportes & Radio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.radio_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transmisión de Radio activada')),
              );
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Tarjeta Destacada EN VIVO
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor.withOpacity(0.8), primaryColor.withOpacity(0.3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 8),
                            SizedBox(width: 6),
                            Text('EN VIVO', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const Text('Champions League', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Icon(Icons.shield, size: 36, color: Colors.white),
                          SizedBox(height: 4),
                          Text('Real Madrid', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text('2 - 1', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                      Column(
                        children: [
                          Icon(Icons.shield_outlined, size: 36, color: Colors.white),
                          SizedBox(height: 4),
                          Text('Barcelona', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {},
                    icon: const Icon(Icons.volume_up, color: Colors.black),
                    label: const Text('Escuchar Narración en Vivo (Radio)', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Cartelera de Hoy - Liga MX', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.sports_soccer)),
              title: const Text('América vs Guadalajara'),
              subtitle: const Text('Hoy 21:00 hrs | Estadio Azteca'),
              trailing: ElevatedButton(
                onPressed: () {},
                child: const Text('Sintonizar'),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.sports_soccer)),
              title: const Text('Cruz Azul vs Pumas'),
              subtitle: const Text('Mañana 19:00 hrs'),
              trailing: const Icon(Icons.access_time),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PESTAÑA 2: PODCASTS
// ==========================================
class PodcastsTab extends StatelessWidget {
  const PodcastsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎙️ Podcasts Destacados'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('Episodios Recientes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.purple.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mic, color: Colors.white),
              ),
              title: const Text('Relatos e Historias de la Noche'),
              subtitle: const Text('Ep. 142 • 45 min'),
              trailing: IconButton(
                icon: const Icon(Icons.play_circle_fill, size: 36),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reproduciendo Podcast...')),
                  );
                },
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.orange.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.graphic_eq, color: Colors.white),
              ),
              title: const Text('Charla & Entretenimiento'),
              subtitle: const Text('Ep. 89 • 1 hr 12 min'),
              trailing: IconButton(
                icon: const Icon(Icons.play_circle_fill, size: 36),
                onPressed: () {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PESTAÑA 3: BUSCADOR YOUTUBE (BACKEND REAL)
// ==========================================
class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  final YoutubeExplode _yt = YoutubeExplode();
  List<Video> _searchResults = [];
  bool _isLoading = false;

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _yt.search.search(query);
      setState(() {
        _searchResults = results.take(15).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al buscar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _yt.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔍 Buscador Multimedia'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar en YouTube...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: _performSearch,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _performSearch(_searchController.text),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Consultando YouTube...'),
                    ],
                  ),
                ),
              )
            else if (_searchResults.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('Escribe algo arriba y presiona buscar', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final video = _searchResults[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: Image.network(
                          video.thumbnails.lowResUrl,
                          width: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.play_arrow),
                        ),
                        title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${video.author} • ${video.duration?.inMinutes ?? 0} min'),
                        trailing: IconButton(
                          icon: const Icon(Icons.play_circle_fill),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Cargando: ${video.title}')),
                            );
                          },
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
// PESTAÑA 4: BÓVEDA
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
                  title: Text('Pista Guardada #${index + 1}'),
                  subtitle: const Text('Bóveda de me gusta'),
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
// PESTAÑA 5: AJUSTES Y SELECCIÓN DE COLOR
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
          const Text('Selecciona el Color Principal:', style: TextStyle(fontWeight: FontWeight.bold)),
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
            onTap: () {
              Share.share('¡Prueba mi nueva aplicación multimedia hecha en Flutter!');
            },
          ),
        ],
      ),
    );
  }
}
