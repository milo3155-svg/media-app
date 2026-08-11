import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // CONFIGURACIÓN DE AUDIO DE 1ER NIVEL EN ANDROID
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

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
// GESTOR DE REPRODUCCIÓN (JUST_AUDIO + SESSION)
// ==========================================
class YMusicPlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final yt_exp.YoutubeExplode _yt = yt_exp.YoutubeExplode();
  
  MediaItemModel? _currentItem;
  bool _isLoading = false;
  bool _isPlaying = false;
  bool _hasError = false;

  MediaItemModel? get currentItem => _currentItem;
  bool get isLoading => _isLoading;
  bool get isPlaying => _isPlaying;
  bool get hasError => _hasError;

  YMusicPlayerProvider() {
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
    });
  }

  Future<void> playItem(MediaItemModel item) async {
    _currentItem = item;
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      await _player.stop();
      String? audioUrl = item.directStreamUrl;

      if (audioUrl == null) {
        final manifest = await _yt.videos.streamsClient.getManifest(item.id);
        final audioStreams = manifest.audioOnly;
        if (audioStreams.isNotEmpty) {
          audioUrl = audioStreams.withHighestBitrate().url.toString();
        } else {
          throw Exception("No audio streams");
        }
      }

      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(audioUrl),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
          },
        ),
      );

      _player.play();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _hasError = true;
      notifyListeners();
    }
  }

  void togglePlayPause() {
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _currentItem = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    _yt.close();
    super.dispose();
  }
}

// ==========================================
// PROVEEDORES DE ESTADO
// ==========================================
class VaultProvider extends ChangeNotifier {
  final List<MediaItemModel> _favorites = [];
  List<MediaItemModel> get favorites => _favorites;
  bool isFavorite(String id) => _favorites.any((item) => item.id == id);
  void toggleFavorite(MediaItemModel item) {
    final index = _favorites.indexWhere((e) => e.id == item.id);
    if (index >= 0) _favorites.removeAt(index); else _favorites.add(item);
    notifyListeners();
  }
}

class ThemeProvider extends ChangeNotifier {
  Color _primaryColor = Colors.deepPurple;
  bool _isDarkMode = true;
  Color get primaryColor => _primaryColor;
  bool get isDarkMode => _isDarkMode;
  void toggleThemeMode() { _isDarkMode = !_isDarkMode; notifyListeners(); }
}

// ==========================================
// APLICACIÓN PRINCIPAL
// ==========================================
class MediaApp extends StatelessWidget {
  const MediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: theme.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light, colorSchemeSeed: theme.primaryColor),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark, colorSchemeSeed: theme.primaryColor),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 1; // Abrir en la pestaña Deportes por defecto

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<YMusicPlayerProvider>(context);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                HomeTab(),
                SportsTab(),
                SearchTab(),
                VaultTab(),
                SettingsTab(),
              ],
            ),
          ),
          if (player.currentItem != null)
            ListTile(
              tileColor: Colors.deepPurple.shade900,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  player.currentItem!.thumbnailUrl,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.music_note),
                ),
              ),
              title: Text(player.currentItem!.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(player.currentItem!.author, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(player.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 32),
                    onPressed: player.togglePlayPause,
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: player.stop),
                ],
              ),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const YMusicPlayerDetailScreen())),
            )
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.sports_soccer), label: 'Deportes'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
          NavigationDestination(icon: Icon(Icons.favorite), label: 'Bóveda'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}

// ==========================================
// PESTAÑAS
// ==========================================
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Inicio')));
}

class SportsTab extends StatelessWidget {
  const SportsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final player = Provider.of<YMusicPlayerProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: const Text('⚽ Deportes & Radio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.radio, size: 36, color: Colors.deepPurple),
              title: const Text('Radio Fórmula México'),
              subtitle: const Text('Noticias y Deportes en vivo (Stream HTTPS)'),
              trailing: const Icon(Icons.play_circle_fill, size: 32),
              onTap: () => player.playItem(
                MediaItemModel(
                  id: 'radio_formula',
                  title: 'Radio Fórmula México',
                  author: 'Deportes / Noticias',
                  thumbnailUrl: 'https://images.unsplash.com/photo-1540747913346-19e32dc3e97e?w=400',
                  duration: 'EN VIVO',
                  directStreamUrl: 'https://stream.radioformula.com.mx/formula.mp3',
                ),
              ),
            ),
          )
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

class _SearchTabState extends State<SearchTab> {
  final _ctrl = TextEditingController();
  final yt_exp.YoutubeExplode _yt = yt_exp.YoutubeExplode();
  List<yt_exp.Video> _res = [];
  bool _isLoading = false;

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final results = await _yt.search.search(q);
      setState(() => _res = results.take(15).toList());
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<YMusicPlayerProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: const Text('🔍 Buscar Música')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'Escribe una canción o artista...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => _search(_ctrl.text)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: _search,
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _res.length,
                  itemBuilder: (c, i) {
                    final video = _res[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Image.network(video.thumbnails.lowResUrl, width: 50, fit: BoxFit.cover),
                        title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(video.author),
                        trailing: const Icon(Icons.play_circle_fill, color: Colors.deepPurple, size: 32),
                        onTap: () {
                          player.playItem(
                            MediaItemModel(
                              id: video.id.value,
                              title: video.title,
                              author: video.author,
                              thumbnailUrl: video.thumbnails.highResUrl,
                              duration: '${video.duration?.inMinutes ?? 0} min',
                            ),
                          );
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const YMusicPlayerDetailScreen()));
                        },
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

class YMusicPlayerDetailScreen extends StatelessWidget {
  const YMusicPlayerDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<YMusicPlayerProvider>(context);
    final item = player.currentItem;

    if (item == null) return const Scaffold(body: Center(child: Text('Sin selección')));

    return Scaffold(
      appBar: AppBar(title: const Text('📻 Reproductor Nativo')),
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
            const SizedBox(height: 24),
            Text(
              item.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(item.author, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            if (player.isLoading)
              const CircularProgressIndicator()
            else if (player.hasError)
              const Text('Error al conectar fuente nativa', style: TextStyle(color: Colors.redAccent))
            else
              IconButton(
                icon: Icon(player.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 72, color: Colors.deepPurple),
                onPressed: player.togglePlayPause,
              ),
          ],
        ),
      ),
    );
  }
}

class VaultTab extends StatelessWidget {
  const VaultTab({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Bóveda')));
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Ajustes')));
}
