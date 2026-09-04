import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';

class MyAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();

  MyAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);
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
      // 👇 FIX 1: Android exige saber qué botones mostrar en la notificación pequeña
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
  Future<void> skipToNext() async {
    debugPrint("Siguiente");
  }

  @override
  Future<void> skipToPrevious() async {
    debugPrint("Anterior");
  }

  @override
  Future<void> playMediaItem(MediaItem item) async {
    mediaItem.add(item);
    final url = item.extras?['url'] as String?;

    if (url != null) {
      try {
        await _player.setAudioSource(AudioSource.uri(
          Uri.parse(url),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'
          },
        ));
        
        _broadcastState(_player.playbackEvent); 
        play();
      } catch (e) {
        playbackState.add(playbackState.value.copyWith(
          errorMessage: "Error: $e",
          processingState: AudioProcessingState.error,
        ));
      }
    }
  }
}

late AudioHandler audioHandler;

Future<void> initAudioService() async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.media_app.channel.audio',
      androidNotificationChannelName: 'Reproductor VIP',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
      androidNotificationIcon: 'mipmap/ic_launcher', 
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initAudioService();
  runApp(const MediaApp());
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spotify-Killer',
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

  Future<void> searchVideos(String query) async {
    if (query.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final results = await yt.search.getVideos(query);
      if (!mounted) return;
      setState(() => videos = results.take(15).toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> playAudio(Video video) async {
    setState(() => playingVideoId = video.id.value);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cargando pista segura...')));

    try {
      final manifest = await yt.videos.streamsClient.getManifest(video.id);
      final muxedStreams = manifest.muxed.where((stream) => stream.container.name == 'mp4');
      if (muxedStreams.isEmpty) throw Exception("Sin formato compatible");
      
      audioHandler.playMediaItem(MediaItem(
        id: video.id.value,
        title: video.title,
        artist: video.author,
        // 👇 FIX 2: Resolucion media para evitar que Android cancele la tarjeta por error de imagen
        artUri: Uri.parse(video.thumbnails.mediumResUrl),
        extras: {'url': muxedStreams.first.url.toString()},
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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
      appBar: AppBar(title: const Text('Spotify-Killer'), backgroundColor: const Color(0xFF1A1A1A)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Buscar...',
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixIcon: IconButton(icon: const Icon(Icons.search, color: Colors.deepPurpleAccent), onPressed: () => searchVideos(searchController.text)),
              ),
              onSubmitted: searchVideos,
            ),
          ),
          if (isLoading) const LinearProgressIndicator(color: Colors.deepPurpleAccent),
          Expanded(
            child: ListView.builder(
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                final isPlaying = playingVideoId == video.id.value;
                return ListTile(
                  leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(video.thumbnails.mediumResUrl, width: 60, height: 45, fit: BoxFit.cover)),
                  title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: isPlaying ? Colors.deepPurpleAccent : Colors.white)),
                  subtitle: Text(video.author, style: const TextStyle(color: Colors.grey)),
                  trailing: IconButton(icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.deepPurpleAccent, size: 32), onPressed: () => playAudio(video)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
