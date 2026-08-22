import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';

class SimpleAudioHandler extends BaseAudioHandler {
  Function()? onPlayCommand, onPauseCommand, onRewindCommand, onFastForwardCommand;
  Function(Duration)? onSeekCommand;

  @override
  Future<void> play() async => onPlayCommand?.call();
  @override
  Future<void> pause() async => onPauseCommand?.call();
  @override
  Future<void> seek(Duration position) async => onSeekCommand?.call(position);
  @override
  Future<void> rewind() async => onRewindCommand?.call();
  @override
  Future<void> fastForward() async => onFastForwardCommand?.call();
}

SimpleAudioHandler? globalAudioHandler;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MediaApp());
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF121212), primaryColor: Colors.purpleAccent),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final YoutubeExplode _yt = YoutubeExplode();
  final AudioPlayer _audioPlayer = AudioPlayer();
  VideoPlayerController? _videoController;
  bool _isPlaying = false, _globalVideoMode = true;
  List<Video> _topResults = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initServices();
    _loadTopContent("Global");
  }

  Future<void> _initServices() async {
    await Permission.notification.request();
    globalAudioHandler = await AudioService.init(
      builder: () => SimpleAudioHandler(),
      config: const AudioServiceConfig(androidNotificationChannelId: 'com.media.app', androidNotificationChannelName: 'Reproductor', androidNotificationIcon: 'mipmap/ic_launcher'),
    );
  }

  Future<void> _loadTopContent(String category) async {
    try {
      var list = await _yt.search.search("Top musica $category");
      if (mounted) setState(() => _topResults = list.take(10).toList());
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _playMedia(Video video) async {
    try {
      await _audioPlayer.stop();
      var manifest = await _yt.videos.streamsClient.getManifest(video.id);
      var stream = manifest.muxed.withHighestBitrate();
      if (_globalVideoMode) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(stream.url.toString()));
        await _videoController!.initialize();
        await _videoController!.play();
      } else {
        await _audioPlayer.play(UrlSource(stream.url.toString()));
      }
      setState(() => _isPlaying = true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de formato')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Media App")),
      body: ListView.builder(
        itemCount: _topResults.length,
        itemBuilder: (context, i) => ListTile(title: Text(_topResults[i].title), onTap: () => _playMedia(_topResults[i])),
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _togglePlayPause(), child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow)),
    );
  }

  void _togglePlayPause() {
    setState(() => _isPlaying = !_isPlaying);
    _globalVideoMode ? (_isPlaying ? _videoController?.play() : _videoController?.pause()) : (_isPlaying ? _audioPlayer.resume() : _audioPlayer.pause());
  }

  @override
  void dispose() { _yt.close(); _audioPlayer.dispose(); _videoController?.dispose(); super.dispose(); }
}
