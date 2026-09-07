import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'dart:math' as math;

// Instancia global del AudioHandler
late MyAudioHandler audioHandler;

// Controlador global para la calidad del audio (Ahorro de datos vs HD)
final ValueNotifier<bool> isHDMode = ValueNotifier<bool>(true);

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
// COMPONENTE: EL LOGO "EL OÍDO QUE TODO LO ESCUCHA"
// -----------------------------------------------------------------------------
class ConspiracyLogo extends StatelessWidget {
  final double size;
  final Color color;

  const ConspiracyLogo({
    super.key, 
    this.size = 100.0, 
    this.color = Colors.deepPurpleAccent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _EarKeyholePainter(color: color),
      ),
    );
  }
}

class _EarKeyholePainter extends CustomPainter {
  final Color color;
  _EarKeyholePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final earPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;

    final earPath = Path();
    earPath.addArc(
      Rect.fromCenter(center: center, width: size.width * 0.9, height: size.height * 0.9),
      -math.pi / 2.5, 
      math.pi * 1.6,
    );
    earPath.quadraticBezierTo(
      size.width * 0.8, size.height * 1.1, 
      size.width * 0.5, size.height * 0.9,
    );
    canvas.drawPath(earPath, earPaint);

    final keyholePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(center.dx, center.dy - size.height * 0.05), size.width * 0.12, keyholePaint);

    final keyholeBase = Path();
    keyholeBase.moveTo(center.dx - size.width * 0.08, center.dy - size.height * 0.05);
    keyholeBase.lineTo(center.dx + size.width * 0.08, center.dy - size.height * 0.05);
    keyholeBase.lineTo(center.dx + size.width * 0.15, center.dy + size.height * 0.25);
    keyholeBase.lineTo(center.dx - size.width * 0.15, center.dy + size.height * 0.25);
    keyholeBase.close();

    canvas.drawPath(keyholeBase, keyholePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
// -----------------------------------------------------------------------------

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  final _yt = YoutubeExplode();

  MyAudioHandler() {
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
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
      ));
    });

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
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
      final nextItem = queueList[currentIndex + 1];
      await playMediaItem(nextItem);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final queueList = queue.value;
    if (queueList.isEmpty) return;

    final currentItem = mediaItem.value;
    final currentIndex = queueList.indexWhere((item) => item.id == currentItem?.id);

    if (currentIndex > 0) {
      final previousItem = queueList[currentIndex - 1];
      await playMediaItem(previousItem);
    }
  }

  @override
  Future<void> playMediaItem(MediaItem item) async {
    mediaItem.add(item);
    
    try {
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.loading,
      ));

      await _player.stop();

      final videoId = item.id;
      var manifest = await _yt.videos.streamsClient.getManifest(videoId);
      
      StreamInfo streamInfo;
      
      if (manifest.muxed.isNotEmpty) {
        if (isHDMode.value) {
          streamInfo = manifest.muxed.withHighestBitrate();
        } else {
          streamInfo = manifest.muxed.reduce((a, b) => a.bitrate.bitsPerSecond < b.bitrate.bitsPerSecond ? a : b);
        }
      } else if (manifest.audioOnly.isNotEmpty) {
        if (isHDMode.value) {
          streamInfo = manifest.audioOnly.withHighestBitrate();
        } else {
          streamInfo = manifest.audioOnly.reduce((a, b) => a.bitrate.bitsPerSecond < b.bitrate.bitsPerSecond ? a : b);
        }
      } else {
        throw Exception("No hay audios disponibles");
      }

      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(streamInfo.url.toString()),
          tag: item,
          headers: const {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36',
          },
        ),
      );

      await _player.play();
    } catch (e) {
      debugPrint("Error crítico: $e");
      String errorMsg = e.toString().replaceAll('\n', ' ');
      if (errorMsg.length > 60) errorMsg = errorMsg.substring(0, 60);
      mediaItem.add(item.copyWith(artist: "🛑 $errorMsg"));
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
      ));
    }
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    queue.add(newQueue);
  }

  void shuffleQueue() {
    final currentQueue = queue.value.toList();
    currentQueue.shuffle();
    queue.add(currentQueue);
  }
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spotify Killer VIP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        primaryColor: Colors.deepPurpleAccent,
      ),
      home: const SearchScreen(),
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
  final yt = YoutubeExplode();
  List<Video> videos = [];
  bool isLoading = false;
  String? playingVideoId;
  String selectedFilter = 'Todos'; // Estado para el chip seleccionado

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.notification.request();
  }

  void searchVideos(String query) async {
    if (query.isEmpty) return;
    setState(() => isLoading = true);
    try {
      var result = await yt.search.search(query);
      setState(() {
        videos = result.toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void playVideo(Video video) async {
    setState(() => playingVideoId = video.id.value);

    final queueList = videos.map((v) => MediaItem(
      id: v.id.value,
      title: v.title,
      artist: v.author,
      duration: v.duration,
      artUri: Uri.parse(v.thumbnails.highResUrl),
    )).toList();

    await audioHandler.updateQueue(queueList);

    final selectedItem = queueList.firstWhere((item) => item.id == video.id.value);
    await audioHandler.playMediaItem(selectedItem);
  }

  // NUEVO: Menú de opciones por canción (3 puntitos)
  void _showSongOptions(BuildContext context, Video video) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(video.thumbnails.lowResUrl, width: 40, height: 40, fit: BoxFit.cover),
                ),
                title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(video.author, style: const TextStyle(color: Colors.grey)),
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.queue_music, color: Colors.white),
                title: const Text('Agregar a cola de reproducción'),
                onTap: () {
                  // Agrega el item al final de la cola actual
                  final newItem = MediaItem(
                    id: video.id.value,
                    title: video.title,
                    artist: video.author,
                    duration: video.duration,
                    artUri: Uri.parse(video.thumbnails.highResUrl),
                  );
                  final currentQueue = audioHandler.queue.value.toList();
                  if (!currentQueue.any((item) => item.id == newItem.id)) {
                    currentQueue.add(newItem);
                    audioHandler.updateQueue(currentQueue);
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agregada a la cola'), backgroundColor: Colors.deepPurpleAccent));
                },
              ),
              ListTile(
                leading: const Icon(Icons.favorite_border, color: Colors.white),
                title: const Text('Agregar a listas / Favoritos'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Próximamente en Fase 2')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.white),
                title: const Text('Descargar para escuchar offline'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Próximamente en Fase 2')));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    yt.close();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // NUEVO: Menú Lateral (Drawer)
      drawer: Drawer(
        backgroundColor: const Color(0xFF1A1A1A),
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF111111),
                border: Border(bottom: BorderSide(color: Colors.deepPurpleAccent, width: 2)),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ConspiracyLogo(size: 60), // EL LOGO EN ACCIÓN
                    SizedBox(height: 15),
                    Text('VIP ACCESS', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 3)),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.white),
              title: const Text('Historial', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.library_music, color: Colors.white),
              title: const Text('Mis Listas & Favoritos', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.download_done, color: Colors.white),
              title: const Text('Gestor de Descargas', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.sports_soccer, color: Colors.deepPurpleAccent),
              title: const Text('Zona Deportiva (Beta)', style: TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pop(context),
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title: const Text('Configuración', style: TextStyle(color: Colors.grey)),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('Spotify Killer', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Buscar música, artistas...',
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.deepPurpleAccent),
                  onPressed: () => searchVideos(searchController.text),
                ),
              ),
              onSubmitted: searchVideos,
            ),
          ),
          
          // NUEVO: Chips de Filtros Visuales
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: ['Todos', 'Podcasts', 'Música de Moda', 'Rock 90s', 'Electrónica'].map((filter) {
                final isSelected = selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(filter, style: TextStyle(color: isSelected ? Colors.white : Colors.grey)),
                    selected: isSelected,
                    selectedColor: Colors.deepPurpleAccent,
                    backgroundColor: const Color(0xFF2A2A2A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (bool selected) {
                      setState(() => selectedFilter = filter);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)))
          else
            Expanded(
              child: ListView.builder(
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  final video = videos[index];
                  final isPlaying = playingVideoId == video.id.value;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(video.thumbnails.mediumResUrl, width: 55, height: 55, fit: BoxFit.cover),
                    ),
                    title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(video.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    // NUEVO: Agrupamos el ícono de Play y los 3 puntitos
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPlaying)
                           const Icon(Icons.equalizer, color: Colors.deepPurpleAccent, size: 24),
                        IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          onPressed: () => _showSongOptions(context, video),
                        ),
                      ],
                    ),
                    onTap: () => playVideo(video),
                  );
                },
              ),
            ),
          const MiniPlayer(),
        ],
      ),
    );
  }
}

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
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const FullScreenPlayer(),
            );
          },
          child: Container(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    mediaItem.artUri.toString(),
                    width: 45,
                    height: 45,
                    fit: BoxFit.cover,
                  ),
                ),
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
                    final state = snapshot.data;
                    final playing = state?.playing ?? false;
                    final isBuffering = state?.processingState == AudioProcessingState.buffering || state?.processingState == AudioProcessingState.loading;
                    
                    if (isBuffering) {
                      return const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurpleAccent)),
                      );
                    }

                    return IconButton(
                      icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
                      iconSize: 42,
                      color: Colors.deepPurpleAccent,
                      onPressed: () {
                        if (playing) {
                          audioHandler.pause();
                        } else {
                          audioHandler.play();
                        }
                      },
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Text("Siguiente en la lista", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
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
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(item.artUri.toString(), width: 45, height: 45, fit: BoxFit.cover),
                        ),
                        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(item.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
                        onTap: () {
                          audioHandler.playMediaItem(item);
                          Navigator.pop(context); 
                        },
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
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
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
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 40),
                
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    mediaItem.artUri.toString(),
                    width: MediaQuery.of(context).size.width * 0.85,
                    height: MediaQuery.of(context).size.width * 0.85,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 40),
                
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    mediaItem.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    mediaItem.artist ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
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

                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                            activeTrackColor: Colors.deepPurpleAccent,
                            inactiveTrackColor: Colors.grey[800],
                            thumbColor: Colors.deepPurpleAccent,
                          ),
                          child: Slider(
                            value: positionValue,
                            max: durationValue,
                            onChanged: (value) {
                              audioHandler.seek(Duration(milliseconds: value.toInt()));
                            },
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(position), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(_formatDuration(duration), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    );
                  }
                ),
                const SizedBox(height: 20),
                
                StreamBuilder<PlaybackState>(
                  stream: audioHandler.playbackState,
                  builder: (context, snapshot) {
                    final state = snapshot.data;
                    final playing = state?.playing ?? false;
                    final isBuffering = state?.processingState == AudioProcessingState.buffering || state?.processingState == AudioProcessingState.loading;
                    
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: isHDMode,
                          builder: (context, isHD, _) {
                            return IconButton(
                              icon: Icon(isHD ? Icons.high_quality : Icons.data_saver_on),
                              color: isHD ? Colors.deepPurpleAccent : Colors.grey,
                              onPressed: () {
                                isHDMode.value = !isHD;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isHD ? "Ahorro de datos activado" : "Audio HD Activado (Se aplicará en la siguiente canción)"),
                                    backgroundColor: isHD ? Colors.orange : Colors.deepPurpleAccent,
                                  )
                                );
                              },
                            );
                          }
                        ),
                        
                        IconButton(
                          icon: const Icon(Icons.skip_previous),
                          iconSize: 48,
                          color: Colors.white,
                          onPressed: audioHandler.skipToPrevious,
                        ),
                        
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.deepPurpleAccent,
                          ),
                          child: isBuffering 
                            ? const Padding(
                                padding: EdgeInsets.all(20.0),
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                              )
                            : IconButton(
                                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                                iconSize: 48,
                                color: Colors.white,
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
                          icon: const Icon(Icons.skip_next),
                          iconSize: 48,
                          color: Colors.white,
                          onPressed: audioHandler.skipToNext,
                        ),
                        
                        IconButton(
                          icon: const Icon(Icons.shuffle),
                          color: Colors.grey,
                          onPressed: () {
                            audioHandler.shuffleQueue();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Lista mezclada"), backgroundColor: Colors.deepPurpleAccent)
                            );
                          },
                        ),
                      ],
                    );
                  }
                ),
                
                const Spacer(),
                
                GestureDetector(
                  onTap: () => _showQueueList(context),
                  child: const Column(
                    children: [
                      Icon(Icons.keyboard_arrow_up, color: Colors.grey, size: 30),
                      Text("Cola de reproducción", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
