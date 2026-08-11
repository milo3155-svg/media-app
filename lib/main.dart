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
// GESTOR DE REPRODUCCIÓN (Doble Motor: Audio/Web)
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
      ..setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36');
  }

  Future<void> playItem(MediaItemModel item) async {
    _currentItem = item;
    _isLoading = true;
    notifyListeners();

    if (item.directStreamUrl != null) {
      _webViewController?.loadRequest(Uri.parse('about:blank'));
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(item.directStreamUrl!));
    } else {
      await _audioPlayer.stop();
      // Usamos el modo embed estándar
      final String targetUrl = 'https://www.youtube.com/embed/${item.id}?autoplay=1&enablejsapi=1&origin=https://www.youtube.com';
      _webViewController?.loadRequest(Uri.parse(targetUrl));
    }

    _isLoading = false;
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
  int _currentIndex = 0;
  @override
  Widget build(BuildContext context) {
    final player = Provider.of<YMusicPlayerProvider>(context);
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: IndexedStack(index: _currentIndex, children: const [
             HomeTab(), SportsTab(), SearchTab(), VaultTab(), SettingsTab()
          ])),
          if (player.currentItem != null)
             ListTile(
               tileColor: Colors.deepPurple.shade900,
               title: Text(player.currentItem!.title, maxLines: 1),
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
// PESTAÑAS Y REPRODUCTOR
// ==========================================
class HomeTab extends StatelessWidget { const HomeTab({super.key}); @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Inicio'))); }

class SportsTab extends StatelessWidget { const SportsTab({super.key}); @override Widget build(BuildContext context) {
  final player = Provider.of<YMusicPlayerProvider>(context, listen: false);
  return Scaffold(body: ListView(children: [
    ListTile(title: const Text('W Radio'), onTap: () => player.playItem(MediaItemModel(id: 'w', title: 'W Radio', author: 'Deportes', thumbnailUrl: '', duration: 'VIVO', directStreamUrl: 'https://stream.wradio.com.mx/wradio.mp3')))
  ]));
}}

class SearchTab extends StatefulWidget { const SearchTab({super.key}); @override State<SearchTab> createState() => _SearchTabState(); }
class _SearchTabState extends State<SearchTab> {
  final _ctrl = TextEditingController();
  List<yt_exp.Video> _res = [];
  Future<void> _search(String q) async {
    final results = await yt_exp.YoutubeExplode().search.search(q);
    setState(() => _res = results.take(10).toList());
  }
  @override Widget build(BuildContext context) {
    final player = Provider.of<YMusicPlayerProvider>(context, listen: false);
    return Scaffold(body: Column(children: [
      TextField(controller: _ctrl, onSubmitted: _search),
      Expanded(child: ListView.builder(itemCount: _res.length, itemBuilder: (c, i) => ListTile(title: Text(_res[i].title), onTap: () => player.playItem(MediaItemModel(id: _res[i].id.value, title: _res[i].title, author: _res[i].author, thumbnailUrl: _res[i].thumbnails.highResUrl, duration: '')))))
    ]));
  }
}

class YMusicPlayerDetailScreen extends StatelessWidget { const YMusicPlayerDetailScreen({super.key}); @override Widget build(BuildContext context) {
  final player = Provider.of<YMusicPlayerProvider>(context);
  return Scaffold(appBar: AppBar(title: const Text('Reproductor')), body: Column(children: [
    if (player.currentItem?.directStreamUrl == null && player.webViewController != null)
      Expanded(child: WebViewWidget(controller: player.webViewController!))
    else 
      const Expanded(child: Icon(Icons.radio, size: 100))
  ]));
}}

class VaultTab extends StatelessWidget { const VaultTab({super.key}); @override Widget build(BuildContext context) => const Scaffold(); }
class SettingsTab extends StatelessWidget { const SettingsTab({super.key}); @override Widget build(BuildContext context) => const Scaffold(); }
