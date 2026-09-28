import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_downloader/flutter_downloader.dart';

// Importa tu Bóveda Offline
import 'offline_vault_screen.dart';

class VIPHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)';
  }
}

// Variables Globales
late MyAudioHandler audioHandler;
final ValueNotifier<bool> isHDMode = ValueNotifier<bool>(true);
final ValueNotifier<Color> appColor = ValueNotifier<Color>(Colors.cyanAccent);
final ValueNotifier<int> sleepTimerRemaining = ValueNotifier<int>(0);

Future<String?> obtenerAudioDirecto(String videoId) async {
  try {
    final yt = YoutubeExplode();
    final manifest = await yt.videos.streamsClient.getManifest(videoId);
    final streamsMp4 = manifest.audioOnly.where((stream) => stream.container.name == 'mp4');
    final streamInfo = streamsMp4.withHighestBitrate();
    yt.close();
    return streamInfo.url.toString();
  } catch (e) {
    print("Error obteniendo URL: \$e");
    return null;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = VIPHttpOverrides();

  await Hive.openBox('cerrojo_box');
  await Hive.initFlutter();
  await Hive.openBox('favorites');
  await Hive.openBox('history');
  await Hive.openBox('search_history');
  await Hive.openBox('playlists');
  await Hive.openBox('downloads'); // Caja para la Bóveda Offline

  await FlutterDownloader.initialize(debug: true, ignoreSsl: true);

  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.tuapp.audio',
      androidNotificationChannelName: 'Spotify Killer VIP',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(const MediaApp());
}

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  final _yt = YoutubeExplode();
  bool _isAutoPlayEnabled = true;
  String? _lastPlayedId;
  DateTime? _lastPlayTime;

  MyAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);
    
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });

    _player.positionStream.listen((position) {
      final currentState = playbackState.value;
      playbackState.add(currentState.copyWith(updatePosition: position));
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'playLocal' && extras != null) {
      final localPath = extras['localPath'] as String;
      final title = extras['title'] as String;
      final artist = extras['artist'] as String;
      final artUri = extras['artUri'] as String;
      final duration = extras['duration'] as int? ?? 0;
      
      final newItem = MediaItem(
        id: localPath,
        title: title,
        artist: artist,
        artUri: Uri.parse(artUri),
        duration: Duration(seconds: duration),
        extras: {'isLocal': true},
      );
      
      mediaItem.add(newItem);
      await _player.setFilePath(localPath);
      play();
    }
  }

  @override
  Future<void> playMediaItem(MediaItem item) async {
    final now = DateTime.now();
    if (_lastPlayedId == item.id && _lastPlayTime != null) {
      if (now.difference(_lastPlayTime!).inSeconds < 2) {
        print("Bloqueo anti-rebote activado para: \${item.title}");
        return;
      }
    }
    
    _lastPlayedId = item.id;
    _lastPlayTime = now;
    mediaItem.add(item);
    
    final historyBox = Hive.box('history');
    final itemMap = {
      'id': item.id,
      'title': item.title,
      'artist': item.artist ?? 'Desconocido',
      'duration': item.duration?.inSeconds ?? 0,
      'artUri': item.artUri?.toString() ?? '',
    };
    
    historyBox.put(item.id, itemMap);
    if (historyBox.length > 50) {
      historyBox.deleteAt(0);
    }

    try {
      final url = await obtenerAudioDirecto(item.id);
      if (url != null) {
        await _player.setUrl(url);
        play();
      } else {
        print("No se pudo obtener URL para: \${item.title}");
      }
    } catch (e) {
      print("Error en playMediaItem: \$e");
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    queue.add(newQueue);
  }

  @override
  Future<void> skipToNext() async {
    final queueList = queue.value;
    if (queueList.isEmpty) return;
    
    final currentItem = mediaItem.value;
    final currentIndex = queueList.indexWhere((item) => item.id == currentItem?.id);
    
    if (currentIndex != -1 && currentIndex < queueList.length - 1) {
      await playMediaItem(queueList[currentIndex + 1]);
    } else if (_isAutoPlayEnabled && currentItem != null && currentItem.extras?['isLocal'] != true) {
      await _autoPlayNext(currentItem.id);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final queueList = queue.value;
    if (queueList.isEmpty) return;
    
    final currentItem = mediaItem.value;
    final currentIndex = queueList.indexWhere((item) => item.id == currentItem?.id);
    
    if (currentIndex > 0) {
      await playMediaItem(queueList[currentIndex - 1]);
    }
  }

  Future<void> _autoPlayNext(String videoId) async {
    try {
      final video = await _yt.videos.get(videoId);
      final relatedList = await _yt.videos.getRelatedVideos(video);
if (relatedList == null || relatedList.isEmpty) return;
final related = relatedList.first;
      
      final nextItem = MediaItem(
        id: related.id.value,
        title: related.title,
        artist: related.author,
        duration: related.duration,
        artUri: Uri.parse(related.thumbnails.highResUrl),
      );
      
      final currentQueue = queue.value.toList();
      currentQueue.add(nextItem);
      queue.add(currentQueue);
      
      await playMediaItem(nextItem);
    } catch (e) {
      print("Error en AutoPlay: \$e");
    }
  }
}

// --- Funciones Globales para acceder desde la UI ---
Future<void> globalPlay(MediaItem item) async {
  await audioHandler.updateQueue([item]);
  await audioHandler.playMediaItem(item);
}

Future<void> globalPlayQueue(List<MediaItem> items, int startIndex) async {
  await audioHandler.updateQueue(items);
  await audioHandler.playMediaItem(items[startIndex]);
}
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

String formatGlobalDuration(Duration? d) {
  if (d == null) return "Live";
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return "${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds";
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
  showModalBottomSheet(
    context: context, backgroundColor: const Color(0xFF1A1A1A), isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(video.thumbnails.highResUrl, width: 50, height: 50, fit: BoxFit.cover)), title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), subtitle: Text(video.author, style: const TextStyle(color: Colors.grey))),
            const Divider(color: Colors.white24),
            ListTile(leading: const Icon(Icons.radio, color: Colors.white), title: const Text('Ir a la radio de la canción', style: TextStyle(color: Colors.white))),
            ListTile(leading: const Icon(Icons.playlist_add, color: Colors.white), title: const Text('Agregar a una playlist', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _showPlaylistDialog(context, video, color); }),
            ListTile(
              leading: const Icon(Icons.queue_music, color: Colors.white),
              title: const Text('Agregar a la cola', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final itemToQueue = MediaItem(id: video.id.value, title: video.title, artist: video.author, duration: video.duration, artUri: Uri.parse(video.thumbnails.highResUrl));
                await audioHandler.addQueueItem(itemToQueue);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Canción agregada a la cola')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.white),
              title: const Text('Descargar', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                downloadAudio(context, video);
              },
            ),
            ValueListenableBuilder(
              valueListenable: Hive.box('favorites').listenable(),
              builder: (context, Box box, _) {
                final isFav = box.containsKey(video.id.value);
                return ListTile(
                  leading: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : Colors.white),
                  title: Text(isFav ? 'Eliminar de Tus me gusta' : 'Agregar a Tus me gusta', style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    if (isFav) { box.delete(video.id.value); } else { box.put(video.id.value, {'id': video.id.value, 'title': video.title, 'artist': video.author, 'artUri': video.thumbnails.highResUrl, 'duration': video.duration?.inMilliseconds ?? 0}); }
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isFav ? 'Eliminado de Favoritos' : 'Agregado a Favoritos'), backgroundColor: color));
                  }
                );
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
    builder: (context) => AlertDialog(backgroundColor: const Color(0xFF1A1A1A), title: const Text("Mis Playlists", style: TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.add, color: Colors.white), title: const Text("Crear Nueva Playlist", style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _showCreatePlaylistDialog(context, songData, color); }),
        if (box.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text("No tienes playlists aún", style: TextStyle(color: Colors.grey)))
        else ...box.keys.map((key) => ListTile(leading: const Icon(Icons.queue_music, color: Colors.grey), title: Text(key.toString(), style: const TextStyle(color: Colors.white)), onTap: () { final currentList = box.get(key) ?? []; if (!currentList.any((s) => s['id'] == songData['id'])) { currentList.add(songData); box.put(key, currentList); } Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Agregado a $key"), backgroundColor: color)); })).toList()
      ])
    )
  );
}

void _showCreatePlaylistDialog(BuildContext context, Map songData, Color color) {
  final textController = TextEditingController();
  showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF1A1A1A), title: const Text("Nueva Playlist", style: TextStyle(color: Colors.white)),
    content: TextField(controller: textController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Nombre de la playlist", hintStyle: TextStyle(color: Colors.grey))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
      TextButton(onPressed: () { if (textController.text.trim().isNotEmpty) { Hive.box('playlists').put(textController.text.trim(), [songData]); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Playlist creada"), backgroundColor: color)); } }, child: const Text("Crear", style: TextStyle(color: Colors.white)))
    ]
  ));
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});
  
  @override 
  Widget build(BuildContext context) {
    final bool accesoConcedido = Hive.box('cerrojo_box').get('acceso_concedido', defaultValue: false);
  
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
              type: BottomNavigationBarType.fixed
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0D0D0D), 
              elevation: 0, 
              centerTitle: true
            )
          ),
          home: accesoConcedido ? const SuperAppSkeleton() : const CerrojoScreen(),
        );
      }
    );
  }
}

class SuperAppSkeleton extends StatefulWidget { const SuperAppSkeleton({super.key}); @override State<SuperAppSkeleton> createState() => _SuperAppSkeletonState(); }
class _SuperAppSkeletonState extends State<SuperAppSkeleton> {
  int _currentIndex = 0; final List<Widget> _screens = [const HomeScreen(), const SearchScreen(), OfflineVaultScreen(audioHandler: audioHandler), const VaultScreen(), const SportsScreen()];
  @override Widget build(BuildContext context) { 
    return Scaffold(
      extendBody: true, 
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _screens),
          const Positioned(left: 0, right: 0, bottom: 65, child: MiniPlayer()), 
        ],
      ), 
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: Container(
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), border: const Border(top: BorderSide(color: Colors.white10, width: 1))),
            child: BottomNavigationBar(currentIndex: _currentIndex, onTap: (index) => setState(() => _currentIndex = index), items: const [BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Inicio'), BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'), BottomNavigationBarItem(icon: Icon(Icons.fingerprint), label: 'Bóveda'), BottomNavigationBarItem(icon: Icon(Icons.queue_music), label: 'VIP'), BottomNavigationBarItem(icon: Icon(Icons.stadium), label: 'Deportes')]),
          ),
        ),
      )
    ); 
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  Widget _buildHorizontalList(List<Map> items) { return SizedBox(height: 180, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: items.length, itemBuilder: (context, index) { final item = items[index]; return GestureDetector(onTap: () async { final mediaItem = MediaItem(id: item['id'], title: item['title'], artist: item['artist'], artUri: Uri.parse(item['artUri']), duration: Duration(milliseconds: item['duration'])); await globalPlay(mediaItem); }, child: Container(width: 120, margin: const EdgeInsets.only(right: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(item['artUri'], width: 120, height: 120, fit: BoxFit.cover)), const SizedBox(height: 8), Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)), Text(item['artist'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 11))]))); })); }
  @override Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => ConspiracyLogo(size: 60, color: color)), IconButton(icon: const Icon(Icons.settings, color: Colors.grey, size: 28), onPressed: () { showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1A1A1A), builder: (context) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Ajustes VIP", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 20), const Text("Color del Neón", style: TextStyle(color: Colors.grey)), const SizedBox(height: 10), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Colors.cyanAccent, Colors.purpleAccent, Colors.greenAccent, Colors.amberAccent, Colors.blueAccent, Colors.white].map((c) => GestureDetector(onTap: () { appColor.value = c; Navigator.pop(context); }, child: Container(width: 40, height: 40, decoration: BoxDecoration(color: c, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c, blurRadius: 10)], border: Border.all(color: Colors.white24, width: 2))))).toList()), const SizedBox(height: 20), const Divider(color: Colors.white24), const SizedBox(height: 10), ListTile(leading: const Icon(Icons.delete_forever, color: Colors.redAccent), title: const Text("Botón Nuclear (Borrar Todo)", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)), subtitle: const Text("Resetea todo el algoritmo y bóveda", style: TextStyle(color: Colors.grey, fontSize: 12)), onTap: () { Hive.box('history').clear(); Hive.box('favorites').clear(); Hive.box('search_history').clear(); Hive.box('playlists').clear(); audioHandler.updateQueue([]); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Memoria de la app borrada. Renacimiento VIP.'), backgroundColor: Colors.redAccent)); })]))); })])), ValueListenableBuilder(valueListenable: Hive.box('history').listenable(), builder: (context, Box box, _) { if (box.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text("Comienza a escuchar música para activar el radar.", style: TextStyle(color: Colors.grey))); final allItems = box.values.toList().cast<Map>(); final recentItems = List<Map>.from(allItems)..sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0)); final topItems = List<Map>.from(allItems)..sort((a, b) => (b['playCount'] as int? ?? 0).compareTo(a['playCount'] as int? ?? 0)); return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text("Escuchado Recientemente", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))), _buildHorizontalList(recentItems), const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text("Tu Frecuencia Máxima (Top 25)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))), _buildHorizontalList(topItems.take(25).toList()), const SizedBox(height: 100)]); })]))));
  }
}

class SearchScreen extends StatefulWidget { const SearchScreen({super.key}); @override State<SearchScreen> createState() => _SearchScreenState(); }
class _SearchScreenState extends State<SearchScreen> {
  final searchController = TextEditingController(); late final YoutubeExplode yt; 
  List<Video> videos = []; List<String> searchSuggestions = []; bool isLoading = false;
  Timer? _debounce; 
  
  @override void initState() { super.initState(); yt = YoutubeExplode(); Permission.notification.request(); }
  @override void dispose() { _debounce?.cancel(); searchController.dispose(); super.dispose(); }
  
  void _saveSearchHistory(String query) { if (query.trim().isEmpty) return; final box = Hive.box('search_history'); List<String> searches = box.values.cast<String>().toList(); searches.remove(query); searches.insert(0, query); if (searches.length > 15) searches = searches.sublist(0, 15); box.clear(); box.addAll(searches); }
  void searchVideos(String query) async {
    if (query.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    _saveSearchHistory(query);
    setState(() { isLoading = true; videos.clear(); });
    try {
      final results = await yt.search.search(query);
      setState(() { videos = results.toList(); isLoading = false; });
    } catch (e) {
      setState(() { isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de conexión con YouTube: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 6)));
    }
  }
  
  Widget _buildSearchHistory() {
    return ListView(
      children: [
        ValueListenableBuilder(
          valueListenable: Hive.box('search_history').listenable(),
          builder: (context, Box box, _) {
            if (box.isEmpty) return const SizedBox.shrink();
            final history = box.values.cast<String>().toList();
            return Column(
              children: history.map((query) {
                int index = history.indexOf(query);
                return ListTile(leading: const Icon(Icons.history, color: Colors.grey), title: Text(query, style: const TextStyle(color: Colors.white)), onTap: () { searchController.text = query; searchVideos(query); }, trailing: Row(mainAxisSize: MainAxisSize.min, children: [ IconButton(icon: const Icon(Icons.north_west, color: Colors.grey, size: 20), onPressed: () { searchController.text = query; searchController.selection = TextSelection.fromPosition(TextPosition(offset: searchController.text.length)); }), IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 20), onPressed: () { final newHistory = List<String>.from(history)..removeAt(index); box.clear(); box.addAll(newHistory); }), ]));
              }).toList(),
            );
          }
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text("Escuchado Recientemente", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16))),
        ValueListenableBuilder(
          valueListenable: Hive.box('history').listenable(),
          builder: (context, Box box, _) {
            if (box.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text("Aún no hay canciones en tu registro.", style: TextStyle(color: Colors.grey)));
            final items = box.values.toList().cast<Map>()..sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0));
            return Column(
              children: items.take(15).map((item) {
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(item['artUri'], width: 50, height: 50, fit: BoxFit.cover)),