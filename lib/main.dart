import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

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
// PESTAÑA 2: PODCASTS
// ==========================================
class PodcastsTab extends StatelessWidget {
  const PodcastsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🎙️ Podcasts Destacados')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.mic, color: Colors.purple, size: 36),
              title: const Text('Relatos e Historias de la Noche'),
              subtitle: const Text('Episodio de Terror • 45 min'),
              trailing: IconButton(
                icon: const Icon(Icons.play_circle_fill, size: 36),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PlayerScreen(
                        videoId: 'kXYiU_JCYtU',
                        title: 'Relatos e Historias de la Noche',
                        author: 'Podcast Oficial',
                        isAudioOnlyDefault: true,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PESTAÑA 3: BUSCADOR YOUTUBE
// ==========================================
class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  final yt_exp.YoutubeExplode _yt = yt_exp.YoutubeExplode();
  List<yt_exp.Video> _searchResults = [];
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
                          icon: const Icon(Icons.play_circle_fill, size: 36),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlayerScreen(
                                  videoId: video.id.value,
                                  title: video.title,
                                  author: video.author,
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
// PANTALLA DEL REPRODUCTOR (VIDEO Y SOLO AUDIO)
// ==========================================
class PlayerScreen extends StatefulWidget {
  final String videoId;
  final String title;
  final String author;
  final bool isAudioOnlyDefault;

  const PlayerScreen({
    super.key,
    required this.videoId,
    required this.title,
    required this.author,
    this.isAudioOnlyDefault = false,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final yt_exp.YoutubeExplode _yt = yt_exp.YoutubeExplode();
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _isAudioOnly = false;
  String _statusMessage = 'Extrayendo enlace de reproducción...';

  @override
  void initState() {
    super.initState();
    _isAudioOnly = widget.isAudioOnlyDefault;
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Cargando contenido...';
    });

    try {
      final manifest = await _yt.videos.streamsClient.getManifest(widget.videoId);
      
      String streamUrl;
      if (_isAudioOnly) {
        final audioStream = manifest.audioOnly.withHighestBitrate();
        streamUrl = audioStream.url.toString();
      } else {
        final muxedStream = manifest.muxed.withHighestBitrate();
        streamUrl = muxedStream.url.toString();
      }

      _videoPlayerController?.dispose();
      _chewieController?.dispose();

      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _isAudioOnly ? 16 / 9 : _videoPlayerController!.value.aspectRatio,
        allowFullScreen: !_isAudioOnly,
        showControls: !_isAudioOnly,
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error al cargar transmisión: $e';
      });
    }
  }

  void _toggleAudioOnly(bool value) {
    if (_isAudioOnly == value) return;
    setState(() {
      _isAudioOnly = value;
    });
    _initializePlayer();
  }

  @override
  void dispose() {
    _yt.close();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isAudioOnly ? '📻 Reproductor Radio' : '🎬 Reproductor Video'),
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
                  : _isAudioOnly
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.radio, size: 64, color: Colors.purpleAccent),
                              const SizedBox(height: 8),
                              const Text('Modo Solo Audio Activado', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: Icon(_videoPlayerController!.value.isPlaying ? Icons.pause_circle : Icons.play_circle, size: 48, color: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        _videoPlayerController!.value.isPlaying
                                            ? _videoPlayerController!.pause()
                                            : _videoPlayerController!.play();
                                      });
                                    },
                                  ),
                                ],
                              )
                            ],
                          ),
                        )
                      : Chewie(controller: _chewieController!),
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
                SwitchListTile(
                  title: const Text('Modo Solo Audio (Ahorro de datos)'),
                  subtitle: const Text('Ideal para escuchar con pantalla en segundo plano'),
                  value: _isAudioOnly,
                  onChanged: _toggleAudioOnly,
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
// PESTAÑAS BÓVEDA Y AJUSTES
// ==========================================
class VaultTab extends StatelessWidget {
  const VaultTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('👍 Mi Bóveda')),
      body: const Center(child: Text('Lista de Me Gusta guardados')),
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
