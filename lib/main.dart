import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';

// 1. IMPORTAMOS NUESTRO MOTOR AISLADO Y BLINDADO
import 'services/audio_handler.dart';
import 'screens/discover_screens.dart';

class VIPHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..userAgent =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36';
  }
}

late MyAudioHandler audioHandler;
final ValueNotifier<bool> isHDMode = ValueNotifier<bool>(true);
final ValueNotifier<Color> appColor = ValueNotifier<Color>(Colors.cyanAccent);

String formatGlobalDuration(Duration? d) {
  if (d == null || d == Duration.zero) return "";
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return "${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds";
}

Widget buildSafeThumb(String? url, {double? width, required double height, double radius = 8}) {
  final cleanUrl = (url ?? '').trim();
  final placeholder = Container(
    width: width,
    height: height,
    color: const Color(0xFF1F1F1F),
    alignment: Alignment.center,
    child: Icon(Icons.music_note, color: Colors.white38, size: height >= 120 ? 48 : 22),
  );
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: cleanUrl.isEmpty
        ? placeholder
        : Image.network(
            cleanUrl,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
          ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = VIPHttpOverrides();

  await Hive.initFlutter();
  await Hive.openBox('favorites');
  await Hive.openBox('history');
  await Hive.openBox('search_history');
  await Hive.openBox('playlists');

  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.media_app.audio_master_v62',
      androidNotificationChannelName: 'Spotify Killer VIP',
      androidNotificationOngoing: false,
      androidShowNotificationBadge: true,
      androidStopForegroundOnPause: false,
      androidNotificationIcon: 'drawable/ic_notification',
    ),
  ) as MyAudioHandler;

  runApp(const MediaApp());
}

class ConspiracyLogo extends StatelessWidget {
  final double size;
  final Color color;
  const ConspiracyLogo({super.key, this.size = 150.0, required this.color});
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _OsirisEyePainter(color: color)));
  }
}

class _OsirisEyePainter extends CustomPainter {
  final Color color;
  _OsirisEyePainter({required this.color});
  void _drawTextOnLine(Canvas canvas, String text, Offset start, Offset end, double fontSize) {
    final midPoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    canvas.save();
    canvas.translate(midPoint.dx, midPoint.dy);
    canvas.rotate(angle);
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'Courier'),
    );
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout();
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height - 2));
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final p1 = Offset(w * 0.15, h * 0.15);
    final p2 = Offset(w * 0.15, h * 0.85);
    final p3 = Offset(w * 0.90, h * 0.50);
    final playPath = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
    canvas.drawPath(playPath, paint);
    final fontSize = w * 0.08;
    _drawTextOnLine(canvas, "Θ ⅃ Θ", p1, p2, fontSize);
    _drawTextOnLine(canvas, "Δ Ξ", p2, p3, fontSize);
    _drawTextOnLine(canvas, "Θ Ϟ Ι ℟ Ι Ϟ", p3, p1, fontSize);
    final eyeLeft = w * 0.28;
    final eyeRight = w * 0.62;
    final eyeY = h * 0.50;
    final eyeCenterX = w * 0.45;
    final eyePath = Path()
      ..moveTo(eyeLeft, eyeY)
      ..quadraticBezierTo(eyeCenterX, h * 0.32, eyeRight, eyeY)
      ..quadraticBezierTo(eyeCenterX, h * 0.68, eyeLeft, eyeY);
    canvas.drawPath(eyePath, paint);
    final wavePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03;
    canvas.drawCircle(Offset(eyeCenterX, h * 0.50), w * 0.08, wavePaint);
    canvas.drawCircle(Offset(eyeCenterX, h * 0.50), w * 0.03, wavePaint);
    canvas.drawLine(Offset(eyeCenterX - w * 0.12, h * 0.50), Offset(eyeCenterX + w * 0.12, h * 0.50), wavePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

void globalShowOptions(BuildContext context, MediaItem item, Color color) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A1A1A),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      final inQueue = audioHandler.queue.value.any((i) => i.id == item.id);
      final durText = formatGlobalDuration(item.duration);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: buildSafeThumb(item.artUri?.toString(), width: 40, height: 40, radius: 4),
              title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                durText.isNotEmpty ? "${item.artist ?? ''} • $durText" : (item.artist ?? ''),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.playlist_play, color: Colors.white),
              title: const Text('Siguiente en cola', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                audioHandler.insertNextInQueue(item);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sonará a continuación: ${item.title}'), backgroundColor: color),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_to_queue, color: Colors.white),
              title: const Text('Última en cola', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                audioHandler.addToQueueEnd(item);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Añadida al final de la cola: ${item.title}'), backgroundColor: color),
                );
              },
            ),
            if (inQueue)
              ListTile(
                leading: const Icon(Icons.remove_from_queue, color: Colors.redAccent),
                title: const Text('Eliminar de la cola de reproducción', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  audioHandler.removeFromQueue(item);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Eliminada de la cola'), backgroundColor: Colors.redAccent),
                  );
                },
              ),
            ValueListenableBuilder(
              valueListenable: Hive.box('favorites').listenable(),
              builder: (context, Box box, _) {
                final isFav = box.containsKey(item.id);
                return ListTile(
                  leading: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : Colors.white),
                  title: Text(isFav ? 'Eliminar de Favoritos' : 'Añadir a favoritos', style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    if (isFav) {
                      box.delete(item.id);
                    } else {
                      box.put(item.id, {
                        'id': item.id,
                        'title': item.title,
                        'artist': item.artist ?? '',
                        'artUri': item.artUri?.toString() ?? '',
                        'duration': item.duration?.inMilliseconds ?? 0,
                      });
                    }
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isFav ? 'Eliminado de Favoritos' : 'Añadido a Favoritos'), backgroundColor: color),
                    );
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add, color: Colors.white),
              title: const Text('Añadir a lista de reproducción', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showPlaylistDialog(context, item, color);
              },
            ),
            ListTile(
              leading: const Icon(Icons.radio, color: Colors.white),
              title: const Text('Iniciar Radio de la canción', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                await globalPlay(item, audioHandler);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Iniciando Radio de ${item.title}'), backgroundColor: color),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

void _showPlaylistDialog(BuildContext context, MediaItem item, Color color) {
  final box = Hive.box('playlists');
  final songData = {
    'id': item.id,
    'title': item.title,
    'artist': item.artist ?? '',
    'artUri': item.artUri?.toString() ?? '',
    'duration': item.duration?.inMilliseconds ?? 0,
  };
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text("Mis Playlists", style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add, color: Colors.white),
              title: const Text("Crear Nueva Playlist", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showCreatePlaylistDialog(context, songData, color);
              },
            ),
            const Divider(color: Colors.white24),
            if (box.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text("No tienes playlists aún", style: TextStyle(color: Colors.grey)))
            else
              ...box.keys.map((key) => ListTile(
                    leading: const Icon(Icons.queue_music, color: Colors.grey),
                    title: Text(key.toString(), style: const TextStyle(color: Colors.white)),
                    onTap: () {
                      List currentList = box.get(key) ?? [];
                      if (!currentList.any((s) => s['id'] == songData['id'])) {
                        currentList.add(songData);
                        box.put(key, currentList);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Agregada a $key'), backgroundColor: color));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ya está en esta playlist'), backgroundColor: Colors.redAccent),
                        );
                      }
                      Navigator.pop(context);
                    },
                  )),
          ],
        ),
      ),
    ),
  );
}

void _showCreatePlaylistDialog(BuildContext context, Map songData, Color color) {
  final textController = TextEditingController();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text("Nueva Playlist", style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: textController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Nombre de la playlist",
          hintStyle: const TextStyle(color: Colors.grey),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: color)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: color)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
        TextButton(
          onPressed: () {
            if (textController.text.trim().isNotEmpty) {
              Hive.box('playlists').put(textController.text.trim(), [songData]);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Playlist creada'), backgroundColor: color));
            }
          },
          child: Text("Crear", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: appColor,
      builder: (context, color, _) {
        return MaterialApp(
          title: 'Spotify Killer VIP',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF0D0D0D),
            primaryColor: color,
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              backgroundColor: Colors.transparent,
              selectedItemColor: color,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
            ),
            appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0D0D0D), elevation: 0, centerTitle: true),
          ),
          home: const MainNavigationScreen(),
        );
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  String _activeSection = 'discover';

  Widget _buildBody(Color color) {
    if (_activeSection == 'vault') return const VaultScreen();
    if (_activeSection == 'history') return const HomeScreen();
    if (_activeSection == 'sports') return const SportsTab();
    if (_activeSection == 'settings') return const SettingsTab();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            color: const Color(0xFF0D0D0D),
            child: TabBar(
              indicatorColor: color,
              labelColor: color,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(icon: Icon(Icons.home_outlined)),
                Tab(icon: Icon(Icons.music_note)),
                Tab(icon: Icon(Icons.star_border)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                HomeFeedTab(
                  accentColor: color,
                  onPlay: (item) => globalPlay(item, audioHandler),
                  onOptions: (ctx, item) => globalShowOptions(ctx, item, color),
                ),
                TrendingTab(
                  accentColor: color,
                  onPlay: (item) => globalPlay(item, audioHandler),
                  onOptions: (ctx, item) => globalShowOptions(ctx, item, color),
                ),
                const VaultScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _sectionTitle() {
    switch (_activeSection) {
      case 'vault':
        return 'Biblioteca';
      case 'history':
        return 'Volver a escuchar';
      case 'sports':
        return 'Deportes';
      case 'settings':
        return 'Ajustes';
      default:
        return 'Inicio';
    }
  }

  void _selectSection(String section) {
    Navigator.pop(context);
    setState(() => _activeSection = section);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: appColor,
      builder: (context, color, _) {
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            title: Text(_sectionTitle(), style: const TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                },
              ),
            ],
          ),
          drawer: Drawer(
            backgroundColor: const Color(0xFF141414),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(color: Color(0xFF1A1A1A)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ConspiracyLogo(size: 52, color: color),
                      const SizedBox(height: 10),
                      const Text(
                        'Spotify Killer VIP',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Text('v1.1.0', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.explore, color: _activeSection == 'discover' ? color : Colors.white70),
                  title: Text('Descubrir', style: TextStyle(color: _activeSection == 'discover' ? color : Colors.white)),
                  selected: _activeSection == 'discover',
                  selectedTileColor: color.withOpacity(0.12),
                  onTap: () => _selectSection('discover'),
                ),
                ListTile(
                  leading: Icon(Icons.library_music, color: _activeSection == 'vault' ? color : Colors.white70),
                  title: Text('Biblioteca', style: TextStyle(color: _activeSection == 'vault' ? color : Colors.white)),
                  selected: _activeSection == 'vault',
                  selectedTileColor: color.withOpacity(0.12),
                  onTap: () => _selectSection('vault'),
                ),
                ListTile(
                  leading: Icon(Icons.history, color: _activeSection == 'history' ? color : Colors.white70),
                  title: Text('Volver a escuchar', style: TextStyle(color: _activeSection == 'history' ? color : Colors.white)),
                  selected: _activeSection == 'history',
                  selectedTileColor: color.withOpacity(0.12),
                  onTap: () => _selectSection('history'),
                ),
                const Divider(color: Colors.white12),
                ListTile(
                  leading: Icon(Icons.sports_soccer, color: _activeSection == 'sports' ? color : Colors.white70),
                  title: Text('Deportes', style: TextStyle(color: _activeSection == 'sports' ? color : Colors.white)),
                  selected: _activeSection == 'sports',
                  selectedTileColor: color.withOpacity(0.12),
                  onTap: () => _selectSection('sports'),
                ),
                ListTile(
                  leading: Icon(Icons.settings, color: _activeSection == 'settings' ? color : Colors.white70),
                  title: Text('Ajustes', style: TextStyle(color: _activeSection == 'settings' ? color : Colors.white)),
                  selected: _activeSection == 'settings',
                  selectedTileColor: color.withOpacity(0.12),
                  onTap: () => _selectSection('settings'),
                ),
              ],
            ),
          ),
          body: Stack(
            children: [
              _buildBody(color),
              const Positioned(left: 0, right: 0, bottom: 8, child: MiniPlayer()),
            ],
          ),
        );
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  Widget _buildHorizontalList(List items) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () async {
              final newItem = MediaItem(
                id: item['id'],
                title: item['title'],
                artist: item['artist'],
                artUri: Uri.parse(item['artUri']),
                duration: Duration(milliseconds: item['duration']),
              );
              await globalPlay(newItem, audioHandler);
            },
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildSafeThumb(item['artUri']?.toString(), width: 140, height: 140, radius: 8),
                  const SizedBox(height: 8),
                  Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(item['artist'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.all(16.0), child: Text("Para ti", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
              ValueListenableBuilder(
                valueListenable: Hive.box('history').listenable(),
                builder: (context, Box box, _) {
                  if (box.isEmpty) return const SizedBox.shrink();
                  final items = box.values.toList().cast()
                    ..sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Text("Escuchado recientemente", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      _buildHorizontalList(items.take(10).toList()),
                    ],
                  );
                },
              ),
              const SizedBox(height: 100),
            ],
          ),
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
      appBar: AppBar(title: const Text('⚽ Deportes & Ligas', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent),
      body: const Center(child: Text('Filtros de ligas, equipos y partidos en vivo en la próxima fase.', style: TextStyle(color: Colors.grey))),
    );
  }
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🎨 Ajustes', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            leading: const Icon(Icons.share, color: Colors.white),
            title: const Text('Compartir App', style: TextStyle(color: Colors.white)),
            onTap: () => Share.share('¡Prueba mi app multimedia VIP!'),
          ),
        ],
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final searchController = TextEditingController();
  late final YoutubeExplode _yt;
  List<MediaItem> videos = [];
  List<String> searchSuggestions = [];
  bool isLoading = false;
  bool hasSearched = false;
  bool hasSearchError = false;
  Timer? _debounce;
  int _suggestRequestId = 0;
  String _lastQuery = "";

  final Map<String, String> _categories = {
    "Tendencias": "Tendencias musica en español",
    "Podcasts": "Podcasts en español",
    "Electrónica": "Electronic music mix",
    "Rock": "Rock clasico en español",
    "Relajación": "Musica relajante lofi",
  };

  @override
  void initState() {
    super.initState();
    _yt = YoutubeExplode();
    Permission.notification.request();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _yt.close();
    searchController.dispose();
    super.dispose();
  }

  void _saveSearchHistory(String query) {
    if (query.trim().isEmpty) return;
    final box = Hive.box('search_history');
    List history = box.get('history') ?? [];
    history.remove(query);
    history.insert(0, query);
    if (history.length > 10) history = history.sublist(0, 10);
    box.put('history', history);
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    final reqId = ++_suggestRequestId;
    if (query.trim().isEmpty) {
      setState(() {
        searchSuggestions = [];
        videos = [];
        hasSearched = false;
        hasSearchError = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final suggestions = await _yt.search.getQuerySuggestions(query);
        if (!mounted || reqId != _suggestRequestId) return;
        setState(() {
          searchSuggestions = suggestions.take(6).toList();
        });
      } catch (_) {}
    });
  }

  String _extractText(dynamic obj) {
    if (obj is Map) {
      if (obj['simpleText'] is String) return obj['simpleText'] as String;
      if (obj['runs'] is List) {
        return (obj['runs'] as List).whereType().map((r) => r['text']?.toString() ?? '').join();
      }
    }
    return '';
  }

  Duration? _parseDuration(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final parts = text.trim().split(':').map((p) => int.tryParse(p.trim())).toList();
    if (parts.any((p) => p == null)) return null;
    if (parts.length == 3) {
      return Duration(hours: parts[0]!, minutes: parts[1]!, seconds: parts[2]!);
    } else if (parts.length == 2) {
      return Duration(minutes: parts[0]!, seconds: parts[1]!);
    } else if (parts.length == 1) {
      return Duration(seconds: parts[0]!);
    }
    return null;
  }

  void _collectVideos(dynamic node, List<MediaItem> out, Set<String> seen) {
    if (node is Map) {
      final vr = node['videoRenderer'];
      if (vr is Map) {
        final videoId = vr['videoId']?.toString() ?? '';
        if (videoId.isNotEmpty && seen.add(videoId)) {
          final title = _extractText(vr['title']).trim();
          String author = _extractText(vr['ownerText']).trim();
          if (author.isEmpty) author = _extractText(vr['longBylineText']).trim();
          if (author.isEmpty) author = _extractText(vr['shortBylineText']).trim();
          if (author.isEmpty) author = 'YouTube';
          final duration = _parseDuration(_extractText(vr['lengthText']));
          if (title.isNotEmpty) {
            out.add(MediaItem(
              id: videoId,
              title: title,
              artist: author,
              duration: duration,
              artUri: Uri.parse('https://i.ytimg.com/vi/$videoId/hqdefault.jpg'),
            ));
          }
        }
      }
      for (final value in node.values) {
        _collectVideos(value, out, seen);
      }
    } else if (node is List) {
      for (final item in node) {
        _collectVideos(item, out, seen);
      }
    }
  }

  Future<List<MediaItem>> _searchYoutubeDirect(String query) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.postUrl(
        Uri.parse('https://www.youtube.com/youtubei/v1/search?prettyPrint=false'),
      );
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
      req.headers.set('Accept-Language', 'es-MX,es;q=0.9');
      final payload = jsonEncode({
        'context': {
          'client': {
            'clientName': 'WEB',
            'clientVersion': '2.20241120.00.00',
            'hl': 'es',
            'gl': 'MX',
          },
        },
        'query': query,
      });
      req.add(utf8.encode(payload));
      final res = await req.close().timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 12));
      final data = jsonDecode(body);
      final items = <MediaItem>[];
      final seen = <String>{};
      _collectVideos(data, items, seen);
      return items;
    } finally {
      client.close(force: true);
    }
  }

  void searchVideos(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _debounce?.cancel();
    _suggestRequestId++;
    FocusScope.of(context).unfocus();
    _saveSearchHistory(trimmed);
    setState(() {
      isLoading = true;
      hasSearched = true;
      hasSearchError = false;
      videos = [];
      searchSuggestions = [];
      _lastQuery = trimmed;
    });
    try {
      List<MediaItem> results = [];
      try {
        results = await _searchYoutubeDirect(trimmed);
      } catch (_) {}

      if (results.isEmpty) {
        final fallback = await _yt.search.search(trimmed).timeout(const Duration(seconds: 12));
        results = fallback
            .map((v) => MediaItem(
                  id: v.id.value,
                  title: v.title,
                  artist: v.author,
                  duration: v.duration,
                  artUri: Uri.parse(v.thumbnails.highResUrl),
                ))
            .toList();
      }

      if (!mounted) return;
      setState(() {
        videos = results;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        hasSearchError = true;
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _buildSearchHistory() {
    return Column(
      children: [
        ValueListenableBuilder(
          valueListenable: Hive.box('search_history').listenable(),
          builder: (context, Box box, _) {
            if (box.isEmpty) return const SizedBox.shrink();
            final history = box.get('history') ?? [];
            return Column(
              children: history.map<Widget>((query) {
                return ListTile(
                  leading: const Icon(Icons.history, color: Colors.grey),
                  title: Text(query, style: const TextStyle(color: Colors.white)),
                  trailing: IconButton(
                    icon: const Icon(Icons.north_west, color: Colors.grey, size: 18),
                    onPressed: () {
                      searchController.text = query;
                      _onSearchChanged(query);
                    },
                  ),
                  onTap: () {
                    searchController.text = query;
                    searchVideos(query);
                  },
                );
              }).toList(),
            );
          },
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text("Explorar Categorías", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _categories.entries
              .map((e) => ActionChip(
                    label: Text(e.key),
                    backgroundColor: const Color(0xFF1A1A1A),
                    onPressed: () {
                      searchController.text = e.key;
                      searchVideos(e.value);
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscador VIP', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar canciones, artistas, podcasts...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _debounce?.cancel();
                    _suggestRequestId++;
                    searchController.clear();
                    setState(() {
                      videos.clear();
                      searchSuggestions.clear();
                      _lastQuery = "";
                      hasSearched = false;
                      hasSearchError = false;
                    });
                  },
                ),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0), borderSide: BorderSide.none),
              ),
              onSubmitted: searchVideos,
            ),
          ),
          if (searchSuggestions.isNotEmpty)
            Container(
              color: const Color(0xFF141414),
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: searchSuggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = searchSuggestions[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.search, color: Colors.cyanAccent, size: 18),
                    title: Text(suggestion, style: const TextStyle(color: Colors.white)),
                    trailing: IconButton(
                      icon: const Icon(Icons.north_west, color: Colors.grey, size: 18),
                      onPressed: () {
                        searchController.text = suggestion;
                        searchController.selection = TextSelection.fromPosition(TextPosition(offset: suggestion.length));
                        _onSearchChanged(suggestion);
                      },
                    ),
                    onTap: () {
                      searchController.text = suggestion;
                      searchVideos(suggestion);
                    },
                  );
                },
              ),
            ),
          if (_lastQuery.isNotEmpty && videos.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  ActionChip(
                    label: const Text("🔥 Lo más sonado"),
                    backgroundColor: const Color(0xFF1A1A1A),
                    onPressed: () => searchVideos("$_lastQuery exitos mas escuchados"),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text("🆕 Lo más nuevo"),
                    backgroundColor: const Color(0xFF1A1A1A),
                    onPressed: () => searchVideos("$_lastQuery nuevo 2026"),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text("📻 Radio / Mix"),
                    backgroundColor: const Color(0xFF1A1A1A),
                    onPressed: () => searchVideos("$_lastQuery mix oficial"),
                  ),
                ],
              ),
            ),
          if (isLoading)
            Expanded(
              child: Center(
                child: ValueListenableBuilder<Color>(
                  valueListenable: appColor,
                  builder: (context, color, _) => CircularProgressIndicator(color: color),
                ),
              ),
            )
          else if (hasSearchError)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.grey, size: 42),
                      const SizedBox(height: 12),
                      Text(
                        "No se pudieron cargar los resultados para '$_lastQuery'.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ValueListenableBuilder<Color>(
                        valueListenable: appColor,
                        builder: (context, color, _) => ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.black),
                          icon: const Icon(Icons.refresh),
                          label: const Text("Reintentar"),
                          onPressed: () => searchVideos(_lastQuery),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (videos.isEmpty && hasSearched)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    "Sin resultados en YouTube para '$_lastQuery'",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
          else if (videos.isEmpty)
            Expanded(child: SingleChildScrollView(child: _buildSearchHistory()))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  final item = videos[index];
                  final durText = formatGlobalDuration(item.duration);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: buildSafeThumb(item.artUri?.toString(), width: 60, height: 60, radius: 8),
                    title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      durText.isNotEmpty ? "${item.artist ?? ''} • $durText" : (item.artist ?? ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onPressed: () => globalShowOptions(context, item, appColor.value),
                    ),
                    onTap: () async {
                      await globalPlay(item, audioHandler);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('La Bóveda', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(indicatorColor: Colors.white, tabs: [Tab(text: 'Historial'), Tab(text: 'Favoritos'), Tab(text: 'Playlists')]),
        ),
        body: TabBarView(
          children: [
            ValueListenableBuilder(
              valueListenable: Hive.box('history').listenable(),
              builder: (context, Box box, _) {
                if (box.isEmpty) return const Center(child: Text("Sin historial aún", style: TextStyle(color: Colors.grey)));
                final items = box.values.toList().cast()
                  ..sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0));
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      leading: buildSafeThumb(item['artUri']?.toString(), width: 50, height: 50, radius: 4),
                      title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 20), onPressed: () => box.delete(item['id'])),
                      onTap: () async {
                        final newItem = MediaItem(
                          id: item['id'],
                          title: item['title'],
                          artist: item['artist'],
                          artUri: Uri.parse(item['artUri']),
                          duration: Duration(milliseconds: item['duration']),
                        );
                        await globalPlay(newItem, audioHandler);
                      },
                    );
                  },
                );
              },
            ),
            ValueListenableBuilder(
              valueListenable: Hive.box('favorites').listenable(),
              builder: (context, Box box, _) {
                if (box.isEmpty) return const Center(child: Text("Sin favoritos aún", style: TextStyle(color: Colors.grey)));
                final items = box.values.toList().cast();
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      leading: buildSafeThumb(item['artUri']?.toString(), width: 50, height: 50, radius: 4),
                      title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: IconButton(icon: const Icon(Icons.favorite, color: Colors.redAccent), onPressed: () => box.delete(item['id'])),
                      onTap: () async {
                        List<MediaItem> allFavs = items
                            .map((e) => MediaItem(
                                  id: e['id'],
                                  title: e['title'],
                                  artist: e['artist'],
                                  artUri: Uri.parse(e['artUri']),
                                  duration: Duration(milliseconds: e['duration']),
                                ))
                            .toList();
                        await globalPlayQueue(allFavs, index, audioHandler);
                      },
                    );
                  },
                );
              },
            ),
            ValueListenableBuilder(
              valueListenable: Hive.box('playlists').listenable(),
              builder: (context, Box box, _) {
                if (box.isEmpty) {
                  return const Center(child: Text("Toca los 3 puntitos en una canción para crear listas", style: TextStyle(color: Colors.grey)));
                }
                final keys = box.keys.toList();
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: keys.length,
                  itemBuilder: (context, index) {
                    final playlistName = keys[index].toString();
                    final tracks = box.get(playlistName) ?? [];
                    return ExpansionTile(
                      leading: ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => Icon(Icons.queue_music, color: color)),
                      title: Text(playlistName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      subtitle: Text("${tracks.length} pistas", style: const TextStyle(color: Colors.grey)),
                      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => box.delete(playlistName)),
                      children: tracks.asMap().entries.map<Widget>((entry) {
                        int trackIndex = entry.key;
                        final item = entry.value as Map;
                        return ListTile(
                          contentPadding: const EdgeInsets.only(left: 40, right: 16),
                          leading: buildSafeThumb(item['artUri']?.toString(), width: 40, height: 40, radius: 4),
                          title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.grey, size: 20),
                            onPressed: () {
                              tracks.removeAt(trackIndex);
                              box.put(playlistName, tracks);
                            },
                          ),
                          onTap: () async {
                            List<MediaItem> allTracks = tracks
                                .map<MediaItem>((e) => MediaItem(
                                      id: e['id'],
                                      title: e['title'],
                                      artist: e['artist'],
                                      artUri: Uri.parse(e['artUri']),
                                      duration: Duration(milliseconds: e['duration']),
                                    ))
                                .toList();
                            await globalPlayQueue(allTracks, trackIndex, audioHandler);
                          },
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});
  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const FullScreenPlayer(),
          ),
          child: ValueListenableBuilder<Color>(
            valueListenable: appColor,
            builder: (context, color, _) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color, width: 0.5),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, spreadRadius: 2)],
                  color: Colors.black.withOpacity(0.9),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          buildSafeThumb(mediaItem.artUri?.toString(), width: 45, height: 45, radius: 10),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(mediaItem.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(mediaItem.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          StreamBuilder<PlaybackState>(
                            stream: audioHandler.playbackState,
                            builder: (context, snapshot) {
                              final state = snapshot.data;
                              final playing = state?.playing ?? false;
                              final isLoading = state?.processingState == AudioProcessingState.loading ||
                                  state?.processingState == AudioProcessingState.buffering;
                              return IconButton(
                                icon: isLoading
                                    ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: color, strokeWidth: 2))
                                    : Icon(playing ? Icons.pause : Icons.play_arrow, color: color),
                                onPressed: () {
                                  if (playing) {
                                    audioHandler.pause();
                                  } else {
                                    audioHandler.play();
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class FullScreenPlayer extends StatelessWidget {
  const FullScreenPlayer({super.key});

  Future<String> _fetchLyrics(MediaItem item) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final cleanTitle = item.title
          .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
          .replaceAll(RegExp(r'(?i)official|video|audio|lyrics|letra|hd|4k|mv'), '')
          .trim();
      final query = '${item.artist ?? ''} $cleanTitle'.trim();
      final uri = Uri.parse('https://lrclib.net/api/search?q=${Uri.encodeQueryComponent(query)}');
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return 'No se encontró la letra para esta pista.';
      final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(body);
      if (decoded is List && decoded.isNotEmpty) {
        for (final entry in decoded) {
          if (entry is Map) {
            final plain = entry['plainLyrics']?.toString().trim() ?? '';
            if (plain.isNotEmpty) return plain;
          }
        }
      }
      return 'No se encontró la letra para esta pista.';
    } catch (_) {
      return 'Error de conexión al buscar la letra.';
    } finally {
      client.close(force: true);
    }
  }

  Future _fetchDetailsAndComments(String videoId) async {
    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(videoId).timeout(const Duration(seconds: 10));
      final commentsList = <dynamic>[];
      try {
        final comments = await yt.videos.comments.getComments(video).timeout(const Duration(seconds: 8));
        if (comments != null) {
          for (final c in comments.take(15)) {
            commentsList.add({
              'author': c.author,
              'text': c.text,
              'likes': c.likeCount,
            });
          }
        }
      } catch (_) {}
      return {
        'description': video.description.trim().isEmpty ? 'Sin descripción.' : video.description.trim(),
        'views': video.engagement.viewCount,
        'likes': video.engagement.likeCount,
        'comments': commentsList,
      };
    } catch (_) {
      return {'error': 'No se pudieron cargar los detalles del video.'};
    } finally {
      yt.close();
    }
  }

  void _showLyricsDialog(BuildContext context, MediaItem item, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Letra: ${item.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              Expanded(
                child: FutureBuilder<String>(
                  future: _fetchLyrics(item),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: color));
                    }
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: SelectableText(
                        snapshot.data ?? 'Sin resultados.',
                        style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.6),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDetailsAndCommentsDialog(BuildContext context, MediaItem item, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Detalles y comentarios', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              ),
              const Divider(color: Colors.white24, height: 1),
              Expanded(
                child: FutureBuilder(
                  future: _fetchDetailsAndComments(item.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: color));
                    }
                    final data = snapshot.data ?? {};
                    if (data['error'] != null) {
                      return Center(child: Text(data['error'].toString(), style: const TextStyle(color: Colors.grey)));
                    }
                    final comments = (data['comments'] as List?) ?? [];
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                          '${item.artist ?? ''} • ${data['views'] ?? 0} vistas • ${data['likes'] ?? 0} me gusta',
                          style: TextStyle(color: color, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        const Text('Descripción', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(data['description']?.toString() ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        const Divider(color: Colors.white24, height: 28),
                        Text('Comentarios (${comments.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        if (comments.isEmpty)
                          const Text('Sin comentarios disponibles.', style: TextStyle(color: Colors.grey))
                        else
                          ...comments.map((c) {
                            final author = c['author']?.toString() ?? 'Usuario';
                            final text = c['text']?.toString() ?? '';
                            final likes = c['likes'] ?? 0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$author • 👍 $likes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            );
                          }),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSaveQueueDialog(BuildContext context, List<MediaItem> queueList, Color color) {
    if (queueList.isEmpty) return;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Guardar cola como playlist", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Nombre de la playlist",
            hintStyle: const TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: color)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: color)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final tracks = queueList
                    .map((e) => {
                          'id': e.id,
                          'title': e.title,
                          'artist': e.artist ?? '',
                          'artUri': e.artUri?.toString() ?? '',
                          'duration': e.duration?.inMilliseconds ?? 0,
                        })
                    .toList();
                Hive.box('playlists').put(name, tracks);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Cola guardada en "$name"'), backgroundColor: color),
                );
              }
            },
            child: Text("Guardar", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSpeedPitchDialog(BuildContext context, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Velocidad y tono", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {
                      audioHandler.setSpeed(1.0);
                      audioHandler.setPitch(1.0);
                    },
                    child: Text("Restablecer", style: TextStyle(color: color)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<double>(
                valueListenable: audioHandler.playbackSpeed,
                builder: (context, speed, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Velocidad: ${speed.toStringAsFixed(2)}x", style: const TextStyle(color: Colors.white70)),
                      Slider(
                        value: speed,
                        min: 0.5,
                        max: 2.0,
                        divisions: 30,
                        activeColor: color,
                        onChanged: (v) => audioHandler.setSpeed(v),
                      ),
                    ],
                  );
                },
              ),
              ValueListenableBuilder<double>(
                valueListenable: audioHandler.playbackPitch,
                builder: (context, pitch, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Tono: ${pitch.toStringAsFixed(2)}x", style: const TextStyle(color: Colors.white70)),
                      Slider(
                        value: pitch,
                        min: 0.5,
                        max: 2.0,
                        divisions: 30,
                        activeColor: color,
                        onChanged: (v) => audioHandler.setPitch(v),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEqualizerDialog(BuildContext context, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<AndroidEqualizerParameters>(
            future: audioHandler.equalizer.parameters,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 140,
                  child: Center(child: Text("Reproduce una pista para activar el ecualizador.", style: TextStyle(color: Colors.grey))),
                );
              }
              final params = snapshot.data!;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Ecualizador", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      StreamBuilder<bool>(
                        stream: audioHandler.equalizer.enabledStream,
                        builder: (context, enabledSnap) {
                          final enabled = enabledSnap.data ?? false;
                          return Switch(
                            value: enabled,
                            activeColor: color,
                            onChanged: (v) => audioHandler.equalizer.setEnabled(v),
                          );
                        },
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  ...params.bands.map((band) {
                    return StreamBuilder<double>(
                      stream: band.gainStream,
                      builder: (context, gainSnap) {
                        final gain = (gainSnap.data ?? band.gain).clamp(params.minDecibels, params.maxDecibels);
                        final freq = band.centerFrequency >= 1000
                            ? "${(band.centerFrequency / 1000).toStringAsFixed(1)} kHz"
                            : "${band.centerFrequency.round()} Hz";
                        return Row(
                          children: [
                            SizedBox(width: 68, child: Text(freq, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                            Expanded(
                              child: Slider(
                                value: gain,
                                min: params.minDecibels,
                                max: params.maxDecibels,
                                activeColor: color,
                                onChanged: (v) => band.setGain(v),
                              ),
                            ),
                            SizedBox(
                              width: 44,
                              child: Text("${gain.toStringAsFixed(1)} dB", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            ),
                          ],
                        );
                      },
                    );
                  }),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: const BoxDecoration(color: Color(0xFF0D0D0D), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, snapshot) {
          final mediaItem = snapshot.data;
          if (mediaItem == null) return const SizedBox.shrink();
          return ValueListenableBuilder<Color>(
            valueListenable: appColor,
            builder: (context, color, _) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        ValueListenableBuilder<bool>(
                          valueListenable: audioHandler.sponsorBlockEnabled,
                          builder: (context, enabled, _) => IconButton(
                            tooltip: 'SponsorBlock',
                            icon: Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: enabled ? color : Colors.grey, width: 1.8),
                              ),
                              child: Text(
                                'S',
                                style: TextStyle(
                                  color: enabled ? color : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            onPressed: () {
                              audioHandler.toggleSponsorBlock();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(audioHandler.sponsorBlockEnabled.value ? 'SponsorBlock activado' : 'SponsorBlock desactivado'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: audioHandler.sleepTimerRemaining,
                          builder: (context, remaining, _) => IconButton(
                            icon: Icon(Icons.timer, color: remaining > 0 ? color : Colors.white70),
                            onPressed: () => _showSleepTimerDialog(context),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          color: const Color(0xFF1F1F1F),
                          onSelected: (value) {
                            switch (value) {
                              case 'details':
                                _showDetailsAndCommentsDialog(context, mediaItem, color);
                                break;
                              case 'playlist':
                                _showPlaylistDialog(context, mediaItem, color);
                                break;
                              case 'share':
                                Share.share('${mediaItem.title}\nhttps://youtu.be/${mediaItem.id}');
                                break;
                              case 'save_queue':
                                _showSaveQueueDialog(context, audioHandler.queue.value, color);
                                break;
                              case 'lyrics':
                                _showLyricsDialog(context, mediaItem, color);
                                break;
                              case 'speed':
                                _showSpeedPitchDialog(context, color);
                                break;
                              case 'eq':
                                _showEqualizerDialog(context, color);
                                break;
                              case 'reload':
                                audioHandler.reloadCurrentTrack();
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'details', child: ListTile(dense: true, leading: Icon(Icons.info_outline, color: Colors.white), title: Text('Detalles y comentarios', style: TextStyle(color: Colors.white)))),
                            const PopupMenuItem(value: 'playlist', child: ListTile(dense: true, leading: Icon(Icons.playlist_add, color: Colors.white), title: Text('Añadir a una lista', style: TextStyle(color: Colors.white)))),
                            const PopupMenuItem(value: 'share', child: ListTile(dense: true, leading: Icon(Icons.share, color: Colors.white), title: Text('Compartir', style: TextStyle(color: Colors.white)))),
                            const PopupMenuItem(value: 'save_queue', child: ListTile(dense: true, leading: Icon(Icons.save_alt, color: Colors.white), title: Text('Guardar cola como playlist', style: TextStyle(color: Colors.white)))),
                            const PopupMenuItem(value: 'lyrics', child: ListTile(dense: true, leading: Icon(Icons.lyrics, color: Colors.white), title: Text('Buscar letra', style: TextStyle(color: Colors.white)))),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'speed',
                              child: ListTile(
                                dense: true,
                                leading: const Icon(Icons.speed, color: Colors.white),
                                title: const Text('Velocidad y tono', style: TextStyle(color: Colors.white)),
                                trailing: Text('${audioHandler.playbackSpeed.value.toStringAsFixed(1)}x', style: const TextStyle(color: Colors.grey)),
                              ),
                            ),
                            const PopupMenuItem(value: 'eq', child: ListTile(dense: true, leading: Icon(Icons.equalizer, color: Colors.white), title: Text('Ecualizador', style: TextStyle(color: Colors.white)))),
                            const PopupMenuDivider(),
                            const PopupMenuItem(value: 'reload', child: ListTile(dense: true, leading: Icon(Icons.refresh, color: Colors.white), title: Text('Reload player', style: TextStyle(color: Colors.white)))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        buildSafeThumb(mediaItem.artUri?.toString(), width: 100, height: 100, radius: 14),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(mediaItem.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(height: 6),
                              Text(mediaItem.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                            ],
                          ),
                        ),
                        ValueListenableBuilder(
                          valueListenable: Hive.box('favorites').listenable(),
                          builder: (context, Box box, _) {
                            final isFav = box.containsKey(mediaItem.id);
                            return IconButton(
                              icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : Colors.white),
                              onPressed: () {
                                if (isFav) {
                                  box.delete(mediaItem.id);
                                } else {
                                  box.put(mediaItem.id, {
                                    'id': mediaItem.id,
                                    'title': mediaItem.title,
                                    'artist': mediaItem.artist,
                                    'artUri': mediaItem.artUri.toString(),
                                    'duration': mediaItem.duration?.inMilliseconds ?? 0,
                                  });
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  StreamBuilder<Duration>(
                    stream: AudioService.position,
                    builder: (context, snapshotPosition) {
                      final pos = snapshotPosition.data ?? Duration.zero;
                      return StreamBuilder<PlaybackState>(
                        stream: audioHandler.playbackState,
                        builder: (context, snapshot) {
                          final state = snapshot.data;
                          final isLoading = state?.processingState == AudioProcessingState.loading ||
                              state?.processingState == AudioProcessingState.buffering;
                          final dur = mediaItem.duration ?? Duration.zero;
                          final buffered = state?.bufferedPosition ?? Duration.zero;
                          final maxDur = dur.inMilliseconds.toDouble() > 0 ? dur.inMilliseconds.toDouble() : 1.0;
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 4,
                                    activeTrackColor: color,
                                    secondaryActiveTrackColor: Colors.white54,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: color,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                  ),
                                  child: Slider(
                                    value: isLoading ? 0.0 : pos.inMilliseconds.toDouble().clamp(0.0, maxDur),
                                    secondaryTrackValue: isLoading ? 0.0 : buffered.inMilliseconds.toDouble().clamp(0.0, maxDur),
                                    max: maxDur,
                                    onChanged: (v) {
                                      if (!isLoading) audioHandler.seek(Duration(milliseconds: v.round()));
                                    },
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(formatGlobalDuration(pos), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    Text(formatGlobalDuration(mediaItem.duration), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: StreamBuilder<PlaybackState>(
                      stream: audioHandler.playbackState,
                      builder: (context, snapshot) {
                        final state = snapshot.data;
                        final playing = state?.playing ?? false;
                        final isLoading = state?.processingState == AudioProcessingState.loading ||
                            state?.processingState == AudioProcessingState.buffering;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.fast_rewind, color: Colors.white, size: 28),
                              onPressed: () => audioHandler.seekRelative(const Duration(seconds: -10)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_previous, color: Colors.white, size: 32),
                              onPressed: () => audioHandler.skipToPrevious(),
                            ),
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                                boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 16, spreadRadius: 2)],
                              ),
                              child: IconButton(
                                icon: isLoading
                                    ? const CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5)
                                    : Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 34),
                                onPressed: () {
                                  if (playing) {
                                    audioHandler.pause();
                                  } else {
                                    audioHandler.play();
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_next, color: Colors.white, size: 32),
                              onPressed: () => audioHandler.skipToNext(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.fast_forward, color: Colors.white, size: 28),
                              onPressed: () => audioHandler.seekRelative(const Duration(seconds: 10)),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: Colors.white12, height: 1),
                  Expanded(
                    child: StreamBuilder<List<MediaItem>>(
                      stream: audioHandler.queue,
                      builder: (context, queueSnapshot) {
                        final queueList = queueSnapshot.data ?? [];
                        final currentIndex = queueList.indexWhere((i) => i.id == mediaItem.id);
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              child: Row(
                                children: [
                                  Text(
                                    'A continuación  ${currentIndex >= 0 ? currentIndex + 1 : 0} / ${queueList.length}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const Spacer(),
                                  ValueListenableBuilder<LoopMode>(
                                    valueListenable: audioHandler.loopMode,
                                    builder: (context, mode, _) {
                                      final icon = mode == LoopMode.one ? Icons.repeat_one : Icons.repeat;
                                      return IconButton(
                                        icon: Icon(icon, color: mode == LoopMode.off ? Colors.grey : color, size: 22),
                                        onPressed: () => audioHandler.cycleLoopMode(),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.shuffle, color: Colors.white70, size: 22),
                                    onPressed: () {
                                      audioHandler.shuffleQueue();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Cola mezclada'), duration: Duration(seconds: 1)),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: queueList.isEmpty
                                  ? const Center(child: Text("Cola vacía", style: TextStyle(color: Colors.grey)))
                                  : ReorderableListView.builder(
                                      padding: const EdgeInsets.only(bottom: 24),
                                      itemCount: queueList.length,
                                      onReorder: (oldIndex, newIndex) => audioHandler.reorderQueue(oldIndex, newIndex),
                                      itemBuilder: (context, index) {
                                        final item = queueList[index];
                                        final isPlaying = index == currentIndex;
                                        return Container(
                                          key: ValueKey('${item.id}_$index'),
                                          color: isPlaying ? color.withOpacity(0.12) : Colors.transparent,
                                          child: ListTile(
                                            dense: true,
                                            leading: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                                                const SizedBox(width: 8),
                                                buildSafeThumb(item.artUri?.toString(), width: 42, height: 42, radius: 6),
                                              ],
                                            ),
                                            title: Text(
                                              item.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(color: isPlaying ? color : Colors.white, fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal),
                                            ),
                                            subtitle: Text(
                                              "${formatGlobalDuration(item.duration).isNotEmpty ? '${formatGlobalDuration(item.duration)} • ' : ''}${item.artist ?? ''}",
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                                            ),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                                              onPressed: () => audioHandler.removeFromQueue(item),
                                            ),
                                            onTap: () => audioHandler.skipToQueueItem(index),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showSleepTimerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (context) {
        return Wrap(
          children: [
            const ListTile(title: Text("Temporizador", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
            _timerOption(context, "Desactivar", 0),
            _timerOption(context, "15 minutos", 15),
            _timerOption(context, "30 minutos", 30),
            _timerOption(context, "60 minutos", 60),
          ],
        );
      },
    );
  }

  Widget _timerOption(BuildContext context, String label, int minutes) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white70)),
      onTap: () {
        audioHandler.customAction('setSleepTimer', {'minutes': minutes});
        Navigator.pop(context);
      },
    );
  }
}
