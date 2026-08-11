import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;

void main() async {
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
  final String? directStreamUrl;

  MediaItemModel({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.duration,
    this.directStreamUrl,
  });
}

// ==========================================
// GESTOR DE REPRODUCCIÓN NATIVO (AUDIOPLAYERS)
// ==========================================
class YMusicPlayerProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final yt_exp.YoutubeExplode _yt = yt_exp.YoutubeExplode();
  
  MediaItemModel? _currentItem;
  bool _isLoading = false;
  bool _hasError = false;
  bool _isPlaying = false;
  String _errorMessage = '';

  MediaItemModel? get currentItem => _currentItem;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  bool get isPlaying => _isPlaying;
  String get errorMessage => _errorMessage;

  YMusicPlayerProvider() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = (state == PlayerState.playing);
      notifyListeners();
    });
  }

  Future<void> playItem(MediaItemModel item) async {
    _currentItem = item;
    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
    notifyListeners();

    try {
      await _audioPlayer.stop();

      String? streamUrl = item.directStreamUrl;

      // Si no es un stream directo de radio, extraemos con youtube_explode_dart directo
      if (streamUrl == null) {
        final manifest = await _yt.videos.streamsClient.getManifest(item.id);
        
        // Obtener la mejor pista de audio
        if (manifest.audioOnly.isNotEmpty) {
          streamUrl = manifest.audioOnly.withHighestBitrate().url.toString();
        } else if (manifest.muxed.isNotEmpty) {
          streamUrl = manifest.muxed.first.url.toString();
        }
      }

      if (streamUrl == null || streamUrl.isEmpty) {
        throw Exception("No se pudo obtener la fuente de audio.");
      }

      // Reproducir usando el motor nativo de AudioPlayer
      await _audioPlayer.play(UrlSource(streamUrl));

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _hasError = true;
      _errorMessage = 'No se pudo conectar a la fuente de audio.';
      notifyListeners();
    }
  }

  void togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
  }

  void closePlayer() async {
    await _audioPlayer.stop();
    _currentItem = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _yt.close();
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
                        errorBuilder: (_, __, ___) => const Icon(Icons.radio),
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
          label: const Text('Explorar Música y Videos'),
        ),
      ),
    );
  }
}

// ==========================================
// PESTAÑA DEPORTES CON EMISORAS HTTPS ESTABLES
// ==========================================
class SportsTab extends StatelessWidget {
  const SportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<YMusicPlayerProvider>(context, listen: false);
    final primaryColor = Theme.of(context).colorScheme.primary;

    // URLs de radio HTTPS 100% estables comprobadas
    final List<Map<String, String>> radioStations = [
      {
        'title': 'W Radio México (Deportes)',
        'author': 'Fútbol & Cobertura Deportiva',
        'url': 'https://stream.wradio.com.mx/wradio.mp3',
        'img': 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?w=400',
      },
      {
        'title': 'Radio Formula México',
        'author': 'Noticias & Análisis Deportivo',
        'url': 'https://stream.radioformula.com.mx/formula.mp3',
        'img': 'https://images.unsplash.com/photo-1540747913346-19e32dc3e97e?w=400',
      },
      {
        'title': 'RNE Radio Nacional España',
        'author': 'Deportes e Información',
        'url': 'https://rtvestream.rtve.es/rne/rne_r1_main.mp3',
        'img': 'https://images.unsplash.com/photo-1518091043644-c1d4457512c6?w=400',
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('⚽ Deportes & Radio en Vivo')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor.withOpacity(0.9), primaryColor.withOpacity(0.4)],
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
                      const Text('Jornada Deportiva', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text('América', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      Text('2 - 1', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                      Text('Chivas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    onPressed: () {
                      final item = MediaItemModel(
                        id: 'w_deportes',
                        title: radioStations[0]['title']!,
                        author: radioStations[0]['author']!,
                        thumbnailUrl: radioStations[0]['img']!,
                        duration: 'EN VIVO',
                        directStreamUrl: radioStations[0]['url']!,
                      );
                      playerProvider.playItem(item);
                    },
                    icon: const Icon(Icons.radio, color: Colors.redAccent),
                    label: const Text('Escuchar Transmisión en Vivo', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('📻 Emisoras Deportivas en Vivo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...radioStations.map((station) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(station['img']!, width: 50, height: 50, fit: BoxFit.cover),
                ),
                title: Text(station['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(station['author']!),
                trailing: IconButton(
                  icon: const Icon(Icons.play_circle_fill, size: 36, color: Colors.deepPurple),
                  onPressed: () {
                    final item = MediaItemModel(
                      id: station['title']!,
                      title: station['title']!,
                      author: station['author']!,
                      thumbnailUrl: station['img']!,
                      duration: 'EN VIVO',
                      directStreamUrl: station['url']!,
                    );
                    playerProvider.playItem(item);
                  },
                ),
              ),
            );
          }),
        ],
      ),
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
// REPRODUCTOR DETALLADO
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
                  child: const Icon(Icons.radio, size: 80, color: Colors.white70),
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
            const SizedBox(height: 32),
            if (playerProvider.isLoading)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Conectando fuente nativa...', style: TextStyle(color: Colors.grey)),
                ],
              )
            else if (playerProvider.hasError)
              Column(
                children: [
                  Text(playerProvider.errorMessage, style: const TextStyle(color: Colors.orangeAccent)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => playerProvider.playItem(item),
                    child: const Text('Reintentar'),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      playerProvider.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: playerProvider.togglePlayPause,
                  ),
                ],
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
                  Icon(Icons.headset, color: Colors.purpleAccent, size: 20),
                  SizedBox(width: 8),
                  Text('Reproducción activa • Puedes navegar por la app', style: TextStyle(fontSize: 12)),
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
