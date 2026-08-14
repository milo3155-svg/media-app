import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.mediaapp.channel.audio',
    androidNotificationChannelName: 'Reproducción 2do Plano',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'drawable/ic_notification',
  );
  
  runApp(const MediaApp());
}

class MediaApp extends StatefulWidget {
  const MediaApp({super.key});

  @override
  State<MediaApp> createState() => _MediaAppState();
}

class _MediaAppState extends State<MediaApp> {
  Color _primaryColor = Colors.purpleAccent;

  @override
  void initState() {
    super.initState();
    _loadSavedColor();
    _requestInitialPermissions();
  }

  Future<void> _requestInitialPermissions() async {
    if (Platform.isAndroid) {
      await [Permission.notification].request();
    }
  }

  Future<void> _loadSavedColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('theme_color');
    if (colorValue != null) setState(() => _primaryColor = Color(colorValue));
  }

  Future<void> _changeThemeColor(Color color) async {
    setState(() => _primaryColor = color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_color', color.value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: _primaryColor,
        colorScheme: ColorScheme.dark(primary: _primaryColor),
      ),
      home: HomeScreen(primaryColor: _primaryColor, onChangeColor: _changeThemeColor),
    );
  }
}

// ==========================================
// 🏠 PANTALLA PRINCIPAL (EXPLORADOR)
// ==========================================
class HomeScreen extends StatefulWidget {
  final Color primaryColor;
  final Function(Color) onChangeColor;
  
  const HomeScreen({super.key, required this.primaryColor, required this.onChangeColor});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _favorites = [];

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _searchVideos('Lo más escuchado 2026');
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final favString = prefs.getString('saved_favorites');
    if (favString != null) {
      setState(() {
        _favorites = List<Map<String, dynamic>>.from(json.decode(favString));
      });
    }
  }

  Future<void> _saveLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_favorites', json.encode(_favorites));
  }

  Future<void> _searchVideos(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final ytExplode = yt.YoutubeExplode();
      final searchResults = await ytExplode.search.search(query);
      ytExplode.close();

      if (mounted) {
        setState(() {
          _videos = searchResults.map((video) => {
            'id': video.id.value,
            'title': video.title,
            'uploader': video.author,
            'thumbnail': video.thumbnails.highResUrl,
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _videos = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleFavorite(Map<String, dynamic> videoItem) {
    final videoId = videoItem['id'];
    setState(() {
      final exists = _favorites.any((v) => v['id'] == videoId);
      if (exists) {
        _favorites.removeWhere((v) => v['id'] == videoId);
      } else {
        _favorites.add(videoItem);
      }
    });
    _saveLocalData();
  }

  void _openPlayer(Map<String, dynamic> video, List<Map<String, dynamic>> playlist, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          primaryColor: widget.primaryColor,
          initialVideo: video,
          playlist: playlist,
          initialIndex: index,
          favorites: _favorites,
          onToggleFavorite: _toggleFavorite,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final activeList = _currentIndex == 0 ? _videos : _favorites;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Explorar' : 'Mis Favoritos', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        actions: [
          PopupMenuButton<Color>(
            icon: Icon(Icons.palette_rounded, color: widget.primaryColor),
            onSelected: widget.onChangeColor,
            itemBuilder: (context) => [
              const PopupMenuItem(value: Colors.purpleAccent, child: Text('Púrpura Neón')),
              const PopupMenuItem(value: Colors.blueAccent, child: Text('Azul Eléctrico')),
              const PopupMenuItem(value: Colors.tealAccent, child: Text('Verde Esmeralda')),
              const PopupMenuItem(value: Colors.redAccent, child: Text('Rojo Carmesí')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_currentIndex == 0)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar canciones, artistas, videos...',
                  prefixIcon: Icon(Icons.search, color: widget.primaryColor),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.send, color: widget.primaryColor), 
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus(); // FIX DE TECLADO
                      _searchVideos(_searchController.text);
                    }
                  ),
                  filled: true,
                  fillColor: const Color(0xFF2C2C2C),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0), borderSide: BorderSide.none),
                ),
                onSubmitted: (val) {
                  FocusManager.instance.primaryFocus?.unfocus(); // FIX DE TECLADO
                  _searchVideos(val);
                },
              ),
            ),
          
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: widget.primaryColor))
                : activeList.isEmpty
                    ? Center(child: Text(_currentIndex == 0 ? 'No hay resultados.' : 'Tu lista de favoritos está vacía.', style: const TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: activeList.length,
                        itemBuilder: (context, index) {
                          final video = activeList[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.network(video['thumbnail'], width: 80, height: 60, fit: BoxFit.cover),
                            ),
                            title: Text(video['title'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(video['uploader'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            onTap: () => _openPlayer(video, activeList, index),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: widget.primaryColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF1F1F1F),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explorar'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favoritos'),
        ],
      ),
    );
  }
}

// ==========================================
// 🎥 PANTALLA DEL REPRODUCTOR DEDICADO
// ==========================================
class PlayerScreen extends StatefulWidget {
  final Color primaryColor;
  final Map<String, dynamic> initialVideo;
  final List<Map<String, dynamic>> playlist;
  final int initialIndex;
  final List<Map<String, dynamic>> favorites;
  final Function(Map<String, dynamic>) onToggleFavorite;

  const PlayerScreen({
    super.key,
    required this.primaryColor,
    required this.initialVideo,
    required this.playlist,
    required this.initialIndex,
    required this.favorites,
    required this.onToggleFavorite,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late Map<String, dynamic> _currentVideo;
  late int _currentIndex;
  
  VideoPlayerController? _videoController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<yt.MuxedStreamInfo> _videoStreams = [];
  String _audioFallbackUrl = '';
  
  bool _isLoading = true;
  bool _isAudioMode = false;
  String _currentQualityLabel = 'Alta Calidad';

  @override
  void initState() {
    super.initState();
    _currentVideo = widget.initialVideo;
    _currentIndex = widget.initialIndex;
    _initExtract();
  }

  Future<void> _initExtract() async {
    setState(() => _isLoading = true);
    try {
      final ytExplode = yt.YoutubeExplode();
      final manifest = await ytExplode.videos.streamsClient.getManifest(_currentVideo['id']);
      ytExplode.close();

      _videoStreams = manifest.muxed.sortByVideoQuality().toList();
      
      if (_videoStreams.isNotEmpty) {
        final audioStreams = manifest.audioOnly.where((s) => s.container.name == 'mp4' || s.audioCodec.contains('mp4a'));
        if (audioStreams.isNotEmpty) {
          _audioFallbackUrl = audioStreams.withHighestBitrate().url.toString();
        } else {
          _audioFallbackUrl = manifest.audioOnly.withHighestBitrate().url.toString(); 
        }
        
        if (_isAudioMode) {
          await _startAudio(Duration.zero);
        } else {
          _currentQualityLabel = '${_videoStreams.first.videoQuality.name}p';
          await _startVideo(_videoStreams.first.url.toString(), Duration.zero);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startVideo(String url, Duration startAt) async {
    final oldController = _videoController;
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    
    await _videoController!.initialize();
    await _videoController!.seekTo(startAt);
    _videoController!.play();
    
    _videoController!.addListener(() {
      if (mounted) setState(() {});
    });

    if (mounted) {
      setState(() {
        _isAudioMode = false;
        _isLoading = false;
      });
    }
    oldController?.dispose();
  }

  Future<void> _startAudio(Duration startAt) async {
    try {
      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(_audioFallbackUrl),
          tag: MediaItem(
            id: _currentVideo['id'],
            title: _currentVideo['title'],
            artist: _currentVideo['uploader'],
            artUri: Uri.parse(_currentVideo['thumbnail']),
          ),
        ),
      );
      await _audioPlayer.seek(startAt);
      _audioPlayer.play();
      
      _audioPlayer.positionStream.listen((_) {
        if (mounted) setState(() {});
      });

      if (mounted) {
        setState(() {
          _isAudioMode = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error audio: $e");
    }
  }

  void _changeVideo(int newIndex) {
    if (newIndex >= 0 && newIndex < widget.playlist.length) {
      _videoController?.pause();
      _audioPlayer.stop();
      setState(() {
        _currentIndex = newIndex;
        _currentVideo = widget.playlist[newIndex];
      });
      _initExtract();
    }
  }

  Future<void> _changeMode(String modeUrl, String label) async {
    Navigator.pop(context); 
    setState(() => _isLoading = true);
    
    Duration currentPos = Duration.zero;
    if (_isAudioMode) {
      currentPos = _audioPlayer.position;
      await _audioPlayer.stop();
    } else if (_videoController != null) {
      currentPos = _videoController!.value.position;
      await _videoController!.pause();
    }

    setState(() => _currentQualityLabel = label);

    if (modeUrl == 'audio_only') {
      await _startAudio(currentPos);
    } else {
      await _startVideo(modeUrl, currentPos);
    }
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Calidad de Reproducción', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              ..._videoStreams.map((stream) => ListTile(
                leading: const Icon(Icons.hd, color: Colors.white70),
                title: Text('Video ${stream.videoQuality.name}p', style: const TextStyle(color: Colors.white)),
                onTap: () => _changeMode(stream.url.toString(), '${stream.videoQuality.name}p'),
              )),
              const Divider(color: Colors.grey),
              ListTile(
                leading: Icon(Icons.headphones, color: widget.primaryColor),
                title: Text('Solo Audio (Permite 2do Plano)', style: TextStyle(color: widget.primaryColor, fontWeight: FontWeight.bold)),
                onTap: () => _changeMode('audio_only', 'Solo Audio'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _seekRelative(int seconds) {
    if (_isAudioMode) {
      final pos = _audioPlayer.position;
      _audioPlayer.seek(pos + Duration(seconds: seconds));
    } else if (_videoController != null) {
      final pos = _videoController!.value.position;
      _videoController!.seekTo(pos + Duration(seconds: seconds));
    }
  }

  void _toggleFullScreen() {
    if (_videoController == null || _isAudioMode) return;
    
    Navigator.of(context).push(MaterialPageRoute(builder: (context) {
      return FullScreenPlayerPage(controller: _videoController!, primaryColor: widget.primaryColor);
    })).then((_) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isFav = widget.favorites.any((v) => v['id'] == _currentVideo['id']);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down, size: 32), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _showSettingsBottomSheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black,
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: widget.primaryColor))
                      : _isAudioMode
                          ? Image.network(_currentVideo['thumbnail'], fit: BoxFit.cover, color: Colors.black54, colorBlendMode: BlendMode.darken)
                          : (_videoController != null && _videoController!.value.isInitialized)
                              ? VideoPlayer(_videoController!)
                              : const SizedBox(),
                ),
              ),
              
              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_currentVideo['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(_currentVideo['uploader'], style: const TextStyle(fontSize: 14, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text('Calidad actual: $_currentQualityLabel', style: TextStyle(fontSize: 12, color: widget.primaryColor)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : Colors.grey, size: 28),
                      onPressed: () {
                        widget.onToggleFavorite(_currentVideo);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Text(_formatDuration(_isAudioMode ? _audioPlayer.position : (_videoController?.value.position ?? Duration.zero)), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3.0,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                          activeTrackColor: widget.primaryColor,
                          thumbColor: widget.primaryColor,
                        ),
                        child: Slider(
                          min: 0.0,
                          max: _isAudioMode ? (_audioPlayer.duration?.inSeconds.toDouble() ?? 1.0) : (_videoController?.value.duration.inSeconds.toDouble() ?? 1.0),
                          value: _isAudioMode 
                              ? _audioPlayer.position.inSeconds.toDouble().clamp(0.0, _audioPlayer.duration?.inSeconds.toDouble() ?? 1.0)
                              : (_videoController?.value.position.inSeconds.toDouble().clamp(0.0, _videoController?.value.duration.inSeconds.toDouble() ?? 1.0) ?? 0.0),
                          onChanged: (val) {
                            final newPos = Duration(seconds: val.toInt());
                            _isAudioMode ? _audioPlayer.seek(newPos) : _videoController?.seekTo(newPos);
                          },
                        ),
                      ),
                    ),
                    Text(_formatDuration(_isAudioMode ? (_audioPlayer.duration ?? Duration.zero) : (_videoController?.value.duration ?? Duration.zero)), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(icon: const Icon(Icons.skip_previous), color: Colors.white, iconSize: 36, onPressed: () => _changeVideo(_currentIndex - 1)),
                  IconButton(icon: const Icon(Icons.replay_10), color: Colors.white70, iconSize: 32, onPressed: () => _seekRelative(-10)),
                  Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: widget.primaryColor.withOpacity(0.2)),
                    child: IconButton(
                      iconSize: 64,
                      icon: Icon(
                        _isAudioMode 
                            ? (_audioPlayer.playing ? Icons.pause : Icons.play_arrow)
                            : ((_videoController?.value.isPlaying ?? false) ? Icons.pause : Icons.play_arrow),
                        color: widget.primaryColor,
                      ),
                      onPressed: () {
                        setState(() {
                          if (_isAudioMode) {
                            _audioPlayer.playing ? _audioPlayer.pause() : _audioPlayer.play();
                          } else {
                            (_videoController?.value.isPlaying ?? false) ? _videoController!.pause() : _videoController!.play();
                          }
                        });
                      },
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.forward_10), color: Colors.white70, iconSize: 32, onPressed: () => _seekRelative(10)),
                  IconButton(icon: const Icon(Icons.skip_next), color: Colors.white, iconSize: 36, onPressed: () => _changeVideo(_currentIndex + 1)),
                ],
              ),
              const SizedBox(height: 10),
              if (!_isAudioMode)
                Center(
                  child: IconButton(
                    icon: const Icon(Icons.fullscreen, color: Colors.white, size: 32),
                    onPressed: _toggleFullScreen,
                  ),
                ),
            ],
          ),

          DraggableScrollableSheet(
            initialChildSize: 0.12,
            minChildSize: 0.12,
            maxChildSize: 0.6,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, -2))],
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(10)),
                    ),
                    const Text('Siguiente en la lista', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: widget.playlist.length,
                        itemBuilder: (context, index) {
                          final video = widget.playlist[index];
                          final isPlaying = index == _currentIndex;
                          return ListTile(
                            tileColor: isPlaying ? widget.primaryColor.withOpacity(0.1) : Colors.transparent,
                            leading: ClipRRect(borderRadius: BorderRadius.circular(8.0), child: Image.network(video['thumbnail'], width: 60, height: 45, fit: BoxFit.cover)),
                            title: Text(video['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isPlaying ? widget.primaryColor : Colors.white, fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                            subtitle: Text(video['uploader'], style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            trailing: isPlaying ? Icon(Icons.equalizer, color: widget.primaryColor) : null,
                            onTap: () => _changeVideo(index),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class FullScreenPlayerPage extends StatefulWidget {
  final VideoPlayerController controller;
  final Color primaryColor;

  const FullScreenPlayerPage({super.key, required this.controller, required this.primaryColor});

  @override
  State<FullScreenPlayerPage> createState() => _FullScreenPlayerPageState();
}

class _FullScreenPlayerPageState extends State<FullScreenPlayerPage> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    widget.controller.addListener(_updateState);
  }

  void _updateState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateState);
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: widget.controller.value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),
            if (_showControls)
              Container(
                color: Colors.black54,
                child: Stack(
                  children: [
                    Positioned(
                      top: 10, left: 10,
                      child: IconButton(icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 32), onPressed: () => Navigator.pop(context)),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(icon: const Icon(Icons.replay_10, color: Colors.white), iconSize: 42, onPressed: () => widget.controller.seekTo(widget.controller.value.position - const Duration(seconds: 10))),
                          IconButton(
                            iconSize: 80,
                            icon: Icon(widget.controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white),
                            onPressed: () => setState(() => widget.controller.value.isPlaying ? widget.controller.pause() : widget.controller.play()),
                          ),
                          IconButton(icon: const Icon(Icons.forward_10, color: Colors.white), iconSize: 42, onPressed: () => widget.controller.seekTo(widget.controller.value.position + const Duration(seconds: 10))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
