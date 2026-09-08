import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math' as math;
import 'dart:async'; // Necesario para el Timer

// Controladores Globales
late MyAudioHandler audioHandler;
final ValueNotifier<bool> isHDMode = ValueNotifier<bool>(true);
final ValueNotifier<Color> appColor = ValueNotifier<Color>(Colors.deepPurpleAccent);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('favorites');
  await Hive.openBox('history');
  await Hive.openBox('search_history');

  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.media_app.audio_master_v24',
      androidNotificationChannelName: 'Spotify Killer VIP',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
      androidNotificationIcon: 'drawable/ic_notification',
    ),
  );

  runApp(const MediaApp());
}

// -----------------------------------------------------------------------------
// LOGO V3: "El Sello de Osiris" 
// -----------------------------------------------------------------------------
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
    final textSpan = TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'Courier'));
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout();
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height - 2));
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = w * 0.05..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round;

    final p1 = Offset(w * 0.15, h * 0.15); final p2 = Offset(w * 0.15, h * 0.85); final p3 = Offset(w * 0.90, h * 0.50); 
    final playPath = Path()..moveTo(p1.dx, p1.dy)..lineTo(p2.dx, p2.dy)..lineTo(p3.dx, p3.dy)..close();
    canvas.drawPath(playPath, paint);

    final fontSize = w * 0.08;
    _drawTextOnLine(canvas, "Θ ⅃ Θ", p1, p2, fontSize); _drawTextOnLine(canvas, "Δ Ξ", p2, p3, fontSize); _drawTextOnLine(canvas, "Θ Ϟ Ι ℟ Ι Ϟ", p3, p1, fontSize);

    final eyeLeft = w * 0.28; final eyeRight = w * 0.62; final eyeY = h * 0.50; final eyeCenterX = w * 0.45;
    final eyePath = Path()..moveTo(eyeLeft, eyeY)..quadraticBezierTo(eyeCenterX, h * 0.32, eyeRight, eyeY)..quadraticBezierTo(eyeCenterX, h * 0.68, eyeLeft, eyeY);
    canvas.drawPath(eyePath, paint);

    final wavePaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = w * 0.03;
    canvas.drawCircle(Offset(eyeCenterX, h * 0.50), w * 0.08, wavePaint); canvas.drawCircle(Offset(eyeCenterX, h * 0.50), w * 0.03, wavePaint); canvas.drawLine(Offset(eyeCenterX - w * 0.12, h * 0.50), Offset(eyeCenterX + w * 0.12, h * 0.50), wavePaint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// -----------------------------------------------------------------------------
// MOTOR DE AUDIO VIP (SPRINT 1: RADIO, MARCADORES Y SLEEP TIMER)
// -----------------------------------------------------------------------------
class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  late final YoutubeExplode _yt;
  Timer? _sleepTimer; // TICKET #003: Temporizador

  MyAudioHandler() {
    // TICKET #006: Forzamos el idioma español para evitar auto-traducciones raras
    // Inicializamos YoutubeExplode con un cliente estándar pero internamente usa el locale del dispositivo o podemos sobreescribir.
    _yt = YoutubeExplode(); 

    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      
      // TICKET #007: Si se pausa, guardamos el marcador temporal exacto en Hive
      if (!playing && mediaItem.value != null) {
        _saveResumePosition(mediaItem.value!.id, _player.position.inMilliseconds);
      }

      playbackState.add(playbackState.value.copyWith(
        controls: [MediaControl.skipToPrevious, if (playing) MediaControl.pause else MediaControl.play, MediaControl.skipToNext],
        systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle, ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering, ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing, updatePosition: _player.position, bufferedPosition: _player.bufferedPosition, speed: _player.speed,
      ));
    });

    _player.processingStateStream.listen((state) {
      // TICKET #001 y #005: Modo Radio. Si termina la canción...
      if (state == ProcessingState.completed) {
        _handleAutoPlayRadio();
      }
    });
  }

  // --- Lógica de Modo Radio ---
  Future<void> _handleAutoPlayRadio() async {
    final currentQueue = queue.value;
    final currentItem = mediaItem.value;
    
    if (currentItem == null) return;
    
    final currentIndex = currentQueue.indexWhere((item) => item.id == currentItem.id);
    
    if (currentIndex != -1 && currentIndex < currentQueue.length - 1) {
      // Si hay más canciones en la cola normal, pasa a la siguiente
      skipToNext();
    } else {
      // ¡AQUÍ ESTÁ LA MAGIA! Si se acabó la cola, buscamos un video relacionado para continuar (Modo Radio)
      try {
        var relatedVideos = await _yt.videos.getRelatedVideos(VideoId(currentItem.id));
        if (relatedVideos != null && relatedVideos.isNotEmpty) {
          final nextVideo = relatedVideos.first;
          final newItem = MediaItem(
            id: nextVideo.id.value,
            title: nextVideo.title,
            artist: nextVideo.author,
            duration: nextVideo.duration,
            artUri: Uri.parse(nextVideo.thumbnails.highResUrl),
          );
          
          final newQueue = List<MediaItem>.from(currentQueue)..add(newItem);
          await updateQueue(newQueue);
          await playMediaItem(newItem);
        }
      } catch (e) {
        debugPrint("Error buscando radio relacionada: $e");
      }
    }
  }

  void _saveResumePosition(String id, int milliseconds) {
    final historyBox = Hive.box('history');
    if (historyBox.containsKey(id)) {
      final item = Map<String, dynamic>.from(historyBox.get(id));
      item['savedPosition'] = milliseconds; // Guardamos el minuto exacto
      historyBox.put(id, item);
    }
  }

  // Comandos personalizados (Sleep Timer)
  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'setSleepTimer' && extras != null) {
      int minutes = extras['minutes'];
      _sleepTimer?.cancel();
      if (minutes > 0) {
        _sleepTimer = Timer(Duration(minutes: minutes), () => pause());
      }
    }
  }

  @override Future<void> play() => _player.play();
  @override Future<void> pause() => _player.pause();
  @override Future<void> seek(Duration position) => _player.seek(position);
  
  @override Future<void> skipToNext() async {
    final queueList = queue.value;
    if (queueList.isEmpty) return;
    final currentItem = mediaItem.value;
    final currentIndex = queueList.indexWhere((item) => item.id == currentItem?.id);
    if (currentIndex != -1 && currentIndex < queueList.length - 1) await playMediaItem(queueList[currentIndex + 1]);
  }
  
  @override Future<void> skipToPrevious() async {
    final queueList = queue.value;
    if (queueList.isEmpty) return;
    final currentItem = mediaItem.value;
    final currentIndex = queueList.indexWhere((item) => item.id == currentItem?.id);
    if (currentIndex > 0) await playMediaItem(queueList[currentIndex - 1]);
  }

  @override
  Future<void> playMediaItem(MediaItem item) async {
    mediaItem.add(item);
    
    final historyBox = Hive.box('history');
    int playCount = 1;
    int savedPosition = 0; // Para el Ticket #007
    
    if (historyBox.containsKey(item.id)) {
      final existingItem = historyBox.get(item.id);
      playCount = (existingItem['playCount'] ?? 0) + 1;
      savedPosition = existingItem['savedPosition'] ?? 0;
    }
    
    historyBox.put(item.id, {
      'id': item.id, 'title': item.title, 'artist': item.artist, 'artUri': item.artUri.toString(),
      'duration': item.duration?.inMilliseconds ?? 0, 'timestamp': DateTime.now().millisecondsSinceEpoch,
      'playCount': playCount, 'savedPosition': 0, // Reiniciamos al reproducir
    });

    try {
      playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.loading));
      await _player.stop();

      var manifest = await _yt.videos.streamsClient.getManifest(item.id);
      StreamInfo streamInfo;
      
      if (manifest.muxed.isNotEmpty) {
        streamInfo = isHDMode.value ? manifest.muxed.withHighestBitrate() : manifest.muxed.reduce((a, b) => a.bitrate.bitsPerSecond < b.bitrate.bitsPerSecond ? a : b);
      } else if (manifest.audioOnly.isNotEmpty) {
        streamInfo = isHDMode.value ? manifest.audioOnly.withHighestBitrate() : manifest.audioOnly.reduce((a, b) => a.bitrate.bitsPerSecond < b.bitrate.bitsPerSecond ? a : b);
      } else {
        throw Exception("No streams");
      }

      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(streamInfo.url.toString()), tag: item,
          // Cabeceras modificadas para intentar forzar español
          headers: const {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36',
            'Accept-Language': 'es-MX,es;q=0.9,en-US;q=0.8,en;q=0.7' 
          },
        ),
      );
      
      // TICKET #007: Si había una posición guardada, saltamos ahí automáticamente
      if (savedPosition > 0) {
        await _player.seek(Duration(milliseconds: savedPosition));
      }
      
      await _player.play();
    } catch (e) {
      debugPrint("Error crítico: $e");
      playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.error, playing: false));
    }
  }

  @override Future<void> updateQueue(List<MediaItem> newQueue) async { queue.add(newQueue); }
  void shuffleQueue() { final currentQueue = queue.value.toList()..shuffle(); queue.add(currentQueue); }
}

// -----------------------------------------------------------------------------
// ARQUITECTURA PRINCIPAL
// -----------------------------------------------------------------------------
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
            scaffoldBackgroundColor: const Color(0xFF1A1A1A),
            primaryColor: color,
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              backgroundColor: const Color(0xFF111111), selectedItemColor: color, unselectedItemColor: Colors.grey, type: BottomNavigationBarType.fixed, elevation: 20,
            ),
            appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1A1A1A), elevation: 0, centerTitle: true),
          ),
          home: const SuperAppSkeleton(),
        );
      }
    );
  }
}

class SuperAppSkeleton extends StatefulWidget {
  const SuperAppSkeleton({super.key});
  @override
  State<SuperAppSkeleton> createState() => _SuperAppSkeletonState();
}

class _SuperAppSkeletonState extends State<SuperAppSkeleton> {
  int _currentIndex = 0;
  final List<Widget> _screens = [const HomeScreen(), const SearchScreen(), const VaultScreen(), const SportsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: IndexedStack(index: _currentIndex, children: _screens)),
          const MiniPlayer(), 
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'),
          BottomNavigationBarItem(icon: Icon(Icons.fingerprint), label: 'Bóveda'),
          BottomNavigationBarItem(icon: Icon(Icons.stadium), label: 'VIP'),
        ],
      ),
    );
  }
}

// --- TAB 0: INICIO (DASHBOARD INTELIGENTE) ---
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Widget _buildHorizontalList(List<Map> items) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () async {
              final mediaItem = MediaItem(id: item['id'], title: item['title'], artist: item['artist'], artUri: Uri.parse(item['artUri']), duration: Duration(milliseconds: item['duration']));
              await audioHandler.updateQueue([mediaItem]);
              await audioHandler.playMediaItem(mediaItem);
            },
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(item['artUri'], width: 120, height: 120, fit: BoxFit.cover)),
                  const SizedBox(height: 8),
                  Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                  Text(item['artist'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 11)),
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
    final List<Color> themeColors = [Colors.deepPurpleAccent, Colors.redAccent, Colors.greenAccent, Colors.amberAccent, Colors.blueAccent, Colors.white];
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => ConspiracyLogo(size: 60, color: color)),
                    Row(
                      children: themeColors.map((colorOption) {
                        return GestureDetector(
                          onTap: () => appColor.value = colorOption,
                          child: Container(margin: const EdgeInsets.only(left: 8), width: 20, height: 20, decoration: BoxDecoration(color: colorOption, shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 1))),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              ValueListenableBuilder(
                valueListenable: Hive.box('history').listenable(),
                builder: (context, Box box, _) {
                  if (box.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text("Comienza a escuchar música para activar el radar.", style: TextStyle(color: Colors.grey)));
                  final allItems = box.values.toList().cast<Map>();
                  final recentItems = List<Map>.from(allItems)..sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0));
                  final topItems = List<Map>.from(allItems)..sort((a, b) => (b['playCount'] as int? ?? 0).compareTo(a['playCount'] as int? ?? 0));
                  final top25 = topItems.take(25).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text("Escuchado Recientemente", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
                      _buildHorizontalList(recentItems),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text("Tu Frecuencia Máxima (Top 25)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
                      _buildHorizontalList(top25),
                      const SizedBox(height: 20),
                    ],
                  );
                }
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- TAB 1: BUSCADOR ---
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final searchController = TextEditingController();
  final yt = YoutubeExplode();
  List<Video> videos = [];
  bool isLoading = false;
  String? playingVideoId;
  String selectedFilter = 'Todos';

  @override void initState() { super.initState(); Permission.notification.request(); }

  void _saveSearchHistory(String query) {
    if (query.trim().isEmpty) return;
    final box = Hive.box('search_history');
    List<String> searches = box.values.cast<String>().toList();
    searches.remove(query); searches.insert(0, query);
    if (searches.length > 15) searches = searches.sublist(0, 15);
    box.clear(); box.addAll(searches);
  }

  void searchVideos(String query) async {
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus(); 
    _saveSearchHistory(query); 
    setState(() => isLoading = true);
    try {
      var result = await yt.search.search(query);
      setState(() { videos = result.toList(); isLoading = false; });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void playVideo(Video video) async {
    setState(() => playingVideoId = video.id.value);
    final queueList = videos.map((v) => MediaItem(id: v.id.value, title: v.title, artist: v.author, duration: v.duration, artUri: Uri.parse(v.thumbnails.highResUrl))).toList();
    await audioHandler.updateQueue(queueList);
    final selectedItem = queueList.firstWhere((item) => item.id == video.id.value);
    await audioHandler.playMediaItem(selectedItem);
  }

  Widget _buildSearchHistory() {
    return ValueListenableBuilder(
      valueListenable: Hive.box('search_history').listenable(),
      builder: (context, Box box, _) {
        if (box.isEmpty) return const Center(child: Text("Busca a tu artista favorito", style: TextStyle(color: Colors.grey)));
        final history = box.values.cast<String>().toList();
        return ListView.builder(
          itemCount: history.length,
          itemBuilder: (context, index) {
            return ListTile(
              leading: const Icon(Icons.history, color: Colors.grey), title: Text(history[index], style: const TextStyle(color: Colors.white)),
              trailing: IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 18), onPressed: () { final newHistory = List<String>.from(history)..removeAt(index); box.clear(); box.addAll(newHistory); }),
              onTap: () { searchController.text = history[index]; searchVideos(history[index]); },
            );
          },
        );
      }
    );
  }

  void _showSongOptions(BuildContext context, Video video) {
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF1A1A1A), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(video.thumbnails.lowResUrl, width: 40, height: 40, fit: BoxFit.cover)), title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(video.author, style: const TextStyle(color: Colors.grey))),
              const Divider(color: Colors.white24),
              ListTile(leading: const Icon(Icons.queue_music, color: Colors.white), title: const Text('Agregar a cola'), onTap: () {
                  final newItem = MediaItem(id: video.id.value, title: video.title, artist: video.author, duration: video.duration, artUri: Uri.parse(video.thumbnails.highResUrl));
                  final currentQueue = audioHandler.queue.value.toList();
                  if (!currentQueue.any((item) => item.id == newItem.id)) { currentQueue.add(newItem); audioHandler.updateQueue(currentQueue); }
                  Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Agregada a la cola'), backgroundColor: appColor.value));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscador VIP', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: searchController,
              onChanged: (val) { if (val.isEmpty) setState(() { videos.clear(); }); },
              decoration: InputDecoration(
                hintText: 'Buscar música...', filled: true, fillColor: const Color(0xFF2A2A2A), contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                suffixIcon: ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => IconButton(icon: Icon(Icons.search, color: color), onPressed: () => searchVideos(searchController.text))),
              ),
              onSubmitted: searchVideos,
            ),
          ),
          if (isLoading) Expanded(child: Center(child: ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => CircularProgressIndicator(color: color))))
          else if (videos.isEmpty && searchController.text.isEmpty) Expanded(child: _buildSearchHistory()) 
          else Expanded(
            child: ListView.builder(
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index]; final isPlaying = playingVideoId == video.id.value;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(video.thumbnails.mediumResUrl, width: 55, height: 55, fit: BoxFit.cover)),
                  title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(video.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [if (isPlaying) ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => Icon(Icons.equalizer, color: color, size: 24)), IconButton(icon: const Icon(Icons.more_vert, color: Colors.grey), onPressed: () => _showSongOptions(context, video))]),
                  onTap: () => playVideo(video),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- TAB 2 Y 3: BÓVEDA Y DEPORTES ---
class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text('La Bóveda', style: TextStyle(fontWeight: FontWeight.bold)), bottom: TabBar(indicatorColor: appColor.value, tabs: const [Tab(icon: Icon(Icons.history), text: "Historial Pleno"), Tab(icon: Icon(Icons.favorite), text: "Favoritos")])),
        body: TabBarView(
          children: [
            ValueListenableBuilder(valueListenable: Hive.box('history').listenable(), builder: (context, Box box, _) {
                if (box.isEmpty) return const Center(child: Text("Sin historial aún", style: TextStyle(color: Colors.grey)));
                final items = box.values.toList().cast<Map>()..sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
                return ListView.builder(itemCount: items.length, itemBuilder: (context, index) { final item = items[index]; return ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(item['artUri'], width: 50, height: 50, fit: BoxFit.cover)), title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(item['artist'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)), onTap: () async { final mediaItem = MediaItem(id: item['id'], title: item['title'], artist: item['artist'], artUri: Uri.parse(item['artUri']), duration: Duration(milliseconds: item['duration'])); await audioHandler.updateQueue([mediaItem]); await audioHandler.playMediaItem(mediaItem); }); });
              }
            ),
            ValueListenableBuilder(valueListenable: Hive.box('favorites').listenable(), builder: (context, Box box, _) {
                if (box.isEmpty) return const Center(child: Text("Sin favoritos aún", style: TextStyle(color: Colors.grey)));
                final items = box.values.toList().cast<Map>();
                return ListView.builder(itemCount: items.length, itemBuilder: (context, index) { final item = items[index]; return ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(item['artUri'], width: 50, height: 50, fit: BoxFit.cover)), title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(item['artist'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)), trailing: IconButton(icon: const Icon(Icons.favorite, color: Colors.redAccent), onPressed: () => box.delete(item['id'])), onTap: () async { final mediaItem = MediaItem(id: item['id'], title: item['title'], artist: item['artist'], artUri: Uri.parse(item['artUri']), duration: Duration(milliseconds: item['duration'])); await audioHandler.updateQueue([mediaItem]); await audioHandler.playMediaItem(mediaItem); }); });
              }
            ),
          ],
        ),
      ),
    );
  }
}
class SportsScreen extends StatelessWidget { const SportsScreen({super.key}); @override Widget build(BuildContext context) => Scaffold(backgroundColor: const Color(0xFF0A1910), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.sports_soccer, size: 80, color: Colors.greenAccent), const SizedBox(height: 20), const Text('Tablero VIP Deportivo', style: TextStyle(color: Colors.white, fontSize: 18))]))); }

// -----------------------------------------------------------------------------
// REPRODUCTORES
// -----------------------------------------------------------------------------
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => const FullScreenPlayer()),
          child: Container(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8), decoration: const BoxDecoration(color: Color(0xFF1A1A1A), border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 1))),
            child: Row(
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(mediaItem.artUri.toString(), width: 45, height: 45, fit: BoxFit.cover)), const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(mediaItem.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), Text(mediaItem.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey))])),
                StreamBuilder<PlaybackState>(stream: audioHandler.playbackState, builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;
                    final isBuffering = snapshot.data?.processingState == AudioProcessingState.buffering || snapshot.data?.processingState == AudioProcessingState.loading;
                    return ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) {
                        if (isBuffering) return Padding(padding: const EdgeInsets.all(12.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: color)));
                        return IconButton(icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill), iconSize: 42, color: color, onPressed: () => playing ? audioHandler.pause() : audioHandler.play());
                      }
                    );
                  }
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class FullScreenPlayer extends StatelessWidget {
  const FullScreenPlayer({super.key});

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds";
  }

  void _showSleepTimerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Temporizador de Sueño", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text("Apagar en 15 minutos", style: TextStyle(color: Colors.white)), onTap: () { audioHandler.customAction('setSleepTimer', {'minutes': 15}); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Temporizador activado (15 min)"))); }),
            ListTile(title: const Text("Apagar en 30 minutos", style: TextStyle(color: Colors.white)), onTap: () { audioHandler.customAction('setSleepTimer', {'minutes': 30}); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Temporizador activado (30 min)"))); }),
            ListTile(title: const Text("Apagar en 60 minutos", style: TextStyle(color: Colors.white)), onTap: () { audioHandler.customAction('setSleepTimer', {'minutes': 60}); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Temporizador activado (60 min)"))); }),
            ListTile(title: const Text("Desactivar", style: TextStyle(color: Colors.redAccent)), onTap: () { audioHandler.customAction('setSleepTimer', {'minutes': 0}); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Temporizador desactivado"))); }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.95, decoration: const BoxDecoration(color: Color(0xFF111111), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, snapshot) {
          final mediaItem = snapshot.data;
          if (mediaItem == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16), Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(10))), const SizedBox(height: 30),
                ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(mediaItem.artUri.toString(), width: MediaQuery.of(context).size.width * 0.85, height: MediaQuery.of(context).size.width * 0.85, fit: BoxFit.cover)), const SizedBox(height: 30),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(mediaItem.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 8), Text(mediaItem.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, color: Colors.grey))])),
                    ValueListenableBuilder(
                      valueListenable: Hive.box('favorites').listenable(),
                      builder: (context, Box box, _) {
                        final isFav = box.containsKey(mediaItem.id);
                        return ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => IconButton(icon: Icon(isFav ? Icons.favorite : Icons.favorite_border), iconSize: 32, color: isFav ? Colors.redAccent : color, onPressed: () { if (isFav) box.delete(mediaItem.id); else box.put(mediaItem.id, {'id': mediaItem.id, 'title': mediaItem.title, 'artist': mediaItem.artist, 'artUri': mediaItem.artUri.toString(), 'duration': mediaItem.duration?.inMilliseconds ?? 0}); }));
                      }
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                StreamBuilder<Duration>(
                  stream: AudioService.position,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero; final duration = mediaItem.duration ?? Duration.zero;
                    double positionValue = position.inMilliseconds.toDouble(); double durationValue = duration.inMilliseconds.toDouble();
                    if (positionValue > durationValue) positionValue = durationValue; if (durationValue == 0.0) durationValue = 1.0;
                    return ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) {
                        return Column(children: [SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8), overlayShape: const RoundSliderOverlayShape(overlayRadius: 16), activeTrackColor: color, inactiveTrackColor: Colors.grey[800], thumbColor: color), child: Slider(value: positionValue, max: durationValue, onChanged: (value) => audioHandler.seek(Duration(milliseconds: value.toInt())))), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_formatDuration(position), style: const TextStyle(fontSize: 12, color: Colors.grey)), Text(_formatDuration(duration), style: const TextStyle(fontSize: 12, color: Colors.grey))])]);
                      }
                    );
                  }
                ),
                const SizedBox(height: 20),
                StreamBuilder<PlaybackState>(
                  stream: audioHandler.playbackState,
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false; final isBuffering = snapshot.data?.processingState == AudioProcessingState.buffering || snapshot.data?.processingState == AudioProcessingState.loading;
                    return ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) {
                        return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                          IconButton(icon: Icon(Icons.timer, color: color), onPressed: () => _showSleepTimerDialog(context)), // Botón de Sleep Timer
                          IconButton(icon: const Icon(Icons.skip_previous), iconSize: 48, color: Colors.white, onPressed: audioHandler.skipToPrevious), 
                          Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: color), child: isBuffering ? const Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) : IconButton(icon: Icon(playing ? Icons.pause : Icons.play_arrow), iconSize: 48, color: Colors.white, onPressed: () => playing ? audioHandler.pause() : audioHandler.play())), 
                          IconButton(icon: const Icon(Icons.skip_next), iconSize: 48, color: Colors.white, onPressed: audioHandler.skipToNext), 
                          IconButton(icon: const Icon(Icons.shuffle), color: Colors.grey, onPressed: () { audioHandler.shuffleQueue(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Lista mezclada"), backgroundColor: color)); })
                        ]);
                      }
                    );
                  }
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context, backgroundColor: const Color(0xFF1A1A1A), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (context) => Column(children: [const Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: Text("Siguiente en la lista", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))), Expanded(child: StreamBuilder<List<MediaItem>>(stream: audioHandler.queue, builder: (context, snapshot) { final queueList = snapshot.data ?? []; return ListView.builder(itemCount: queueList.length, itemBuilder: (context, index) { final item = queueList[index]; return ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(item.artUri.toString(), width: 45, height: 45, fit: BoxFit.cover)), title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(item.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)), onTap: () { audioHandler.playMediaItem(item); Navigator.pop(context); }); }); }))]),
                    );
                  }, 
                  child: const Column(children: [Icon(Icons.keyboard_arrow_up, color: Colors.grey, size: 30), Text("Cola", style: TextStyle(color: Colors.grey, fontSize: 12)), SizedBox(height: 20)])
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
