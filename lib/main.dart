import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;
import 'package:video_player/video_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => VaultProvider()),
        ChangeNotifierProvider(create: (_) => GlobalPlayerProvider()),
      ],
      child: const MediaApp(),
    ),
  );
}

// ==========================================
// GESTOR GLOBAL DE REPRODUCCIÓN (MANTIENE EL SONIDO AL NAVEGAR)
// ==========================================
class GlobalMediaItem {
  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;

  GlobalMediaItem({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
  });
}

class GlobalPlayerProvider extends ChangeNotifier {
  final yt_exp.YoutubeExplode _yt = yt_exp.YoutubeExplode();
  VideoPlayerController? _videoPlayerController;
  GlobalMediaItem? _currentItem;

  bool _isLoading = false;
  bool _hasError = false;
  bool _isPlaying = false;

  GlobalMediaItem? get currentItem => _currentItem;
  VideoPlayerController? get controller => _videoPlayerController;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  bool get isPlaying => _isPlaying;

  Future<void> playItem(GlobalMediaItem item) async {
    _currentItem = item;
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      final manifest = await _yt.videos.streamsClient.getManifest(item.id);
      final muxedStreams = manifest.muxed.toList();
      String? streamUrl;

      if (muxedStreams.isNotEmpty) {
        streamUrl = muxedStreams.first.url.toString();
      } else if (manifest.audioOnly.isNotEmpty) {
        streamUrl = manifest.audioOnly.first.url.toString();
      }

      if (streamUrl == null) throw Exception("Stream no disponible");

      await _videoPlayerController?.dispose();
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
      await _videoPlayerController!.initialize();
      _videoPlayerController!.play();

      _videoPlayerController!.addListener(() {
        if (_videoPlayerController != null) {
          final isControllerPlaying = _videoPlayerController!.value.isPlaying;
          if (_isPlaying != isControllerPlaying) {
            _isPlaying = isControllerPlaying;
            notifyListeners();
          }
        }
      });

      _isPlaying = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _hasError = true;
      notifyListeners();
    }
  }

  void togglePlayPause() {
    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      if (_videoPlayerController!.value.isPlaying) {
        _videoPlayerController!.pause();
        _isPlaying = false;
      } else {
        _videoPlayerController!.play();
        _isPlaying = true;
      }
      notifyListeners();
    }
  }

  void closePlayer() {
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
    _currentItem = null;
    _isPlaying = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _yt.close();
    _videoPlayerController?.dispose();
    super.dispose();
  }
}

// ==========================================
// PROVEEDOR DE BÓVEDA
// ==========================================
class VaultProvider extends ChangeNotifier {
  final List<GlobalMediaItem> _favorites = [];

  List<GlobalMediaItem> get favorites => _favorites;

  bool isFavorite(String id) {
    return _favorites.any((item) => item.id == id);
  }

  void toggleFavorite(GlobalMediaItem item) {
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
// NAVEGACIÓN CON MINI-REPRODUCTOR PERSISTENTE
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
    final playerProvider = Provider.of<GlobalPlayerProvider>(context);

    final List<Widget> tabs = [
      HomeTab(onNavigateToSearch: () {
        setState(() => _currentIndex = 2);
      }),
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
          // MINI-BARRA REPRODUCTORA INFERIOR
          if (playerProvider.currentItem != null)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlayerDetailScreen()),
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
                    if (playerProvider.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else
                      IconButton(
                        icon: Icon(playerProvider.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 36),
                        onPressed: playerProvider.togglePlayPause,
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
// PESTAÑAS
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
          label: const Text('Ir al Buscador'),
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
    final playerProvider = Provider.of<GlobalPlayerProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('🔍 Buscador')),
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
                      hintText: 'Buscar un video o canción...',
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
              const Expanded(child: Center(child: Text('Escribe algo arriba para buscar')))
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
                          icon: const Icon(Icons.play_circle_fill, size: 36, color: Colors.deepPurple),
                          onPressed: () {
                            final mediaItem = GlobalMediaItem(
                              id: video.id.value,
                              title: video.title,
                              author: video.author,
                              thumbnailUrl: video.thumbnails.highResUrl,
                            );

                            playerProvider.playItem(mediaItem);

                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PlayerDetailScreen()),
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
// PANTALLA DETALLADA DEL REPRODUCTOR
// ==========================================
class PlayerDetailScreen extends StatelessWidget {
  const PlayerDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<GlobalPlayerProvider>(context);
    final item = playerProvider.currentItem;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No hay contenido en reproducción')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎬 Reproduciendo'),
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: playerProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : playerProvider.hasError
                      ? const Center(child: Text('Error al cargar la transmisión', style: TextStyle(color: Colors.white)))
                      : Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            VideoPlayer(playerProvider.controller!),
                            VideoProgressIndicator(playerProvider.controller!, allowScrubbing: true),
                            Center(
                              child: IconButton(
                                icon: Icon(
                                  playerProvider.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                  size: 64,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                                onPressed: playerProvider.togglePlayPause,
                              ),
                            ),
                          ],
                        ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(item.author, style: const TextStyle(color: Colors.grey)),
                const Divider(height: 32),
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.deepPurple),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Puedes presionar la flecha ← para regresar. La música seguirá sonando en la mini-barra inferior.',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class VaultTab extends StatelessWidget {
  const VaultTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('👍 Mi Bóveda')),
      body: const Center(child: Text('Bóveda')),
    );
  }
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🎨 Ajustes')),
      body: const Center(child: Text('Ajustes')),
    );
  }
}
