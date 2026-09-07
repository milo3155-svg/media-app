import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'dart:math' as math;

// Controladores Globales
late MyAudioHandler audioHandler;
final ValueNotifier<bool> isHDMode = ValueNotifier<bool>(true);

// NUEVO: Cerebro de color global (Tema dinámico)
final ValueNotifier<Color> appColor = ValueNotifier<Color>(Colors.deepPurpleAccent);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.media_app.audio_master_v23',
      androidNotificationChannelName: 'Spotify Killer VIP',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
      androidNotificationIcon: 'drawable/ic_notification',
    ),
  );

  runApp(const MediaApp());
}

// -----------------------------------------------------------------------------
// EL LOGO CONSPIRANOICO V2: "El Ojo de Osiris" con texto oculto
// -----------------------------------------------------------------------------
class ConspiracyLogo extends StatelessWidget {
  final double size;
  final Color color;

  const ConspiracyLogo({
    super.key, 
    this.size = 150.0, 
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OsirisEyePainter(color: color),
      ),
    );
  }
}

class _OsirisEyePainter extends CustomPainter {
  final Color color;
  _OsirisEyePainter({required this.color});

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

    // La Pirámide (Botón Play)
    final playPath = Path();
    playPath.moveTo(w * 0.15, h * 0.15); 
    playPath.lineTo(w * 0.15, h * 0.85); 
    playPath.lineTo(w * 0.90, h * 0.50); 
    playPath.close();
    canvas.drawPath(playPath, paint);

    // El Ojo
    final eyePath = Path();
    final eyeLeft = w * 0.25;
    final eyeRight = w * 0.65;
    final eyeY = h * 0.50;
    final eyeCenterX = w * 0.45;
    
    eyePath.moveTo(eyeLeft, eyeY);
    eyePath.quadraticBezierTo(eyeCenterX, h * 0.30, eyeRight, eyeY);
    eyePath.quadraticBezierTo(eyeCenterX, h * 0.75, eyeLeft, eyeY);
    canvas.drawPath(eyePath, paint);

    // La Frecuencia (Iris)
    final wavePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03;
      
    canvas.drawCircle(Offset(eyeCenterX, h * 0.50), w * 0.10, wavePaint);
    canvas.drawCircle(Offset(eyeCenterX, h * 0.50), w * 0.04, wavePaint);
    canvas.drawLine(Offset(eyeCenterX - w * 0.15, h * 0.50), Offset(eyeCenterX + w * 0.15, h * 0.50), wavePaint);

    // NUEVO: Texto Críptico Inyectado en el Vector
    final textSpan = TextSpan(
      text: 'O S I R I S   4 3 2',
      style: TextStyle(
        color: color,
        fontSize: w * 0.12,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
        fontFamily: 'Courier', // Estilo de archivo clasificado
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    // Lo posicionamos justo debajo de la pirámide
    textPainter.paint(canvas, Offset(w * 0.5 - textPainter.width / 2, h * 0.95));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; // Cambia al cambiar color
}
// -----------------------------------------------------------------------------

// MOTOR DE AUDIO (MANTENIDO INTACTO)
class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  final _yt = YoutubeExplode();

  MyAudioHandler() {
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
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
      if (state == ProcessingState.completed) skipToNext();
    });
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    final queueList = queue.value;
    if (queueList.isEmpty) return;
    final currentItem = mediaItem.value;
    final currentIndex = queueList.indexWhere((item) => item.id == currentItem?.id);
    if (currentIndex != -1 && currentIndex < queueList.length - 1) {
      await playMediaItem(queueList[currentIndex + 1]);
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

  @override
  Future<void> playMediaItem(MediaItem item) async {
    mediaItem.add(item);
    try {
      playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.loading));
      await _player.stop();

      final videoId = item.id;
      var manifest = await _yt.videos.streamsClient.getManifest(videoId);
      StreamInfo streamInfo;
      
      if (manifest.muxed.isNotEmpty) {
        streamInfo = isHDMode.value ? manifest.muxed.withHighestBitrate() : manifest.muxed.reduce((a, b) => a.bitrate.bitsPerSecond < b.bitrate.bitsPerSecond ? a : b);
      } else if (manifest.audioOnly.isNotEmpty) {
        streamInfo = isHDMode.value ? manifest.audioOnly.withHighestBitrate() : manifest.audioOnly.reduce((a, b) => a.bitrate.bitsPerSecond < b.bitrate.bitsPerSecond ? a : b);
      } else {
        throw Exception("No hay audios disponibles");
      }

      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(streamInfo.url.toString()), tag: item,
          headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'},
        ),
      );
      await _player.play();
    } catch (e) {
      debugPrint("Error crítico: $e");
      String errorMsg = e.toString().replaceAll('\n', ' ');
      if (errorMsg.length > 60) errorMsg = errorMsg.substring(0, 60);
      mediaItem.add(item.copyWith(artist: "🛑 $errorMsg"));
      playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.error, playing: false));
    }
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async { queue.add(newQueue); }
  void shuffleQueue() {
    final currentQueue = queue.value.toList();
    currentQueue.shuffle();
    queue.add(currentQueue);
  }
}

// -----------------------------------------------------------------------------
// ARQUITECTURA PRINCIPAL
// -----------------------------------------------------------------------------
class MediaApp extends StatelessWidget {
  const MediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuchamos los cambios del color global
    return ValueListenableBuilder<Color>(
      valueListenable: appColor,
      builder: (context, color, _) {
        return MaterialApp(
          title: 'Spotify Killer VIP',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF1A1A1A),
            primaryColor: color, // Color dinámico
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              backgroundColor: const Color(0xFF111111),
              selectedItemColor: color, // Iconos dinámicos
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              elevation: 20,
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: color),
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

// --- TAB 0: INICIO (CON SELECTOR DE COLOR) ---
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lista de temas VIP disponibles
    final List<Color> themeColors = [
      Colors.deepPurpleAccent,
      Colors.redAccent,
      Colors.greenAccent,
      Colors.amberAccent,
      Colors.blueAccent,
    ];

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ValueListenableBuilder<Color>(
              valueListenable: appColor,
              builder: (context, color, _) {
                return ConspiracyLogo(size: 180, color: color); 
              }
            ),
            const SizedBox(height: 50), // Espacio para el texto del logo
            
            // NUEVO: Selector de colores
            const Text("PROTOCOLOS DE COLOR", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 2)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: themeColors.map((colorOption) {
                return GestureDetector(
                  onTap: () {
                    appColor.value = colorOption; // Cambia el color global mágicamente
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: colorOption,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 2),
                      boxShadow: [
                        BoxShadow(color: colorOption.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)
                      ]
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// --- TAB 1: BUSCADOR ---
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final searchController = TextEditingController();
  final yt = YoutubeExplode();
  List<Video> videos = [];
  bool isLoading = false;
  String? playingVideoId;
  String selectedFilter = 'Todos';

  @override
  void initState() {
    super.initState();
    Permission.notification.request();
  }

  void searchVideos(String query) async {
    if (query.isEmpty) return;
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

  void _showSongOptions(BuildContext context, Video video) {
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(video.thumbnails.lowResUrl, width: 40, height: 40, fit: BoxFit.cover)),
                title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(video.author, style: const TextStyle(color: Colors.grey)),
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.queue_music, color: Colors.white), title: const Text('Agregar a cola'),
                onTap: () {
                  final newItem = MediaItem(id: video.id.value, title: video.title, artist: video.author, duration: video.duration, artUri: Uri.parse(video.thumbnails.highResUrl));
                  final currentQueue = audioHandler.queue.value.toList();
                  if (!currentQueue.any((item) => item.id == newItem.id)) { currentQueue.add(newItem); audioHandler.updateQueue(currentQueue); }
                  Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Agregada a la cola'), backgroundColor: appColor.value));
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.white), title: const Text('Descargar para escuchar offline'),
                onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Próximamente en Fase 2'))); },
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
      appBar: AppBar(title: const Text('Buscador VIP')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Buscar música, artistas...', filled: true, fillColor: const Color(0xFF2A2A2A),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                suffixIcon: ValueListenableBuilder<Color>(
                  valueListenable: appColor,
                  builder: (context, color, _) => IconButton(icon: Icon(Icons.search, color: color), onPressed: () => searchVideos(searchController.text)),
                ),
              ),
              onSubmitted: searchVideos,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ValueListenableBuilder<Color>(
              valueListenable: appColor,
              builder: (context, color, _) {
                return Row(
                  children: ['Todos', 'Podcasts', 'Música de Moda', 'Rock 90s'].map((filter) {
                    final isSelected = selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(filter, style: TextStyle(color: isSelected ? Colors.white : Colors.grey)),
                        selected: isSelected, selectedColor: color, backgroundColor: const Color(0xFF2A2A2A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onSelected: (bool selected) => setState(() => selectedFilter = filter),
                      ),
                    );
                  }).toList(),
                );
              }
            ),
          ),
          if (isLoading) Expanded(child: Center(child: ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => CircularProgressIndicator(color: color))))
          else Expanded(
            child: ListView.builder(
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                final isPlaying = playingVideoId == video.id.value;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(video.thumbnails.mediumResUrl, width: 55, height: 55, fit: BoxFit.cover)),
                  title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(video.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPlaying) ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => Icon(Icons.equalizer, color: color, size: 24)),
                      IconButton(icon: const Icon(Icons.more_vert, color: Colors.grey), onPressed: () => _showSongOptions(context, video)),
                    ],
                  ),
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
class VaultScreen extends StatelessWidget { const VaultScreen({super.key}); @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.lock_outline, size: 80, color: Colors.grey), SizedBox(height: 20), Text('Tu Bóveda Privada', style: TextStyle(color: Colors.white, fontSize: 18))]))); }
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
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
            decoration: const BoxDecoration(color: Color(0xFF1A1A1A), border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 1))),
            child: Row(
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(mediaItem.artUri.toString(), width: 45, height: 45, fit: BoxFit.cover)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(mediaItem.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(mediaItem.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                StreamBuilder<PlaybackState>(
                  stream: audioHandler.playbackState,
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;
                    final isBuffering = snapshot.data?.processingState == AudioProcessingState.buffering || snapshot.data?.processingState == AudioProcessingState.loading;
                    return ValueListenableBuilder<Color>(
                      valueListenable: appColor,
                      builder: (context, color, _) {
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

  void _showQueueList(BuildContext context) {
    // ... [Mismo código de Queue List]
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Column(
          children: [
            const Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: Text("Siguiente en la lista", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
            Expanded(
              child: StreamBuilder<List<MediaItem>>(
                stream: audioHandler.queue,
                builder: (context, snapshot) {
                  final queueList = snapshot.data ?? [];
                  return ListView.builder(
                    itemCount: queueList.length,
                    itemBuilder: (context, index) {
                      final item = queueList[index];
                      return ListTile(
                        leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(item.artUri.toString(), width: 45, height: 45, fit: BoxFit.cover)),
                        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(item.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
                        onTap: () { audioHandler.playMediaItem(item); Navigator.pop(context); },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: const BoxDecoration(color: Color(0xFF111111), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
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
                const SizedBox(height: 16),
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 40),
                ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(mediaItem.artUri.toString(), width: MediaQuery.of(context).size.width * 0.85, height: MediaQuery.of(context).size.width * 0.85, fit: BoxFit.cover)),
                const SizedBox(height: 40),
                
                // NUEVO: Fila con el título y el BOTÓN DE FAVORITOS (Corazón)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mediaItem.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 8),
                          Text(mediaItem.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, color: Colors.grey)),
                        ],
                      ),
                    ),
                    ValueListenableBuilder<Color>(
                      valueListenable: appColor,
                      builder: (context, color, _) {
                        return IconButton(
                          icon: const Icon(Icons.favorite_border),
                          iconSize: 32,
                          color: color,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Agregado a Favoritos'), backgroundColor: color));
                          },
                        );
                      }
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                StreamBuilder<Duration>(
                  stream: AudioService.position,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = mediaItem.duration ?? Duration.zero;
                    double positionValue = position.inMilliseconds.toDouble();
                    double durationValue = duration.inMilliseconds.toDouble();
                    if (positionValue > durationValue) positionValue = durationValue;
                    if (durationValue == 0.0) durationValue = 1.0;
                    return ValueListenableBuilder<Color>(
                      valueListenable: appColor,
                      builder: (context, color, _) {
                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8), overlayShape: const RoundSliderOverlayShape(overlayRadius: 16), activeTrackColor: color, inactiveTrackColor: Colors.grey[800], thumbColor: color),
                              child: Slider(value: positionValue, max: durationValue, onChanged: (value) => audioHandler.seek(Duration(milliseconds: value.toInt()))),
                            ),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_formatDuration(position), style: const TextStyle(fontSize: 12, color: Colors.grey)), Text(_formatDuration(duration), style: const TextStyle(fontSize: 12, color: Colors.grey))]),
                          ],
                        );
                      }
                    );
                  }
                ),
                const SizedBox(height: 20),
                StreamBuilder<PlaybackState>(
                  stream: audioHandler.playbackState,
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;
                    final isBuffering = snapshot.data?.processingState == AudioProcessingState.buffering || snapshot.data?.processingState == AudioProcessingState.loading;
                    return ValueListenableBuilder<Color>(
                      valueListenable: appColor,
                      builder: (context, color, _) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ValueListenableBuilder<bool>(
                              valueListenable: isHDMode,
                              builder: (context, isHD, _) {
                                return IconButton(
                                  icon: Icon(isHD ? Icons.high_quality : Icons.data_saver_on), color: isHD ? color : Colors.grey,
                                  onPressed: () { isHDMode.value = !isHD; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isHD ? "Ahorro de datos" : "Audio HD"), backgroundColor: color)); },
                                );
                              }
                            ),
                            IconButton(icon: const Icon(Icons.skip_previous), iconSize: 48, color: Colors.white, onPressed: audioHandler.skipToPrevious),
                            Container(
                              width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                              child: isBuffering ? const Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) : IconButton(icon: Icon(playing ? Icons.pause : Icons.play_arrow), iconSize: 48, color: Colors.white, onPressed: () => playing ? audioHandler.pause() : audioHandler.play()),
                            ),
                            IconButton(icon: const Icon(Icons.skip_next), iconSize: 48, color: Colors.white, onPressed: audioHandler.skipToNext),
                            IconButton(icon: const Icon(Icons.shuffle), color: Colors.grey, onPressed: () { audioHandler.shuffleQueue(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Lista mezclada"), backgroundColor: color)); }),
                          ],
                        );
                      }
                    );
                  }
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showQueueList(context),
                  child: const Column(children: [Icon(Icons.keyboard_arrow_up, color: Colors.grey, size: 30), Text("Cola de reproducción", style: TextStyle(color: Colors.grey, fontSize: 12)), SizedBox(height: 20)]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
