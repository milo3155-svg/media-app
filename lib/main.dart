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
// GESTOR DE REPRODUCCIÓN DUAL (RADIO NATI + YT WEB)
// ==========================================
class YMusicPlayerProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  WebViewController? _webViewController;
  MediaItemModel? _currentItem;
  bool _isLoading = false;

  MediaItemModel? get currentItem => _currentItem;
  WebViewController? get webViewController => _webViewController;
  bool get isLoading => _isLoading;

  YMusicPlayerProvider() {
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 10; Pixel 10 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36');
  }

  Future<void> playItem(MediaItemModel item) async {
    _currentItem = item;
    _isLoading = true;
    notifyListeners();

    // 1. Si es transmisión de radio nativa (.mp3 direct stream)
    if (item.directStreamUrl != null) {
      _webViewController?.loadRequest(Uri.parse('about:blank'));
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(item.directStreamUrl!));
    } 
    // 2. Si es contenido de YouTube
    else {
      await _audioPlayer.stop();
      final String targetUrl = 'https://www.youtube.com/embed/${item.id}?autoplay=1&playsinline=1&controls=1&modestbranding=1&rel=0';
      _webViewController?.loadRequest(Uri.parse(targetUrl));
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> closePlayer() async {
    await _audioPlayer.stop();
    _webViewController?.loadRequest(Uri.parse('about:blank'));
    _currentItem = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
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
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: tabs,
                ),
              ),
              // MINI-BARRA PERSISTENTE AL NAVEGAR
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
          // WEBVIEW OCULTO EN LA RAÍZ PARA EVITAR CORTES AL DAR ATRÁS EN YOUTUBE
          if (playerProvider.currentItem != null &&
              playerProvider.currentItem!.directStreamUrl == null &&
              playerProvider.webViewController != null)
            Positioned(
              left: -9999,
              top: -9999,
              width: 1,
              height: 1,
              child: WebViewWidget(controller: playerProvider.webViewController!),
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

class SportsTab extends StatelessWidget {
  const SportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<YMusicPlayerProvider>(context, listen: false);
    final primaryColor = Theme.of(context).colorScheme.primary;

    final List<Map<String, String>> radioStations = [
      {
        'title': 'W Radio México (Deportes)',
        'author': 'Fútbol & Cobertura 24/7',
        'url': 'https://stream.wradio.com.mx/wradio.mp3',
        'img': 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?w=400',
      },
      {
        'title': 'Radio Formula México',
        'author': 'Noticias & Análisis Deportivo',
        'url': 'https://stream.radioformula.com.mx/formula.mp3',
        'img': 'https://images.unsplash.com/photo-1540747913346-19e32dc3e97e?w=400',
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
// REPRODUCTOR DETALLADO LIMPIO
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
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 20),
                  SizedBox(width: 8),
                  Text('Transmisión activa • Puedes presionar ← para regresar', style: TextStyle(fontSize: 12)),
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
