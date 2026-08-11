import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;
import 'package:webview_flutter/webview_flutter.dart';

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
// GESTOR DE REPRODUCCIÓN (Audio / Web Engine)
// ==========================================
class YMusicPlayerProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  WebViewController? _webViewController;
  MediaItemModel? _currentItem;

  MediaItemModel? get currentItem => _currentItem;
  WebViewController? get webViewController => _webViewController;

  YMusicPlayerProvider() {
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36');
  }

  Future<void> playItem(MediaItemModel item) async {
    _currentItem = item;
    notifyListeners();

    if (item.directStreamUrl != null) {
      _webViewController?.loadRequest(Uri.parse('about:blank'));
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(item.directStreamUrl!));
    } else {
      await _audioPlayer.stop();
      final String targetUrl = 'https://www.youtube.com/embed/${item.id}?autoplay=1&enablejsapi=1&origin=https://www.youtube.com';
      _webViewController?.loadRequest(Uri.parse(targetUrl));
    }

    notifyListeners();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _webViewController?.loadRequest(Uri.parse('about:blank'));
    _currentItem = null;
    notifyListeners();
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
  int _currentIndex = 2; // Iniciar en Buscar directamente
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
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.music_note),
                ),
              ),
              title: Text(player.currentItem!.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(player.currentItem!.author, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(icon: const Icon(Icons.close), onPressed: player.stop),
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
// PESTAÑAS RESTAURADAS
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
              title: const Text('W Radio México'),
              subtitle: const Text('Transmisión de Deportes 24/7'),
              trailing: const Icon(Icons.play_circle_fill, size: 32),
              onTap: () => player.playItem(
                MediaItemModel(
                  id: 'w_radio',
                  title: 'W Radio México',
                  author: 'Deportes',
                  thumbnailUrl: 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?w=400',
                  duration: 'EN VIVO',
                  directStreamUrl: 'https://stream.wradio.com.mx/wradio.mp3',
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
    return Scaffold(
      appBar: AppBar(title: const Text('📻 Reproductor')),
      body: Column(
        children: [
          if (player.currentItem?.directStreamUrl == null && player.webViewController != null)
            SizedBox(
              height: 240,
              width: double.infinity,
              child: WebViewWidget(controller: player.webViewController!),
            )
          else
            const SizedBox(
              height: 240,
              child: Center(child: Icon(Icons.radio, size: 100, color: Colors.deepPurple)),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              player.currentItem?.title ?? '',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
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
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Bóveda')));
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Ajustes')));
}
