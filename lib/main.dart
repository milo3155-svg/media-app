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
      home: MainScreen(primaryColor: _primaryColor, onChangeColor: _changeThemeColor),
    );
  }
}

class MainScreen extends StatefulWidget {
  final Color primaryColor;
  final Function(Color) onChangeColor;
  const MainScreen({super.key, required this.primaryColor, required this.onChangeColor});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _favorites = [];
  
  // Variables para la lista de reproducción
  Map<String, dynamic>? _currentVideo;
  List<Map<String, dynamic>> _currentPlaylist = [];
  int _currentPlaylistIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
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

  void _playVideo(Map<String, dynamic> videoItem, {List<Map<String, dynamic>>? playlist, int? index}) {
    if (playlist != null) _currentPlaylist = playlist;
    if (index != null) _currentPlaylistIndex = index;

    setState(() {
      _currentVideo = videoItem;
    });
  }

  void _playNext() {
    if (_currentPlaylist.isNotEmpty && _currentPlaylistIndex < _currentPlaylist.length - 1) {
      _currentPlaylistIndex++;
      _playVideo(_currentPlaylist[_currentPlaylistIndex]);
    }
  }

  void _playPrevious() {
    if (_currentPlaylist.isNotEmpty && _currentPlaylistIndex > 0) {
      _currentPlaylistIndex--;
      _playVideo(_currentPlaylist[_currentPlaylistIndex]);
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

  bool _isFavorite(Map<String, dynamic> videoItem) {
    final videoId = videoItem['id'];
    return _favorites.any((v) => v['id'] == videoId);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      SearchTab(
        primaryColor: widget.primaryColor,
        onVideoSelected: (video, list, index) => _playVideo(video, playlist: list, index: index),
        currentVideoId: _currentVideo?['id'],
        onToggleFavorite: _toggleFavorite,
        isFavorite: _isFavorite,
      ),
      FavoritesTab(
        primaryColor: widget.primaryColor,
        favorites: _favorites,
        onVideoSelected: (video, list, index) => _playVideo(video, playlist: list, index: index),
        currentVideoId: _currentVideo?['id'],
        onToggleFavorite: _toggleFavorite,
      ),
    ];

    final bool hasNext = _currentPlaylist.isNotEmpty && _currentPlaylistIndex < _currentPlaylist.length - 1;
    final bool hasPrev = _currentPlaylist.isNotEmpty && _currentPlaylistIndex > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Media App' : 'Tus Favoritos'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1F1F1F),
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
          if (_currentVideo != null) 
            HybridPlayerWidget(
              videoData: _currentVideo!, 
              primaryColor: widget.primaryColor,
              onNext: hasNext ? _playNext : null,
              onPrevious: hasPrev ? _playPrevious : null,
              key: ValueKey(_currentVideo!['id']),
            ),
          Expanded(child: pages[_currentIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: widget.primaryColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF1F1F1F),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'),
          BottomNavigationBarItem(
            icon: Icon(
              _favorites.isNotEmpty ? Icons.favorite : Icons.favorite_border,
              color: _favorites.isNotEmpty ? Colors.redAccent : Colors.grey,
            ),
            label: 'Favoritos (${_favorites.length})',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 🎛️ EL REPRODUCTOR HÍBRIDO DEFINITIVO
// ==========================================
class HybridPlayerWidget extends StatefulWidget {
  final Map<String, dynamic> videoData;
  final Color primaryColor;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const HybridPlayerWidget({
    super.key, 
    required this.videoData, 
    required this.primaryColor,
    this.onNext,
    this.onPrevious,
  });

  @override
  State<HybridPlayerWidget> createState() => _HybridPlayerWidgetState();
}

class _HybridPlayerWidgetState extends State<HybridPlayerWidget> {
  VideoPlayerController? _videoController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<yt.MuxedStreamInfo> _videoStreams = [];
  String _audioUrl = '';
  
  bool _isLoading = true;
  bool _isAudioMode = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initExtract();
  }

  Future<void> _initExtract() async {
    try {
      final ytExplode = yt.YoutubeExplode();
      final manifest = await ytExplode.videos.streamsClient.getManifest(widget.videoData['id']);
      ytExplode.close();

      _audioUrl = manifest.audioOnly.withHighestBitrate().url.toString();
      _videoStreams = manifest.muxed.sortByVideoQuality().toList();
      
      if (_videoStreams.isNotEmpty) {
        _startVideo(_videoStreams.first.url.toString(), Duration.zero);
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
    await _audioPlayer.setAudioSource(
      AudioSource.uri(
        Uri.parse(_audioUrl),
        tag: MediaItem(
          id: widget.videoData['id'],
          title: widget.videoData['title'],
          artist: widget.videoData['uploader'],
          artUri: Uri.parse(widget.videoData['thumbnail']),
        ),
      ),
    );
    await _audioPlayer.seek(startAt);
    _audioPlayer.play();
    
    // Actualizar UI para el slider
    _audioPlayer.positionStream.listen((_) {
      if (mounted) setState(() {});
    });

    if (mounted) {
      setState(() {
        _isAudioMode = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _changeQuality(String option) async {
    setState(() => _isLoading = true);
    Duration currentPos = Duration.zero;
    if (_isAudioMode) {
      currentPos = _audioPlayer.position;
      await _audioPlayer.stop();
    } else if (_videoController != null) {
      currentPos = _videoController!.value.position;
      await _videoController!.pause();
    }

    if (option == 'audio_only') {
      await _startAudio(currentPos);
    } else {
      await _startVideo(option, currentPos);
    }
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
      return FullScreenPlayerPage(
        controller: _videoController!,
        primaryColor: widget.primaryColor,
      );
    })).then((_) {
      // Al salir de pantalla completa, forzamos regresar a vertical
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
    return Container(
      width: double.infinity,
      height: 240,
      color: Colors.black,
      child: _isLoading
          ? Center(child: CircularProgressIndicator(color: widget.primaryColor))
          : GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // CAPA 1: EL REPRODUCTOR VISUAL
                  if (_isAudioMode)
                    Image.network(
                      widget.videoData['thumbnail'],
                      fit: BoxFit.cover,
                      color: Colors.black54,
                      colorBlendMode: BlendMode.darken,
                    )
                  else if (_videoController != null && _videoController!.value.isInitialized)
                    Center(
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
                    ),

                  // CAPA 2: CONTROLES OVERLAY
                  if (_showControls)
                    Container(
                      color: Colors.black54, 
                      child: Stack(
                        children: [
                          // Menú de Calidad (Arriba a la derecha)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: PopupMenuButton<String>(
                              icon: const Icon(Icons.settings, color: Colors.white, size: 26),
                              color: const Color(0xFF1E1E1E),
                              onSelected: _changeQuality,
                              itemBuilder: (context) => [
                                ..._videoStreams.map((stream) => PopupMenuItem(
                                  value: stream.url.toString(),
                                  child: Text('${stream.videoQuality.name}p', style: const TextStyle(color: Colors.white)),
                                )),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'audio_only',
                                  child: Text('Audio only (2do plano)', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),

                          // Fila Central de Controles (Anterior, -10s, Play, +10s, Siguiente)
                          Align(
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.skip_previous, color: Colors.white),
                                  iconSize: 36,
                                  onPressed: widget.onPrevious,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.replay_10, color: Colors.white),
                                  iconSize: 32,
                                  onPressed: () => _seekRelative(-10),
                                ),
                                IconButton(
                                  iconSize: 64,
                                  icon: Icon(
                                    _isAudioMode 
                                        ? (_audioPlayer.playing ? Icons.pause_circle_filled : Icons.play_circle_fill)
                                        : ((_videoController?.value.isPlaying ?? false) ? Icons.pause_circle_filled : Icons.play_circle_fill),
                                    color: Colors.white,
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
                                IconButton(
                                  icon: const Icon(Icons.forward_10, color: Colors.white),
                                  iconSize: 32,
                                  onPressed: () => _seekRelative(10),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.skip_next, color: Colors.white),
                                  iconSize: 36,
                                  onPressed: widget.onNext,
                                ),
                              ],
                            ),
                          ),

                          // Barra de progreso y tiempos (Abajo)
                          Positioned(
                            bottom: 5,
                            left: 10,
                            right: 10,
                            child: Row(
                              children: [
                                Text(
                                  _formatDuration(_isAudioMode ? _audioPlayer.position : (_videoController?.value.position ?? Duration.zero)),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 2.0,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                                      activeTrackColor: widget.primaryColor,
                                      thumbColor: widget.primaryColor,
                                    ),
                                    child: Slider(
                                      min: 0.0,
                                      max: _isAudioMode 
                                          ? (_audioPlayer.duration?.inSeconds.toDouble() ?? 1.0)
                                          : (_videoController?.value.duration.inSeconds.toDouble() ?? 1.0),
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
                                Text(
                                  _formatDuration(_isAudioMode ? (_audioPlayer.duration ?? Duration.zero) : (_videoController?.value.duration ?? Duration.zero)),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                                if (!_isAudioMode)
                                  IconButton(
                                    icon: const Icon(Icons.fullscreen, color: Colors.white),
                                    onPressed: _toggleFullScreen,
                                  ),
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

// ==========================================
// PÁGINA DE PANTALLA COMPLETA
// ==========================================
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
    // Forzamos rotación a horizontal y escondemos barra de estado
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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

  void _seekRelative(int seconds) {
    final pos = widget.controller.value.position;
    widget.controller.seekTo(pos + Duration(seconds: seconds));
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
                      top: 10,
                      left: 10,
                      child: IconButton(
                        icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 32),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.replay_10, color: Colors.white),
                            iconSize: 42,
                            onPressed: () => _seekRelative(-10),
                          ),
                          IconButton(
                            iconSize: 80,
                            icon: Icon(
                              widget.controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                widget.controller.value.isPlaying ? widget.controller.pause() : widget.controller.play();
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.forward_10, color: Colors.white),
                            iconSize: 42,
                            onPressed: () => _seekRelative(10),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 30,
                      right: 30,
                      child: Row(
                        children: [
                          Text(
                            _formatDuration(widget.controller.value.position),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4.0,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                                activeTrackColor: widget.primaryColor,
                                thumbColor: widget.primaryColor,
                              ),
                              child: Slider(
                                min: 0.0,
                                max: widget.controller.value.duration.inSeconds.toDouble(),
                                value: widget.controller.value.position.inSeconds.toDouble().clamp(0.0, widget.controller.value.duration.inSeconds.toDouble()),
                                onChanged: (val) => widget.controller.seekTo(Duration(seconds: val.toInt())),
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(widget.controller.value.duration),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
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

// ==========================================
// TABS DE BÚSQUEDA Y FAVORITOS
// ==========================================
class SearchTab extends StatefulWidget {
  final Color primaryColor;
  final Function(Map<String, dynamic>, List<Map<String, dynamic>>, int) onVideoSelected;
  final String? currentVideoId;
  final Function(Map<String, dynamic>) onToggleFavorite;
  final bool Function(Map<String, dynamic>) isFavorite;

  const SearchTab({
    super.key, 
    required this.primaryColor, 
    required this.onVideoSelected, 
    this.currentVideoId, 
    required this.onToggleFavorite, 
    required this.isFavorite
  });

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchVideos('goles de messi resumen');
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar música, videos, resúmenes...',
              prefixIcon: Icon(Icons.search, color: widget.primaryColor),
              suffixIcon: IconButton(icon: Icon(Icons.send, color: widget.primaryColor), onPressed: () => _searchVideos(_searchController.text)),
              filled: true,
              fillColor: const Color(0xFF2C2C2C),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0), borderSide: BorderSide.none),
            ),
            onSubmitted: _searchVideos,
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: widget.primaryColor))
              : _videos.isEmpty
                  ? const Center(child: Text('No se encontraron resultados'))
                  : ListView.builder(
                      itemCount: _videos.length,
                      itemBuilder: (context, index) {
                        final video = _videos[index];
                        final isSelected = widget.currentVideoId == video['id'];
                        final isFav = widget.isFavorite(video);
                        return Card(
                          color: const Color(0xFF1E1E1E),
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.network(video['thumbnail'], width: 70, height: 50, fit: BoxFit.cover),
                            ),
                            title: Text(video['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text(video['uploader'], style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : Colors.grey, size: 20), onPressed: () => widget.onToggleFavorite(video)),
                                IconButton(icon: Icon(isSelected ? Icons.equalizer : Icons.play_arrow_rounded, color: widget.primaryColor, size: 34), onPressed: () => widget.onVideoSelected(video, _videos, index)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class FavoritesTab extends StatelessWidget {
  final Color primaryColor;
  final List<Map<String, dynamic>> favorites;
  final Function(Map<String, dynamic>, List<Map<String, dynamic>>, int) onVideoSelected;
  final String? currentVideoId;
  final Function(Map<String, dynamic>) onToggleFavorite;

  const FavoritesTab({super.key, required this.primaryColor, required this.favorites, required this.onVideoSelected, this.currentVideoId, required this.onToggleFavorite});

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) return const Center(child: Text('Aún no has agregado favoritos.', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final video = favorites[index];
        final isSelected = currentVideoId == video['id'];
        return Card(
          color: const Color(0xFF1E1E1E),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(video['thumbnail'], width: 70, height: 50, fit: BoxFit.cover),
            ),
            title: Text(video['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(video['uploader'], style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.favorite, color: Colors.redAccent, size: 20), onPressed: () => onToggleFavorite(video)),
                IconButton(icon: Icon(isSelected ? Icons.equalizer : Icons.play_arrow_rounded, color: primaryColor, size: 34), onPressed: () => onVideoSelected(video, favorites, index)),
              ],
            ),
          ),
        );
      },
    );
  }
}
