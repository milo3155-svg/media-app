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
import 'dart:math' as math;
import 'dart:async'; 

// 1. IMPORTAMOS NUESTRO MOTOR AISLADO Y BLINDADO
import 'services/audio_handler.dart';

late MyAudioHandler audioHandler;
final ValueNotifier<bool> isHDMode = ValueNotifier<bool>(true);
final ValueNotifier<Color> appColor = ValueNotifier<Color>(Colors.cyanAccent); 

String formatGlobalDuration(Duration? d) {
  if (d == null || d == Duration.zero) return "";
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return "${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds";
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      androidNotificationIcon: 'drawable/ic_notification' 
    )
  ) as MyAudioHandler; // Casteo estricto a nuestro motor personalizado
  
  runApp(const MediaApp());
}

class ConspiracyLogo extends StatelessWidget {
  final double size; final Color color; const ConspiracyLogo({super.key, this.size = 150.0, required this.color});
  @override Widget build(BuildContext context) { return SizedBox(width: size, height: size, child: CustomPaint(painter: _OsirisEyePainter(color: color))); }
}

class _OsirisEyePainter extends CustomPainter {
  final Color color; _OsirisEyePainter({required this.color});
  void _drawTextOnLine(Canvas canvas, String text, Offset start, Offset end, double fontSize) {
    final midPoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2); final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    canvas.save(); canvas.translate(midPoint.dx, midPoint.dy); canvas.rotate(angle);
    final textSpan = TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'Courier'));
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr); textPainter.layout(); textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height - 2)); canvas.restore();
  }
  @override void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = w * 0.05..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round;
    final p1 = Offset(w * 0.15, h * 0.15); final p2 = Offset(w * 0.15, h * 0.85); final p3 = Offset(w * 0.90, h * 0.50); 
    final playPath = Path()..moveTo(p1.dx, p1.dy)..lineTo(p2.dx, p2.dy)..lineTo(p3.dx, p3.dy)..close(); canvas.drawPath(playPath, paint);
    final fontSize = w * 0.08; _drawTextOnLine(canvas, "Θ ⅃ Θ", p1, p2, fontSize); _drawTextOnLine(canvas, "Δ Ξ", p2, p3, fontSize); _drawTextOnLine(canvas, "Θ Ϟ Ι ℟ Ι Ϟ", p3, p1, fontSize);
    final eyeLeft = w * 0.28; final eyeRight = w * 0.62; final eyeY = h * 0.50; final eyeCenterX = w * 0.45;
    final eyePath = Path()..moveTo(eyeLeft, eyeY)..quadraticBezierTo(eyeCenterX, h * 0.32, eyeRight, eyeY)..quadraticBezierTo(eyeCenterX, h * 0.68, eyeLeft, eyeY); canvas.drawPath(eyePath, paint);
    final wavePaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = w * 0.03; canvas.drawCircle(Offset(eyeCenterX, h * 0.50), w * 0.08, wavePaint); canvas.drawCircle(Offset(eyeCenterX, h * 0.50), w * 0.03, wavePaint); canvas.drawLine(Offset(eyeCenterX - w * 0.12, h * 0.50), Offset(eyeCenterX + w * 0.12, h * 0.50), wavePaint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

void globalShowOptions(BuildContext context, Video video, Color color) {
  final newItem = MediaItem(
    id: video.id.value,
    title: video.title,
    artist: video.author,
    duration: video.duration,
    artUri: Uri.parse(video.thumbnails.highResUrl),
  );

  showModalBottomSheet(
    context: context, backgroundColor: const Color(0xFF1A1A1A), isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), 
    builder: (context) { 
      final inQueue = audioHandler.queue.value.any((i) => i.id == video.id.value);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10), 
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            ListTile(
              leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(video.thumbnails.lowResUrl, width: 40, height: 40, fit: BoxFit.cover)), 
              title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)), 
              subtitle: Text("${video.author} • ${formatGlobalDuration(video.duration)}", style: const TextStyle(color: Colors.grey))
            ), 
            const Divider(color: Colors.white24), 
            ListTile(
              leading: const Icon(Icons.playlist_play, color: Colors.white), 
              title: const Text('Siguiente en cola', style: TextStyle(color: Colors.white)), 
              onTap: () { 
                Navigator.pop(context); 
                audioHandler.insertNextInQueue(newItem); 
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sonará a continuación: ${video.title}'), backgroundColor: color)); 
              }
            ),
            ListTile(
              leading: const Icon(Icons.add_to_queue, color: Colors.white), 
              title: const Text('Última en cola', style: TextStyle(color: Colors.white)), 
              onTap: () { 
                Navigator.pop(context); 
                audioHandler.addToQueueEnd(newItem); 
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Añadida al final de la cola: ${video.title}'), backgroundColor: color)); 
              }
            ),
            if (inQueue)
              ListTile(
                leading: const Icon(Icons.remove_from_queue, color: Colors.redAccent), 
                title: const Text('Eliminar de la cola de reproducción', style: TextStyle(color: Colors.redAccent)), 
                onTap: () { 
                  Navigator.pop(context); 
                  audioHandler.removeFromQueue(newItem); 
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eliminada de la cola'), backgroundColor: Colors.redAccent)); 
                }
              ),
            ValueListenableBuilder(
              valueListenable: Hive.box('favorites').listenable(),
              builder: (context, Box box, _) {
                final isFav = box.containsKey(video.id.value);
                return ListTile(
                  leading: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : Colors.white), 
                  title: Text(isFav ? 'Eliminar de Favoritos' : 'Añadir a favoritos', style: const TextStyle(color: Colors.white)), 
                  onTap: () { 
                    if (isFav) { box.delete(video.id.value); } else { box.put(video.id.value, {'id': video.id.value, 'title': video.title, 'artist': video.author, 'artUri': video.thumbnails.highResUrl, 'duration': video.duration?.inMilliseconds ?? 0}); }
                    Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isFav ? 'Eliminado de Favoritos' : 'Añadido a Favoritos'), backgroundColor: color)); 
                  }
                );
              }
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add, color: Colors.white), 
              title: const Text('Añadir a lista de reproducción', style: TextStyle(color: Colors.white)), 
              onTap: () { Navigator.pop(context); _showPlaylistDialog(context, video, color); }
            ),
            ListTile(
              leading: const Icon(Icons.radio, color: Colors.white), 
              title: const Text('Iniciar Radio de la canción', style: TextStyle(color: Colors.white)), 
              onTap: () async { 
                Navigator.pop(context); 
                await globalPlay(newItem, audioHandler); 
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Iniciando Radio de ${video.title}'), backgroundColor: color)); 
              }
            ),
          ]
        )
      ); 
    }
  ); 
}

void _showPlaylistDialog(BuildContext context, Video video, Color color) {
  final box = Hive.box('playlists');
  final songData = {'id': video.id.value, 'title': video.title, 'artist': video.author, 'artUri': video.thumbnails.highResUrl, 'duration': video.duration?.inMilliseconds ?? 0};
  showDialog(
    context: context, 
    builder: (context) => AlertDialog(backgroundColor: const Color(0xFF1A1A1A), title: const Text("Mis Playlists", style: TextStyle(color: Colors.white)), content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Icon(Icons.add, color: Colors.white), title: const Text("Crear Nueva Playlist", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), onTap: () { Navigator.pop(context); _showCreatePlaylistDialog(context, songData, color); }), const Divider(color: Colors.white24),
            if (box.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text("No tienes playlists aún", style: TextStyle(color: Colors.grey)))
            else ...box.keys.map((key) => ListTile(leading: const Icon(Icons.queue_music, color: Colors.grey), title: Text(key.toString(), style: const TextStyle(color: Colors.white)), onTap: () {
                List currentList = box.get(key) ?? []; if (!currentList.any((s) => s['id'] == songData['id'])) { currentList.add(songData); box.put(key, currentList); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Agregada a $key'), backgroundColor: color)); } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ya está en esta playlist'), backgroundColor: Colors.redAccent)); } Navigator.pop(context);
              })).toList()
          ])))
  );
}

void _showCreatePlaylistDialog(BuildContext context, Map songData, Color color) {
  final textController = TextEditingController();
  showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF1A1A1A), title: const Text("Nueva Playlist", style: TextStyle(color: Colors.white)), content: TextField(controller: textController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Nombre de la playlist", hintStyle: const TextStyle(color: Colors.grey), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: color)), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: color)))), actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
        TextButton(onPressed: () { if (textController.text.trim().isNotEmpty) { Hive.box('playlists').put(textController.text.trim(), [songData]); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Playlist creada'), backgroundColor: color)); } }, child: Text("Crear", style: TextStyle(color: color, fontWeight: FontWeight.bold)))
      ]));
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});
  @override Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: appColor, builder: (context, color, _) {
        return MaterialApp(
          title: 'Spotify Killer VIP', debugShowCheckedModeBanner: false, 
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF0D0D0D), 
            primaryColor: color, 
            bottomNavigationBarTheme: BottomNavigationBarThemeData(backgroundColor: Colors.transparent, selectedItemColor: color, unselectedItemColor: Colors.grey, type: BottomNavigationBarType.fixed, elevation: 0), 
            appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0D0D0D), elevation: 0, centerTitle: true)
          ), 
          home: const MainNavigationScreen()
        );
      }
    );
  }
}

class MainNavigationScreen extends StatefulWidget { const MainNavigationScreen({super.key}); @override State<MainNavigationScreen> createState() => _MainNavigationScreenState(); }
class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0; final List<Widget> _screens = const [HomeScreen(), SportsTab(), SearchScreen(), VaultScreen(), SettingsTab()];
  @override Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _screens),
          const Positioned(left: 0, right: 0, bottom: 65, child: MiniPlayer()),
        ]
      ),
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: Container(
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), border: const Border(top: BorderSide(color: Colors.white10))),
            child: BottomNavigationBar(
              currentIndex: _currentIndex, 
              onTap: (index) => setState(() => _currentIndex = index), 
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'), 
                BottomNavigationBarItem(icon: Icon(Icons.sports_soccer), label: 'Deportes'), 
                BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'), 
                BottomNavigationBarItem(icon: Icon(Icons.folder_special), label: 'Bóveda'),
                BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ajustes')
              ]
            )
          )
        )
      )
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  Widget _buildHorizontalList(List<Map> items) { return SizedBox(height: 180, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: items.length, padding: const EdgeInsets.symmetric(horizontal: 16), itemBuilder: (context, index) { final item = items[index]; return GestureDetector(onTap: () async { final newItem = MediaItem(id: item['id'], title: item['title'], artist: item['artist'], artUri: Uri.parse(item['artUri']), duration: Duration(milliseconds: item['duration'])); await globalPlay(newItem, audioHandler); }, child: Container(width: 140, margin: const EdgeInsets.only(right: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(item['artUri'], width: 140, height: 140, fit: BoxFit.cover)), const SizedBox(height: 8), Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text(item['artist'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12))]))); })); }
  @override Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(16.0), child: Text("Para ti", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))), ValueListenableBuilder(valueListenable: Hive.box('history').listenable(), builder: (context, Box box, _) { if (box.isEmpty) return const SizedBox.shrink(); final items = box.values.toList().cast<Map>()..sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0)); return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), child: Text("Escuchado recientemente", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), _buildHorizontalList(items.take(10).toList())]); }), const SizedBox(height: 100)]))));
  }
}

class SportsTab extends StatelessWidget {
  const SportsTab({super.key});
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('⚽ Deportes & Ligas', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent),
      body: const Center(child: Text('Filtros de ligas, equipos y partidos en vivo en la próxima fase.', style: TextStyle(color: Colors.grey))),
    );
  }
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🎨 Ajustes', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(leading: const Icon(Icons.share, color: Colors.white), title: const Text('Compartir App', style: TextStyle(color: Colors.white)), onTap: () => Share.share('¡Prueba mi app multimedia VIP!')),
        ],
      ),
    );
  }
}

class SearchScreen extends StatefulWidget { const SearchScreen({super.key}); @override State<SearchScreen> createState() => _SearchScreenState(); }
class _SearchScreenState extends State<SearchScreen> {
  final searchController = TextEditingController(); late final YoutubeExplode _yt;
  List<Video> videos = []; List<String> searchSuggestions = []; bool isLoading = false;
  Timer? _debounce;
  String _lastQuery = "";
  
  final Map<String, String> _categories = {"Tendencias": "Tendencias musica en español", "Podcasts": "Podcasts en español", "Electrónica": "Electronic music mix", "Rock": "Rock clasico en español", "Relajación": "Musica relajante lofi"};

  @override void initState() { super.initState(); _yt = YoutubeExplode(); Permission.notification.request(); }
  @override void dispose() { _debounce?.cancel(); searchController.dispose(); super.dispose(); }

  void _saveSearchHistory(String query) { if (query.trim().isEmpty) return; final box = Hive.box('search_history'); List history = box.get('history') ?? []; history.remove(query); history.insert(0, query); if (history.length > 10) history = history.sublist(0, 10); box.put('history', history); }
  
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.trim().isEmpty) {
      setState(() { searchSuggestions = []; videos = []; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final suggestions = await _yt.search.getQuerySuggestions(query);
        if (mounted) setState(() { searchSuggestions = suggestions.take(6).toList(); });
      } catch (_) {}
    });
  }

  void searchVideos(String query) async { 
    if (query.isEmpty) return; 
    FocusScope.of(context).unfocus(); 
    _saveSearchHistory(query); 
    setState(() { isLoading = true; searchSuggestions = []; _lastQuery = query; }); 
    try { 
      final results = await _yt.search.search(query); 
      setState(() { videos = results.toList(); }); 
    } catch (e) { } finally { 
      setState(() => isLoading = false); 
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
                  trailing: IconButton(icon: const Icon(Icons.north_west, color: Colors.grey, size: 18), onPressed: () { searchController.text = query; _onSearchChanged(query); }),
                  onTap: () { searchController.text = query; searchVideos(query); }
                );
              }).toList()
            );
          }
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text("Explorar Categorías", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white))),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: _categories.entries.map((e) => ActionChip(label: Text(e.key), backgroundColor: const Color(0xFF1A1A1A), onPressed: () { searchController.text = e.key; searchVideos(e.value); })).toList(),
        )
      ]
    );
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscador VIP', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent),
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
                suffixIcon: IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { searchController.clear(); setState(() { videos.clear(); searchSuggestions.clear(); _lastQuery = ""; }); }), 
                filled: true, 
                fillColor: const Color(0xFF1A1A1A), 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0), borderSide: BorderSide.none)
              ), 
              onSubmitted: searchVideos
            )
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
                  ActionChip(label: const Text("🔥 Lo más sonado"), backgroundColor: const Color(0xFF1A1A1A), onPressed: () => searchVideos("$_lastQuery exitos mas escuchados")),
                  const SizedBox(width: 8),
                  ActionChip(label: const Text("🆕 Lo más nuevo"), backgroundColor: const Color(0xFF1A1A1A), onPressed: () => searchVideos("$_lastQuery nuevo 2026")),
                  const SizedBox(width: 8),
                  ActionChip(label: const Text("📻 Radio / Mix"), backgroundColor: const Color(0xFF1A1A1A), onPressed: () => searchVideos("$_lastQuery mix oficial")),
                ],
              ),
            ),
          if (isLoading) Expanded(child: Center(child: ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => CircularProgressIndicator(color: color))))
          else if (videos.isEmpty) Expanded(child: SingleChildScrollView(child: _buildSearchHistory()))
          else Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: videos.length, itemBuilder: (context, index) {
                final video = videos[index];
                final durText = formatGlobalDuration(video.duration);
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(video.thumbnails.lowResUrl, width: 60, height: 60, fit: BoxFit.cover)),
                  title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(durText.isNotEmpty ? "${video.author} • $durText" : video.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.grey), 
                    onPressed: () => globalShowOptions(context, video, appColor.value),
                  ),
                  onTap: () async { final newItem = MediaItem(id: video.id.value, title: video.title, artist: video.author, duration: video.duration, artUri: Uri.parse(video.thumbnails.highResUrl)); await globalPlay(newItem, audioHandler); }
                );
              }
            )
          )
        ]
      )
    );
  }
}

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});
  @override Widget build(BuildContext context) {
    return DefaultTabController(length: 3, child: Scaffold(
      appBar: AppBar(title: const Text('La Bóveda', style: TextStyle(fontWeight: FontWeight.bold)), bottom: const TabBar(indicatorColor: Colors.white, tabs: [Tab(text: 'Historial'), Tab(text: 'Favoritos'), Tab(text: 'Playlists')])),
      body: TabBarView(children: [
        ValueListenableBuilder(valueListenable: Hive.box('history').listenable(), builder: (context, Box box, _) {
          if (box.isEmpty) return const Center(child: Text("Sin historial aún", style: TextStyle(color: Colors.grey)));
          final items = box.values.toList().cast<Map>()..sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0));
          return ListView.builder(padding: const EdgeInsets.only(bottom: 100), itemCount: items.length, itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(item['artUri'], width: 50, height: 50, fit: BoxFit.cover)),
              title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 20), onPressed: () => box.delete(item['id'])),
              onTap: () async { final newItem = MediaItem(id: item['id'], title: item['title'], artist: item['artist'], artUri: Uri.parse(item['artUri']), duration: Duration(milliseconds: item['duration'])); await globalPlay(newItem, audioHandler); }
            );
          });
        }),
        ValueListenableBuilder(valueListenable: Hive.box('favorites').listenable(), builder: (context, Box box, _) {
          if (box.isEmpty) return const Center(child: Text("Sin favoritos aún", style: TextStyle(color: Colors.grey)));
          final items = box.values.toList().cast<Map>();
          return ListView.builder(padding: const EdgeInsets.only(bottom: 100), itemCount: items.length, itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(item['artUri'], width: 50, height: 50, fit: BoxFit.cover)),
              title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: IconButton(icon: const Icon(Icons.favorite, color: Colors.redAccent), onPressed: () => box.delete(item['id'])),
              onTap: () async { 
                List<MediaItem> allFavs = items.map((e) => MediaItem(id: e['id'], title: e['title'], artist: e['artist'], artUri: Uri.parse(e['artUri']), duration: Duration(milliseconds: e['duration']))).toList();
                await globalPlayQueue(allFavs, index, audioHandler); 
              }
            );
          });
        }),
        ValueListenableBuilder(valueListenable: Hive.box('playlists').listenable(), builder: (context, Box box, _) {
          if (box.isEmpty) return const Center(child: Text("Toca los 3 puntitos en una canción para crear listas", style: TextStyle(color: Colors.grey)));
          final keys = box.keys.toList();
          return ListView.builder(padding: const EdgeInsets.only(bottom: 100), itemCount: keys.length, itemBuilder: (context, index) {
            final playlistName = keys[index].toString();
            final tracks = box.get(playlistName) ?? [];
            return ExpansionTile(
              leading: ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => Icon(Icons.queue_music, color: color)),
              title: Text(playlistName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              subtitle: Text("${tracks.length} pistas", style: const TextStyle(color: Colors.grey)),
              trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => box.delete(playlistName)),
              children: tracks.asMap().entries.map<Widget>((entry) {
                int trackIndex = entry.key; final item = entry.value as Map;
                return ListTile(
                  contentPadding: const EdgeInsets.only(left: 40, right: 16),
                  leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(item['artUri'], width: 40, height: 40, fit: BoxFit.cover)),
                  title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                  trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.grey, size: 20), onPressed: () { tracks.removeAt(trackIndex); box.put(playlistName, tracks); }),
                  onTap: () async { List<MediaItem> allTracks = tracks.map<MediaItem>((e) => MediaItem(id: e['id'], title: e['title'], artist: e['artist'], artUri: Uri.parse(e['artUri']), duration: Duration(milliseconds: e['duration']))).toList(); await globalPlayQueue(allTracks, trackIndex, audioHandler); }
                );
              }).toList(),
            );
          });
        })
      ])
    ));
  }
}

class MiniPlayer extends StatefulWidget { const MiniPlayer({super.key}); @override State<MiniPlayer> createState() => _MiniPlayerState(); }
class _MiniPlayerState extends State<MiniPlayer> {
  @override Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(stream: audioHandler.mediaItem, builder: (context, snapshot) {
      final mediaItem = snapshot.data; if (mediaItem == null) return const SizedBox.shrink();
      return GestureDetector(
        onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => const FullScreenPlayer()),
        child: ValueListenableBuilder<Color>(
          valueListenable: appColor, builder: (context, color, _) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: color, width: 0.5), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, spreadRadius: 2)], color: Colors.black.withOpacity(0.9)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(children: [ ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(mediaItem.artUri.toString(), width: 45, height: 45, fit: BoxFit.cover)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(mediaItem.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text(mediaItem.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12))])), StreamBuilder<PlaybackState>(stream: audioHandler.playbackState, builder: (context, snapshot) { final state = snapshot.data; final playing = state?.playing ?? false; final isLoading = state?.processingState == AudioProcessingState.loading || state?.processingState == AudioProcessingState.buffering; return IconButton(icon: isLoading ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: color, strokeWidth: 2)) : Icon(playing ? Icons.pause : Icons.play_arrow, color: color), onPressed: () { if (playing) { audioHandler.pause(); } else { audioHandler.play(); } }); }) ])
                  )
                )
              )
            );
          }
        )
      );
    });
  }
}

class FullScreenPlayer extends StatelessWidget {
  const FullScreenPlayer({super.key});

  void _showQueueBottomSheet(BuildContext context, List<MediaItem> queueList, int currentIndex, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              const Text("Cola de Reproducción", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white24),
              Expanded(
                child: ListView.builder(
                  itemCount: queueList.length,
                  itemBuilder: (context, index) {
                    final item = queueList[index];
                    final isPlaying = index == currentIndex;
                    return ListTile(
                      leading: isPlaying ? Icon(Icons.volume_up, color: color) : Text('${index + 1}', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isPlaying ? color : Colors.white)),
                      subtitle: Text(item.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
                      trailing: IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () {
                        audioHandler.removeFromQueue(item);
                        Navigator.pop(context);
                      }),
                      onTap: () {
                        Navigator.pop(context);
                        audioHandler.skipToQueueItem(index);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  @override Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.95, decoration: const BoxDecoration(color: Color(0xFF0D0D0D), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: StreamBuilder<MediaItem?>(stream: audioHandler.mediaItem, builder: (context, snapshot) {
        final mediaItem = snapshot.data; if (mediaItem == null) return const SizedBox.shrink();
        return Column(children: [
          const SizedBox(height: 10), Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))), const SizedBox(height: 30),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) { return Container(decoration: BoxDecoration(boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 40, spreadRadius: 10)]), child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(mediaItem.artUri.toString(), width: double.infinity, height: 320, fit: BoxFit.cover))); })),
          const SizedBox(height: 40),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(mediaItem.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(mediaItem.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, color: Colors.grey))])), ValueListenableBuilder(valueListenable: Hive.box('favorites').listenable(), builder: (context, Box box, _) { final isFav = box.containsKey(mediaItem.id); return IconButton(icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : Colors.white), onPressed: () { if (isFav) { box.delete(mediaItem.id); } else { box.put(mediaItem.id, {'id': mediaItem.id, 'title': mediaItem.title, 'artist': mediaItem.artist, 'artUri': mediaItem.artUri.toString(), 'duration': mediaItem.duration?.inMilliseconds ?? 0}); } }); })])),
          const SizedBox(height: 20),
          StreamBuilder<Duration>(stream: AudioService.position, builder: (context, snapshotPosition) { 
            final pos = snapshotPosition.data ?? Duration.zero; 
            return StreamBuilder<PlaybackState>(stream: audioHandler.playbackState, builder: (context, snapshot) { 
              final state = snapshot.data; 
              final isLoading = state?.processingState == AudioProcessingState.loading || state?.processingState == AudioProcessingState.buffering; 
              final dur = mediaItem.duration ?? Duration.zero; 
              final buffered = state?.bufferedPosition ?? Duration.zero;
              final maxDur = dur.inMilliseconds.toDouble() > 0 ? dur.inMilliseconds.toDouble() : 1.0;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30), 
                  child: ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) { 
                    return SliderTheme(
                      data: SliderTheme.of(context).copyWith(trackHeight: 4, activeTrackColor: color, secondaryActiveTrackColor: Colors.white54, inactiveTrackColor: Colors.white24, thumbColor: color, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), overlayShape: const RoundSliderOverlayShape(overlayRadius: 14)), 
                      child: Slider(
                        value: isLoading ? 0.0 : pos.inMilliseconds.toDouble().clamp(0.0, maxDur), 
                        secondaryTrackValue: isLoading ? 0.0 : buffered.inMilliseconds.toDouble().clamp(0.0, maxDur),
                        max: maxDur, 
                        onChanged: (v) { if (!isLoading) audioHandler.seek(Duration(milliseconds: v.round())); }
                      )
                    ); 
                  })
                ), 
                Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(formatGlobalDuration(pos), style: const TextStyle(color: Colors.grey, fontSize: 12)), Text(formatGlobalDuration(mediaItem.duration), style: const TextStyle(color: Colors.grey, fontSize: 12))]))
              ]); 
            }); 
          }),
          const Spacer(),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: StreamBuilder<PlaybackState>(stream: audioHandler.playbackState, builder: (context, snapshot) { final state = snapshot.data; final playing = state?.playing ?? false; final isLoading = state?.processingState == AudioProcessingState.loading || state?.processingState == AudioProcessingState.buffering; return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [ValueListenableBuilder<int>(valueListenable: audioHandler.sleepTimerRemaining, builder: (context, remaining, _) { return IconButton(icon: Icon(Icons.timer, color: remaining > 0 ? appColor.value : Colors.grey), onPressed: () => _showSleepTimerDialog(context)); }), IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white, size: 36), onPressed: () => audioHandler.skipToPrevious()), ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) { return Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 20, spreadRadius: 5)]), child: IconButton(icon: isLoading ? const CircularProgressIndicator(color: Colors.black) : Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 36), onPressed: () { if (playing) { audioHandler.pause(); } else { audioHandler.play(); } })); }), IconButton(icon: const Icon(Icons.skip_next, color: Colors.white, size: 36), onPressed: () => audioHandler.skipToNext()), IconButton(icon: const Icon(Icons.shuffle, color: Colors.white), onPressed: () { audioHandler.shuffleQueue(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cola mezclada'), duration: Duration(seconds: 1))); })]); })),
          const Spacer(),
          StreamBuilder<List<MediaItem>>(
            stream: audioHandler.queue,
            builder: (context, queueSnapshot) {
              final queueList = queueSnapshot.data ?? [];
              if (queueList.isEmpty) return const SizedBox.shrink();
              final currentIndex = queueList.indexWhere((i) => i.id == mediaItem.id);
              return GestureDetector(
                onTap: () => _showQueueBottomSheet(context, queueList, currentIndex, appColor.value),
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
                    _showQueueBottomSheet(context, queueList, currentIndex, appColor.value);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
                      const Icon(Icons.keyboard_arrow_up, color: Colors.grey),
                      Text('Siguiente: ${currentIndex + 1} de ${queueList.length}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            }
          ),
        ]);
      })
    );
  }
  void _showSleepTimerDialog(BuildContext context) { showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1A1A1A), builder: (context) { return Wrap(children: [const ListTile(title: Text("Temporizador", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))), _timerOption(context, "Desactivar", 0), _timerOption(context, "15 minutos", 15), _timerOption(context, "30 minutos", 30), _timerOption(context, "60 minutos", 60)]); }); }
  Widget _timerOption(BuildContext context, String label, int minutes) { return ListTile(title: Text(label, style: const TextStyle(color: Colors.white70)), onTap: () { audioHandler.customAction('setSleepTimer', {'minutes': minutes}); Navigator.pop(context); }); }
}
