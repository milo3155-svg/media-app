import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.example.media_app.channel.audio',
      androidNotificationChannelName: 'Reproducción de Música',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    debugPrint("Error inicializando notificación: $e");
  }

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
  final String? directStreamUrl;

  MediaItemModel({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    this.directStreamUrl,
  });
}

// ==========================================
// GESTOR DE REPRODUCCIÓN Y DIAGNÓSTICO
// ==========================================
class YMusicPlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final String _backendUrl = 'https://mi-media-proxy.onrender.com';

  MediaItemModel? _currentItem;
  bool _isLoading = false;
  bool _isPlaying = false;
  String? _errorMessage;

  MediaItemModel? get currentItem => _currentItem;
  bool get isLoading => _isLoading;
  bool get isPlaying => _isPlaying;
  String? get errorMessage => _errorMessage;

  YMusicPlayerProvider() {
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isLoading = state.processingState == ProcessingState.loading || state.processingState == ProcessingState.buffering;
      notifyListeners();
    });

    _player.playbackEventStream.listen((event) {}, onError: (Object e, StackTrace st) {
      _errorMessage = "Error reproductor: $e";
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<List<MediaItemModel>> searchMusic(String query) async {
    try {
      final url = Uri.parse('$_backendUrl/api/search?q=${Uri.encodeComponent(query)}');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((item) {
          return MediaItemModel(
            id: item['id'] ?? '',
            title: item['title'] ?? 'Sin título',
            author: item['author'] ?? 'Artista',
            thumbnailUrl: item['thumbnailUrl'] ?? '',
            directStreamUrl: item['streamUrl'] ?? '',
          );
        }).toList();
      }
    } catch (e) {
      debugPrint("Error en búsqueda backend: $e");
    }
    return [];
  }

  Future<void> playItem(MediaItemModel item) async {
    _currentItem = item;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _player.stop();
      final String? audioUrl = item.directStreamUrl;

      if (audioUrl == null || audioUrl.isEmpty) {
        throw Exception("URL de audio vacía");
      }

      // --- WATCHDOG: Forzar error si carga > 8 segundos ---
      bool loadFinished = false;
      Future.delayed(const Duration(seconds: 8), () {
        if (!loadFinished && _isLoading) {
          _errorMessage = "El servidor tardó demasiado. Intenta otra canción.";
          _isLoading = false;
          _player.stop();
          notifyListeners();
        }
      });
      // ----------------------------------------------------

      await _player.setUrl(audioUrl);
      _player.play();
      loadFinished = true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = "Fallo al cargar: ${e.toString()}";
      notifyListeners();
    }
  }

  void togglePlayPause() {
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
    notifyListeners();
  }

  void stop() {
    _player.stop();
    _currentItem = null;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

// ==========================================
// ESTRUCTURA PRINCIPAL
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
  int _currentIndex = 2;

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

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Inicio')));
}

class SportsTab extends StatelessWidget {
  const SportsTab({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Deportes')));
}

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});
  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _ctrl = TextEditingController();
  List<MediaItemModel> _res = [];
  bool _isLoading = false;

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() => _isLoading = true);
    final player = Provider.of<YMusicPlayerProvider>(context, listen: false);
    final results = await player.searchMusic(q);
    setState(() {
      _res = results;
      _isLoading = false;
    });
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
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar canción...',
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
                    final item = _res[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Image.network(item.thumbnailUrl, width: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note)),
                        title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(item.author),
                        trailing: const Icon(Icons.play_circle_fill, color: Colors.deepPurple, size: 32),
                        onTap: () {
                          player.playItem(item);
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
      appBar: AppBar(title: const Text('📻 Reproductor')),
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
            else if (player.errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(player.errorMessage!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
              )
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
