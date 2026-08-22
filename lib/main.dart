import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';

class SimpleAudioHandler extends BaseAudioHandler {
  Function()? onPlayCommand;
  Function()? onPauseCommand;
  Function(Duration)? onSeekCommand;
  Function()? onRewindCommand;
  Function()? onFastForwardCommand;

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
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF121212), primaryColor: Colors.purpleAccent, colorScheme: const ColorScheme.dark(primary: Colors.purpleAccent)),
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
  final TextEditingController _searchController = TextEditingController();
  final YoutubeExplode _yt = YoutubeExplode();
  final AudioPlayer _audioPlayer = AudioPlayer();
  VideoPlayerController? _videoController;
  final ValueNotifier<int> _uiUpdater = ValueNotifier(0);
  
  bool _isSearching = false, _globalVideoMode = true, _isLoadingSearch = false, _isLoadingTop = false, _isPlaying = false, _isLoadingMedia = false, _hasActiveMedia = false, _isRepeating = false;
  List<Video> _searchResults = [], _topResults = [];
  Video? _currentMedia;
  Duration _duration = Duration.zero, _position = Duration.zero;
  MediaItem? _lastMediaItem;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _audioPlayer.setAudioContext(const AudioContext(android: AudioContextAndroid(stayAwake: true, contentType: AndroidContentType.music, usageType: AndroidUsageType.media, audioFocus: AndroidAudioFocus.gain)));
    _initAppServices();
    _audioPlayer.onDurationChanged.listen((d) { if (mounted) { setState(() => _duration = d); _syncSystemState(); _uiUpdater.value++; } });
    _audioPlayer.onPositionChanged.listen((p) { if (mounted) { setState(() => _position = p); _uiUpdater.value++; } });
    _loadTopContent("Global");
  }

  Future<void> _initAppServices() async {
    await Permission.notification.request();
    globalAudioHandler = await AudioService.init(
        builder: () => SimpleAudioHandler(),
        config: const AudioServiceConfig(androidNotificationChannelId: 'com.milo.media_app.channel.audio', androidNotificationChannelName: 'Reproductor Multimedia', androidNotificationOngoing: true, androidStopForegroundOnPause: true, androidNotificationIcon: 'mipmap/ic_launcher'));
    globalAudioHandler?.onPlayCommand = _togglePlayPause;
    globalAudioHandler?.onPauseCommand = _togglePlayPause;
  }

  void _syncSystemState() {
    if (_currentMedia == null || globalAudioHandler == null) return;
    globalAudioHandler!.mediaItem.add(MediaItem(id: _currentMedia!.id.value, title: _currentMedia!.title, artist: _currentMedia!.author, artUri: Uri.parse(_currentMedia!.thumbnails.highResUrl), duration: _duration));
    globalAudioHandler!.playbackState.add(PlaybackState(processingState: _isLoadingMedia ? AudioProcessingState.buffering : AudioProcessingState.ready, controls: [MediaControl.rewind, _isPlaying ? MediaControl.pause : MediaControl.play, MediaControl.fastForward], playing: _isPlaying, updatePosition: _position));
  }

  Future<void> _playMedia(Video video) async {
    setState(() { _currentMedia = video; _hasActiveMedia = true; _isPlaying = false; _isLoadingMedia = true; });
    try {
      await _audioPlayer.stop(); await _audioPlayer.release(); if (_videoController != null) await _videoController!.dispose();
      var manifest = await _yt.videos.streamsClient.getManifest(video.id);
      var streamInfo = manifest.muxed.withHighestBitrate();
      if (_globalVideoMode) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(streamInfo.url.toString()));
        await _videoController!.initialize(); await _videoController!.play();
        setState(() { _isLoadingMedia = false; _isPlaying = true; });
      } else {
        await _audioPlayer.play(UrlSource(streamInfo.url.toString()));
        setState(() { _isPlaying = true; _isLoadingMedia = false; });
      }
      _syncSystemState();
    } catch (e) {
      if (mounted) { setState(() { _isLoadingMedia = false; _isPlaying = false; }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al cargar video.'))); }
    }
  }

  void _togglePlayPause() {
    setState(() => _isPlaying = !_isPlaying);
    _globalVideoMode ? (_isPlaying ? _videoController?.play() : _videoController?.pause()) : (_isPlaying ? _audioPlayer.resume() : _audioPlayer.pause());
    _syncSystemState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Media App")),
      body: Center(child: _hasActiveMedia ? const Text("Reproduciendo...") : const Text("Selecciona un video")),
      floatingActionButton: FloatingActionButton(onPressed: () => _playMedia(_topResults.first), child: const Icon(Icons.play_arrow)),
    );
  }
  @override
  void dispose() { _yt.close(); _audioPlayer.dispose(); _videoController?.dispose(); super.dispose(); }
}
