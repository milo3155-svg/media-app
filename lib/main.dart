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
      // Extraemos el stream de audio de forma segura en segundo plano dentro del Handler
      var manifest = await _yt.videos.streamsClient.getManifest(videoId);
      var audioStreamInfo = manifest.audioOnly.withHighestBitrate();

      await _player.setAudioSource(AudioSource.uri(audioStreamInfo.url));
      await _player.play();
    } catch (e) {
      debugPrint("Error crítico al extraer o reproducir el stream de YouTube: $e");
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
      androidNotificationChannelId: 'com.example.media_app.audio.master_v13',
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
  final _controller = TextEditingController();
  final _yt = YoutubeExplode();
  List<Video> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pedirPermisos();
  }

  Future<void> _pedirPermisos() async {
    await Permission.notification.request();
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final results = await _yt.search.search(query);
      setState(() {
        _results = results.toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error en búsqueda: $e");
      setState(() => _isLoading = false);
    }
  }

  void _onVideoSelected(Video video) {
    // Mandamos la orden inmediata al AudioHandler sin bloquear la UI
    audioHandler?.playMediaItem(MediaItem(
      id: video.id.value,
      title: video.title,
      artist: video.author,
      duration: video.duration,
      artUri: Uri.parse(video.thumbnails.highResUrl),
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cargando: ${video.title}'), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spotify-Killer Buscador VIP'),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Busca artista o canción...',
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.deepPurpleAccent),
                  onPressed: () => _search(_controller.text),
                ),
              ),
              onSubmitted: _search,
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final video = _results[index];
                    return ListTile(
                      leading: Image.network(
                        video.thumbnails.mediumResUrl,
                        width: 50,
                        fit: BoxFit.cover,
                      ),
                      title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(video.author, maxLines: 1),
                      trailing: const Icon(Icons.play_circle_fill, color: Colors.deepPurpleAccent, size: 32),
                      onTap: () => _onVideoSelected(video),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
