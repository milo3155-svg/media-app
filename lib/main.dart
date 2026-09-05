import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  final _yt = YoutubeExplode();

  MyAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);
    _player.playerStateStream.listen((state) {
      playbackState.add(playbackState.value.copyWith(playing: state.playing));
    });
  }

  void _broadcastState(PlaybackEvent event) {
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
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async => debugPrint("Siguiente");

  @override
  Future<void> skipToPrevious() async => debugPrint("Anterior");

  @override
  Future<void> playMediaItem(MediaItem item) async {
    mediaItem.add(item);
    final videoId = item.id;
    
    try {
      debugPrint("Obteniendo manifiesto con contenedores MP4 para: $videoId");
      
      // Obtenemos el manifiesto completo y filtramos por streams MP4 usando 'muxed'
      var manifest = await _yt.videos.streamsClient.getManifest(videoId);
      var streamInfo = manifest.muxed
          .where((stream) => stream.container.name == 'mp4')
          .withHighestBitrate();

      final uriString = streamInfo.url.toString();
      debugPrint("URL obtenida: $uriString");

      // Configuramos la fuente con el User-Agent de navegador para burlar el bloqueo de YouTube
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(uriString),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'
          },
        ),
      );
      
      await _player.play();
      debugPrint("¡Reproducción real iniciada con éxito!");
    } catch (e) {
      debugPrint("❌ Error crítico en playMediaItem: $e");
    }
  }
}

AudioHandler? audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.media_app.audio.master_v23',
      androidNotificationChannelName: 'Spotify-Killer Buscador',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
      androidNotificationIcon: 'drawable/ic_notification',
    ),
  );

  runApp(const MediaApp());
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spotify-Killer VIP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
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
  String playingVideoId = '';

  @override
  void initState() {
    super.initState();
    _pedirPermisos();
  }

  Future<void> _pedirPermisos() async {
    await Permission.notification.request();
  }

  Future<void> searchVideos(String query) async {
    if (query.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final results = await yt.search.search(query);
      if (!mounted) return;
      setState(() {
        videos = results.toList();
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void playVideo(Video video) {
    setState(() => playingVideoId = video.id.value);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cargando pista segura: ${video.title}'), duration: const Duration(seconds: 2)),
    );

    audioHandler?.playMediaItem(MediaItem(
      id: video.id.value,
      title: video.title,
      artist: video.author,
      artUri: Uri.parse(video.thumbnails.highResUrl),
    ));
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
        title: const Text('Spotify-Killer Buscador VIP'),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Busca artista o canción...',
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.deepPurpleAccent),
                  onPressed: () => searchVideos(searchController.text),
                ),
              ),
              onSubmitted: searchVideos,
            ),
          ),
          const SizedBox(height: 6),
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
                    subtitle: Text(video.author, maxLines: 1, style: const TextStyle(color: Colors.grey)),
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
        ],
      ),
    );
  }
}
