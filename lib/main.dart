import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';

// 1. EL CEREBRO DE SEGUNDO PLANO
class MyAudioHandler extends BaseAudioHandler {
  MyAudioHandler() {
    playbackState.add(playbackState.value.copyWith(
      controls: [MediaControl.pause, MediaControl.play],
      systemActions: const {MediaAction.seek},
      processingState: AudioProcessingState.ready,
      playing: false,
    ));
  }

  @override
  Future<void> play() async {
    playbackState.add(playbackState.value.copyWith(playing: true));
  }

  @override
  Future<void> pause() async {
    playbackState.add(playbackState.value.copyWith(playing: false));
  }

  @override
  Future<void> playMediaItem(MediaItem item) async {
    mediaItem.add(item);
    play();
  }
}

// AHORA ES OPCIONAL PARA QUE NO ROMPA LA APP SI FALLA
AudioHandler? audioHandler;

void main() {
  // ARRANCAMOS LA INTERFAZ VISUAL PRIMERO QUE NADA (¡Adios pantalla negra!)
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MediaApp());
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Youtube Streamer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController searchController = TextEditingController();
  final YoutubeExplode yt = YoutubeExplode();
  YoutubePlayerController? _playerController;

  List<Video> videos = [];
  bool isLoading = false;
  String? playingVideoId;

  @override
  void initState() {
    super.initState();
    // INICIAMOS EL SERVICIO VIP EN SEGUNDO PLANO, SIN BLOQUEAR LA APP
    _initAudioService();
  }

  Future<void> _initAudioService() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      audioHandler = await AudioService.init(
        builder: () => MyAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.media_app.channel.audio',
          androidNotificationChannelName: 'Reproductor VIP',
          androidNotificationOngoing: true,
        ),
      );
    } catch (e) {
      // Si Android rechaza la notificación, la app sobrevive y sigue funcionando de forma normal.
      debugPrint('Error de AudioService: $e');
    }
  }

  Future<void> searchVideos(String query) async {
    if (query.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final results = await yt.search.getVideos(query);
      if (!mounted) return;
      setState(() {
        videos = results.take(15).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al buscar: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void playAudio(Video video) {
    setState(() {
      playingVideoId = video.id.value;
      
      if (_playerController == null) {
        _playerController = YoutubePlayerController(
          params: const YoutubePlayerParams(
            showControls: false, 
            mute: false,
            showFullscreenButton: false,
            loop: false,
          ),
        );
      }
      
      _playerController!.loadVideoById(videoId: video.id.value);
      
      // SOLO ENVIAMOS DATOS SI EL SERVICIO VIP LOGRÓ INICIARSE
      if (audioHandler != null) {
        audioHandler!.playMediaItem(MediaItem(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          artUri: Uri.parse(video.thumbnails.mediumResUrl),
        ));
      }
    });
  }

  @override
  void dispose() {
    yt.close();
    _playerController?.close();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Youtube Direct Streamer'),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Buscar video o música...',
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
          if (isLoading)
            const LinearProgressIndicator(color: Colors.deepPurpleAccent),
          
          if (_playerController != null)
            SizedBox(
              height: 1,
              width: 1,
              child: YoutubePlayer(
                controller: _playerController!,
              ),
            ),

          Expanded(
            child: ListView.builder(
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                final isPlaying = playingVideoId == video.id.value;

                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      video.thumbnails.mediumResUrl,
                      width: 60,
                      height: 45,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(
                    video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isPlaying ? Colors.deepPurpleAccent : Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    video.author,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      color: Colors.deepPurpleAccent,
                      size: 32,
                    ),
                    onPressed: () => playAudio(video),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
