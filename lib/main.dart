import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => VaultProvider()),
        ChangeNotifierProvider(create: (_) => YMusicPlayerProvider()),
      ],
      child: const MediaApp(),
    ),
  );
}

// ==========================================
// MODELO DE DATOS
// ==========================================
class MediaItemModel {
  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;
  final String duration;

  MediaItemModel({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.duration,
  });
}

// ==========================================
// GESTOR DE REPRODUCCIÓN (IFRAME EMBEDDED)
// ==========================================
class YMusicPlayerProvider extends ChangeNotifier {
  MediaItemModel? _currentItem;
  YoutubePlayerController? _controller;

  MediaItemModel? get currentItem => _currentItem;
  YoutubePlayerController? get controller => _controller;

  void playItem(MediaItemModel item) {
    _currentItem = item;
    
    _controller?.dispose();
    _controller = YoutubePlayerController(
      initialVideoId: item.id,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        hideControls: true,
        isLive: false,
        forceHD: false,
      ),
    );

    notifyListeners();
  }

  void closePlayer() {
    _controller?.dispose();
    _controller = null;
    _currentItem = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

// ==========================================
// BÓVEDA (FAVORITOS 👍)
// ==========================================
class VaultProvider extends ChangeNotifier {
  final List<MediaItemModel> _favorites = [];

  List<MediaItemModel> get favorites => _favorites;

  bool isFavorite(String id) {
    return _favorites.any((item) => item.id == id);
  }

  void toggleFavorite(MediaItemModel item) {
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
// TEMAS
// ==========================================
class ThemeProvider extends ChangeNotifier {
  Color _primaryColor = Colors.deepPurple;
  bool _isDarkMode = true;

  Color get primaryColor => _primaryColor;
  bool get isDarkMode => _isDarkMode;

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
      title: 'Media Stream Hub',
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
// NAVEGACIÓN PRINCIPAL
// ==========================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<YMusicPlayerProvider>(context);

    final List<Widget> tabs = [
      HomeTab(onNavigateToSearch: () => setState(() => _currentIndex = 2)),
      const SportsTab(),
      const SearchTab(),
      const VaultTab(),
      const SettingsTab(),
    ];

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: tabs,
            ),
          ),
          // MINI-BARRA PERSISTENTE
          if (playerProvider.currentItem != null)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const YMusicPlayerDetailScreen()),
                );
              },
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        playerProvider.currentItem!.thumbnailUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.music_note),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            playerProvider.currentItem!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            playerProvider.currentItem!.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: playerProvider.closePlayer,
                    ),
                  ],
                ),
              ),
            ),
        ],
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
// PESTAÑAS VISTA
// ==========================================
class HomeTab extends StatelessWidget {
  final VoidCallback onNavigateToSearch;

  const HomeTab({super.key, required this.onNavigateToSearch});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🏠 Inicio')),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: onNavigateToSearch,
          icon: const Icon(Icons.search),
          label: const Text('Explorar Música y Videos'),
        ),
      ),
    );
  }
}

class SportsTab extends StatelessWidget {
  const SportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('⚽ Deportes')),
      body: const Center(child: Text('Sección Deportes')),
    );
  }
}

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final yt_exp.YoutubeExplode _yt = yt_exp.YoutubeExplode();
  List<yt_exp.Video> _searchResults = [];
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isLoading = true);

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
      if (mounted) setState(() => _isLoading = false);
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
    final playerProvider = Provider.of<YMusicPlayerProvider>(context, listen: false);
    final vault = Provider.of<VaultProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('🔍 Buscador Multimedia')),
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
                      hintText: 'Buscar canción o artista...',
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
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_searchResults.isEmpty)
              const Expanded(child: Center(child: Text('Escribe algo arriba para buscar', style: TextStyle(color: Colors.grey))))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final video = _searchResults[index];
                    final mediaItem = MediaItemModel(
                      id: video.id.value,
                      title: video.title,
                      author: video.author,
                      thumbnailUrl: video.thumbnails.highResUrl,
                      duration: '${video.duration?.inMinutes ?? 0} min',
                    );
                    final isFav = vault.isFavorite(video.id.value);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: Image.network(
                          video.thumbnails.lowResUrl,
                          width: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.music_note),
                        ),
                        title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${video.author} • ${mediaItem.duration}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isFav ? Icons.thumb_up : Icons.thumb_up_outlined,
                                color: isFav ? Theme.of(context).colorScheme.primary : null,
                              ),
                              onPressed: () => vault.toggleFavorite(mediaItem),
                            ),
                            IconButton(
                              icon: const Icon(Icons.play_circle_fill, size: 36, color: Colors.deepPurple),
                              onPressed: () {
                                playerProvider.playItem(mediaItem);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const YMusicPlayerDetailScreen()),
                                );
                              },
                            ),
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
// REPRODUCTOR EN PANTALLA COMPLETA
// ==========================================
class YMusicPlayerDetailScreen extends StatelessWidget {
  const YMusicPlayerDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<YMusicPlayerProvider>(context);
    final vault = Provider.of<VaultProvider>(context);
    final item = playerProvider.currentItem;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No hay contenido seleccionado')),
      );
    }

    final isFav = vault.isFavorite(item.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📻 Reproductor'),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.thumb_up : Icons.thumb_up_outlined,
              color: isFav ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: () => vault.toggleFavorite(item),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                item.thumbnailUrl,
                width: double.infinity,
                height: 280,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 280,
                  color: Colors.grey[900],
                  child: const Icon(Icons.music_note, size: 80, color: Colors.white70),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              item.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              item.author,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            
            // Player incrustado
            if (playerProvider.controller != null)
              SizedBox(
                height: 1,
                width: 1,
                child: YoutubePlayer(
                  controller: playerProvider.controller!,
                  showVideoProgressIndicator: false,
                ),
              ),

            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 20),
                  SizedBox(width: 8),
                  Text('Conexión nativa activa', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// BÓVEDA (FAVORITOS 👍)
// ==========================================
class VaultTab extends StatelessWidget {
  const VaultTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vault = Provider.of<VaultProvider>(context);
    final playerProvider = Provider.of<YMusicPlayerProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('👍 Mi Bóveda (Favoritos)')),
      body: vault.favorites.isEmpty
          ? const Center(
              child: Text(
                'Aún no tienes canciones favoritas.\n¡Presiona 👍 en el buscador para agregarlas!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: vault.favorites.length,
              itemBuilder: (context, index) {
                final item = vault.favorites[index];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      item.thumbnailUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.music_note),
                    ),
                  ),
                  title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(item.author),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_circle_fill, size: 36),
                    onPressed: () {
                      playerProvider.playItem(item);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const YMusicPlayerDetailScreen()),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('🎨 Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SwitchListTile(
            title: const Text('Modo Oscuro'),
            value: themeProvider.isDarkMode,
            onChanged: (val) => themeProvider.toggleThemeMode(),
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Compartir App'),
            onTap: () => Share.share('¡Prueba mi app multimedia!'),
          ),
        ],
      ),
    );
  }
}
