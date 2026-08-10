import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:audio_session/audio_session.dart';

void main() async {
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
// PROVEEDOR DE BÓVEDA
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
// TEMAS Y COLORES
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
// NAVEGACIÓN PRINCIPAL CON DRAWER
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
// PESTAÑA INICIO
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

// ==========================================
// PESTAÑA DEPORTES
// ==========================================
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

// ==========================================
// PESTAÑA BUSCADOR
// ==========================================
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
    final vault = Provider.of<VaultProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('🔍 Buscador de Prueba')),
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
                    final isFav = vault.isFavorite(video.id.value);

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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlayerScreen(
                                  videoId: video.id.value,
                                  title: video.title,
                                  author: video.author,
                                  thumbnailUrl: video.thumbnails.highResUrl,
                                ),
                              ),
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
// REPRODUCTOR ESPECÍFICO PARA SEGUNDO PLANO
// ==========================================
class PlayerScreen extends StatefulWidget {
  final String videoId;
  final String title;
  final String author;
  final String thumbnailUrl;

  const PlayerScreen({
    super.key,
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final yt_exp.YoutubeExplode _yt = yt_exp.YoutubeExplode();
  VideoPlayerController? _videoPlayerController;
  final ja.AudioPlayer _audioPlayer = ja.AudioPlayer();

  bool _isLoading = true;
  bool _isBackgroundMode = false;
  String _statusMessage = 'Cargando contenido...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _configureAudioSession();
    _initializePlayer();
  }

  // Configura a Android para priorizar el audio sobre la pantalla
  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _statusMessage = _isBackgroundMode ? 'Activando servicio de fondo...' : 'Cargando video...';
    });

    try {
      final manifest = await _yt.videos.streamsClient.getManifest(widget.videoId);

      _videoPlayerController?.dispose();
      await _audioPlayer.stop();

      if (_isBackgroundMode) {
        // MODO SEGUNDO PLANO: Usa únicamente el stream de audio directo en just_audio
        final audioStream = manifest.audioOnly.withHighestBitrate();
        await _audioPlayer.setUrl(audioStream.url.toString());
        _audioPlayer.play();
      } else {
        // MODO VIDEO NORMAL
        final muxedStreams = manifest.muxed.toList();
        String? streamUrl;

        if (muxedStreams.isNotEmpty) {
          streamUrl = muxedStreams.first.url.toString();
        } else if (manifest.audioOnly.isNotEmpty) {
          streamUrl = manifest.audioOnly.first.url.toString();
        }

        if (streamUrl == null) throw Exception("Stream no disponible");

        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
        await _videoPlayerController!.initialize();
        _videoPlayerController!.play();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _statusMessage = 'Error al cargar el audio/video.';
      });
    }
  }

  void _toggleBackgroundMode(bool value) {
    if (_isBackgroundMode == value) return;
    setState(() => _isBackgroundMode = value);
    _initializePlayer();
  }

  @override
  void dispose() {
    _yt.close();
    _videoPlayerController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isBackgroundMode ? '📻 Modo 2do Plano (Bloqueable)' : '🎬 Modo Video'),
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(_statusMessage, style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    )
                  : _hasError
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_statusMessage, style: const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _initializePlayer, child: const Text('Reintentar')),
                            ],
                          ),
                        )
                      : _isBackgroundMode
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(
                                  child: Image.network(
                                    widget.thumbnailUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox(),
                                  ),
                                ),
                                Positioned.fill(child: Container(color: Colors.black.withOpacity(0.85))),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.graphic_eq, size: 56, color: Colors.purpleAccent),
                                    const SizedBox(height: 8),
                                    const Text(
                                      '¡Modo 2do Plano Activo!\nPrueba apagar la pantalla de tu Pixel',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 16),
                                    StreamBuilder<ja.PlayerState>(
                                      stream: _audioPlayer.playerStateStream,
                                      builder: (context, snapshot) {
                                        final isPlaying = snapshot.data?.playing ?? false;
                                        return IconButton(
                                          icon: Icon(
                                            isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                            size: 64,
                                            color: Colors.white,
                                          ),
                                          onPressed: () {
                                            isPlaying ? _audioPlayer.pause() : _audioPlayer.play();
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                VideoPlayer(_videoPlayerController!),
                                VideoProgressIndicator(_videoPlayerController!, allowScrubbing: true),
                                Center(
                                  child: IconButton(
                                    icon: Icon(
                                      _videoPlayerController!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                      size: 64,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _videoPlayerController!.value.isPlaying
                                            ? _videoPlayerController!.pause()
                                            : _videoPlayerController!.play();
                                      });
                                    },
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
                Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(widget.author, style: const TextStyle(color: Colors.grey)),
                const Divider(height: 32),
                Card(
                  color: Colors.deepPurple.withOpacity(0.2),
                  child: SwitchListTile(
                    title: const Text('Activar Modo 2do Plano'),
                    subtitle: const Text('Permite bloquear la pantalla o salir de la app sin detener la música'),
                    value: _isBackgroundMode,
                    onChanged: _toggleBackgroundMode,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// BÓVEDA Y AJUSTES
// ==========================================
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
