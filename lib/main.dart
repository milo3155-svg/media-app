import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';

// 1. EL NUEVO CEREBRO (Conectado a un reproductor nativo)
class MyAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();

  MyAudioHandler() {
    // Sincronizar el estado del reproductor con la notificación de la pantalla de bloqueo
    _player.playbackEventStream.listen((event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          if (playing) MediaControl.pause else MediaControl.play,
        ],
        systemActions: const {MediaAction.seek},
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
  Future<void> playMediaItem(MediaItem item) async {
    mediaItem.add(item);
    // Recuperamos la URL pura del audio que inyectamos desde la interfaz
    final url = item.extras?['url'] as String?;
    if (url != null) {
      await _player.setUrl(url);
      play();
    }
  }
}

AudioHandler? audioHandler;

void main() {
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

  List<Video> videos = [];
  bool isLoading = false;
  String? playingVideoId;

  @override
  void initState() {
    super.initState();
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

  Future<void> playAudio(Video video) async {
    setState(() {
      playingVideoId = video.id.value;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Extrayendo audio puro...')),
    );

    try {
      // LA EXTRACCIÓN: Sacamos la URL directa del audio con la mejor calidad
      final manifest = await yt.videos.streamsClient.getManifest(video.id);
      final audioStream = manifest.audioOnly.withHighestBitrate();

      if (audioHandler != null) {
        audioHandler!.playMediaItem(MediaItem(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          artUri: Uri.parse(video.thumbnails.mediumResUrl),
          // Inyectamos la URL pura para que el reproductor nativo la lea
          extras: {'url': audioStream.url.toString()},
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al extraer audio: $e')),
      );
    }
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
