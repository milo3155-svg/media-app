import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => VaultProvider()),
      ],
      child: const MediaApp(),
    ),
  );
}

// ==========================================
// PROVEEDOR DE BÓVEDA (FAVORITOS)
// ==========================================
class MediaItem {
  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;

  MediaItem({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
  });
}

class VaultProvider extends ChangeNotifier {
  final List<MediaItem> _favorites = [];

  List<MediaItem> get favorites => _favorites;

  bool isFavorite(String id) {
    return _favorites.any((item) => item.id == id);
  }

  void toggleFavorite(MediaItem item) {
    final index = _favorites.indexWhere((element) => element.id == item.id);
    if (index >= 0) {
      _favorites.removeAt(index);
    } else {
      _favorites.add(item);
    }
    notifyListeners();
  }
}

// ==========================================
// PROVEEDOR DE TEMAS Y COLORES
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
// NAVEGACIÓN PRINCIPAL CON DRAWER (MENÚ LATERAL)
// ==========================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String _searchMode = 'YouTube';

  void _selectTabFromDrawer(int index, {String? searchMode}) {
    setState(() {
      _currentIndex = index;
      if (searchMode != null) {
        _searchMode = searchMode;
      }
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    final List<Widget> tabs = [
      HomeTab(onNavigateToSearch: (mode) {
        setState(() {
          _searchMode = mode;
          _currentIndex = 2;
        });
      }),
      const SportsTab(),
      SearchTab(searchMode: _searchMode),
      const VaultTab(),
      const SettingsTab(),
    ];

    return Scaffold(
      drawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.75,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.play_arrow_rounded, size: 40, color: Colors.deepPurple),
              ),
              accountName: const Text('Media Hub Stream', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              accountEmail: const Text('Tu Centro Multimedia Personal', style: TextStyle(color: Colors.white70)),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Inicio'),
              selected: _currentIndex == 0,
              onTap: () => _selectTabFromDrawer(0),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.video_library_outlined, color: Colors.redAccent),
              title: const Text('YouTube Videos'),
              selected: _currentIndex == 2 && _searchMode == 'YouTube',
              onTap: () => _selectTabFromDrawer(2, searchMode: 'YouTube'),
            ),
            ListTile(
              leading: const Icon(Icons.music_note_outlined, color: Colors.red),
              title: const Text('YouTube Music'),
              selected: _currentIndex == 2 && _searchMode == 'YouTube Music',
              onTap: () => _selectTabFromDrawer(2, searchMode: 'YouTube Music'),
            ),
            ListTile(
              leading: const Icon(Icons.sports_soccer_outlined),
              title: const Text('Deportes & Radio'),
              selected: _currentIndex == 1,
              onTap: () => _selectTabFromDrawer(1),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.collections_bookmark_outlined),
              title: const Text('Mi Bóveda / Biblioteca'),
              selected: _currentIndex == 3,
              onTap: () => _selectTabFromDrawer(3),
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Ajustes y Temas'),
              selected: _currentIndex == 4,
              onTap: () => _selectTabFromDrawer(4),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Versión 1.0.0 • Pixel Edition', style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
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
// PESTAÑA INICIO (HOME)
// ==========================================
class HomeTab extends StatelessWidget {
  final Function(String mode) onNavigateToSearch;

  const HomeTab({super.key, required this.onNavigateToSearch});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏠 Inicio'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('¿Qué quieres explorar hoy?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onNavigateToSearch('YouTube'),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withOpacity(0.4)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.play_circle_fill, size: 48, color: Colors.red),
                        SizedBox(height: 8),
                        Text('YouTube', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Videos y Clips', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => onNavigateToSearch('YouTube Music'),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primaryColor.withOpacity(0.4)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.music_note, size: 48, color: primaryColor),
                        const SizedBox(height: 8),
                        const Text('YT Music', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Text('Música y Audio', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Acceso Rápido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sports_soccer, color: Colors.green),
              title: const Text('Eventos Deportivos en Vivo'),
              subtitle: const Text('Revisa la cartelera y escucha narraciones'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {},
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.thumb_up, color: Colors.amber),
              title: const Text('Tus Favoritos en la Bóveda'),
              subtitle: const Text('Escucha tus pistas guardadas'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PESTAÑA DEPORTES
// ==========================================
class SportsTab extends StatelessWidget {
  const SportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚽ Deportes & Radio'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor.withOpacity(0.8), primaryColor.withOpacity(0.3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
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
                      Text('Real Madrid', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('2 - 1', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                      Text('Barcelona', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PlayerScreen(
                            videoId: '148_s-5N0m4',
                            title: 'Transmisión Deportiva en Vivo (Radio)',
                            author: 'Radio Deportes',
                            thumbnailUrl: 'https://img.youtube.com/vi/148_s-5N0m4/hqdefault.jpg',
                            isAudioOnlyDefault: true,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.volume_up, color: Colors.black),
                    label: const Text('Escuchar Transmisión (Solo Audio)', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PESTAÑA BUSCADOR DUAL (YT & YT MUSIC)
// ==========================================
class SearchTab extends StatefulWidget {
  final String searchMode;

  const SearchTab({super.key, this.searchMode = 'YouTube'});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final yt_exp.YoutubeExplode _yt = yt_exp.YoutubeExplode();
  List<yt_exp.Video> _searchResults = [];
  bool _isLoading = false;
  late String _currentMode;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.searchMode;
  }

  @override
  void didUpdateWidget(SearchTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchMode != widget.searchMode) {
      setState(() {
        _currentMode = widget.searchMode;
      });
      if (_searchController.text.isNotEmpty) {
        _performSearch(_searchController.text);
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final searchQuery = _currentMode == 'YouTube Music' ? '$query letra audio' : query;
      final results = await _yt.search.search(searchQuery);
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
    super.build(context);
    final vault = Provider.of<VaultProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('🔍 Buscador $_currentMode'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                ChoiceChip(
                  label: const Text('YouTube'),
                  selected: _currentMode == 'YouTube',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _currentMode = 'YouTube');
                      _performSearch(_searchController.text);
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('YT Music'),
                  selected: _currentMode == 'YouTube Music',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _currentMode = 'YouTube Music');
                      _performSearch(_searchController.text);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: _currentMode == 'YouTube Music' ? 'Buscar canciones, artistas...' : 'Buscar videos...',
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
               
