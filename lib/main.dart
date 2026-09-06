import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

// Instancia global del AudioHandler
late MyAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.media_app.audio_master_v23',
      androidNotificationChannelName: 'Spotify Killer Buscador',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
      androidNotificationIcon: 'drawable/ic_notification',
    ),
  );

  runApp(const MediaApp());
}

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
    // 1. Actualizamos la interfaz de inmediato
    mediaItem.add(item);
    
    try {
      // 2. Avisamos al sistema que estamos cargando el audio
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.loading,
      ));

      // 3. Detenemos el reproductor para limpiar la canción anterior
      await _player.stop();

      final videoId = item.id;
      debugPrint("Obteniendo manifiesto para: $videoId");
      var manifest = await _yt.videos.streamsClient.getManifest(videoId);
      
      // EL CAMBIO CLAVE: Tomamos la mejor calidad sin importar el formato
      var streamInfo = manifest.audioOnly.withHighestBitrate();
      debugPrint("URL obtenida: ${streamInfo.url}");

      await _player.setAudioSource(
        AudioSource.uri(
          streamInfo.url,
          tag: item,
        ),
      );

      await _player.play();
    } catch (e) {
      debugPrint("Error crítico en playMediaItem: $e");
      // En caso de error, el reproductor simplemente se quedará pausado
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
        SnackBar(content: Text('Error al buscar: $e'), backgroundColor: Colors.red),
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

  @override
  void dispose() {
    yt.close();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spotify Killer VIP'),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Buscar artista o canción...',
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
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
          const SizedBox(height: 10),
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
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(video.thumbnails.mediumResUrl, width: 50, height: 50, fit: BoxFit.cover),
                    ),
                    title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(video.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
                    trailing: Icon(
                      isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      color: Colors.deepPurpleAccent,
                      size: 32,
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

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            // Fase 2 (Pantalla completa)
          },
          child: Container(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF111111),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, -5))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
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
                const SizedBox(height: 8),
                StreamBuilder<Duration>(
                  stream: AudioService.position,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = mediaItem.duration ?? Duration.zero;
                    
                    double positionValue = position.inMilliseconds.toDouble();
                    double durationValue = duration.inMilliseconds.toDouble();
                    
                    if (positionValue > durationValue) positionValue = durationValue;
                    if (durationValue == 0.0) durationValue = 1.0;

                    return Row(
                      children: [
                        Text(_formatDuration(position), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
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
                        ),
                        Text(_formatDuration(duration), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    );
                  }
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
