import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;

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
// GESTOR DE REPRODUCCIÓN (PIPED PROXY BACKEND)
// ==========================================
class YMusicPlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  
  // Instancias públicas de Piped API
  final List<String> _pipedInstances = [
    'https://pipedapi.kavin.rocks',
    'https://api.piped.private.coffee',
    'https://pipedapi.mha.fi',
  ];

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

  // Método para consultar la API de Búsqueda de Piped
  Future<List<MediaItemModel>> searchPiped(String query) async {
    for (String instance in _pipedInstances) {
      try {
        final url = Uri.parse('$instance/search?q=${Uri.encodeComponent(query)}&filter=music');
        final response = await http.get(url).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List items = data['items'] ?? [];
          
          return items.where((item) => item['type'] == 'stream').map((item) {
            final String videoId = (item['url'] as String).replaceAll('/watch?v=', '');
            return MediaItemModel(
              id: videoId,
              title: item['title'] ?? 'Sin título',
              author: item['uploaderName'] ?? 'Desconocido',
              thumbnailUrl: item['thumbnail'] ?? '',
              duration: '${(item['duration'] ?? 0) ~/ 60} min',
            );
          }).toList();
        }
      } catch (_) {
        continue; // Si falla una instancia, intenta con la siguiente
      }
    }
    return [];
  }

  // Método para extraer el Stream Directo de Audio vía Proxy
  Future<void> playItem(MediaItemModel item) async {
    _currentItem = item;
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      await _player.stop();
      String? audioUrl = item.directStreamUrl;

      // Si es de YouTube, obtenemos el stream directo desde el Proxy
      if (audioUrl == null) {
        audioUrl = await _fetchAudioUrlFromProxy(item.id);
      }

      if (audioUrl == null || audioUrl.isEmpty) {
        throw Exception("No se pudo obtener el audio desde el proxy");
      }

      await _player.setUrl(audioUrl);
      await _player.play();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _hasError = true;
      notifyListeners();
    }
  }

  Future<String?> _fetchAudioUrlFromProxy(String videoId) async {
    for (String instance in _pipedInstances) {
      try {
        final url = Uri.parse('$instance/streams/$videoId');
        final response = await http.get(url).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List audioStreams = data['audioStreams'] ?? [];

          if (audioStreams.isNotEmpty) {
            // Seleccionar el stream de mejor calidad (M4A / AAC)
            final bestStream = audioStreams.firstWhere(
              (stream) => stream['mimeType']?.contains('audio/mp4') ?? false,
              orElse: () => audioStreams.first,
            );
            return bestStream['url'] as String?;
          }
        }
      } catch (_) {
        continue; // Fallback a la siguiente instancia
      }
    }
    return null;
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
  int _currentIndex = 2; // Pestaña Buscar

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
              subtitle: const Text('Noticias y Deportes en vivo'),
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
  List<MediaItemModel> _res = [];
  bool _isLoading = false;

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() => _isLoading = true);
    final player = Provider.of<YMusicPlayerProvider>(context, listen: false);
    final results = await player.searchPiped(q);
    setState(() {
      _res = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<YMusicPlayerProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: const Text('🔍 Buscar Música (Piped Proxy)')),
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
              const Text('Error al conectar con la fuente del Proxy', style: TextStyle(color: Colors.redAccent))
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
