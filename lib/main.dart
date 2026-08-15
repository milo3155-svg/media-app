import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io'; // <--- ¡AQUÍ ESTÁ LA LÍNEA MÁGICA!
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==========================================
// 🌍 INICIALIZACIÓN
// ==========================================
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

  // ESTADO GLOBAL DEL REPRODUCTOR MÁGICO
  bool _isPlayerVisible = false;
  bool _isPlayerExpanded = false;
  
  Map<String, dynamic>? _currentVideo;
  List<Map<String, dynamic>> _playlist = [];
  int _currentIndex = -1;
  
  bool _isAudioMode = false;
  bool _isLoadingMedia = false;
  String _errorMessage = '';
  String _currentQualityLabel = 'Cargando...';

  VideoPlayerController? _videoController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadSavedColor();
    _requestInitialPermissions();
  }

  Future<void> _requestInitialPermissions() async {
    if (Platform.isAndroid) await [Permission.notification].request();
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

  // ==========================================
  // 🧠 EL MOTOR MULTIMEDIA GLOBAL
  // ==========================================
  Future<void> _playMedia(Map<String, dynamic> video, List<Map<String, dynamic>> playlist, int index) async {
    FocusManager.instance.primaryFocus?.unfocus(); 
    setState(() {
      _currentVideo = video;
      _playlist = playlist;
      _currentIndex = index;
      _isPlayerVisible = true;
      _isPlayerExpanded = true;
      _isLoadingMedia = true;
      _errorMessage = '';
    });

    try {
      final ytExplode = yt.YoutubeExplode();
      
      yt.StreamManifest? manifest;
      int retries = 2;
      while (retries > 0) {
        try {
          manifest = await ytExplode.videos.streamsClient.getManifest(_currentVideo!['id']);
          break;
        } catch (e) {
          retries--;
          if (retries == 0) throw e;
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      ytExplode.close();

      if (manifest == null) throw Exception("Manifest nulo");

      final lowestVideo = manifest.muxed.sortByVideoQuality().first;
      final bestVideo = manifest.muxed.withHighestBitrate();

      if (_isAudioMode) {
        await _startAudio(lowestVideo.url.toString());
      } else {
        _currentQualityLabel = '${bestVideo.videoQuality.name}p';
        await _startVideo(bestVideo.url.toString());
      }
    } catch (e) {
      setState(() {
        _isLoadingMedia = false;
        _errorMessage = 'Error al cargar este contenido. Intenta de nuevo.';
      });
    }
  }

  Future<void> _startVideo(String url) async {
    await _audioPlayer.stop();
    final oldController = _videoController;
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    
    await _videoController!.initialize();
    _videoController!.play();
    _videoController!.addListener(() { if (mounted) setState(() {}); });

    setState(() => _isLoadingMedia = false);
    oldController?.dispose();
  }

  Future<void> _startAudio(String url) async {
    _videoController?.dispose();
    _videoController = null;

    try {
      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: _currentVideo!['id'],
            title: _currentVideo!['title'],
            artist: _currentVideo!['uploader'],
            artUri: Uri.parse(_currentVideo!['thumbnail']),
          ),
        ),
      );
      _audioPlayer.play();
      _audioPlayer.positionStream.listen((_) { if (mounted) setState(() {}); });
      setState(() => _isLoadingMedia = false);
    } catch (e) {
      setState(() { _isLoadingMedia = false; _errorMessage = 'Error en el motor de audio.'; });
    }
  }

  Future<void> _toggleMode(bool toAudio) async {
    if (_isAudioMode == toAudio) return;
    setState(() {
      _isAudioMode = toAudio;
      _isLoadingMedia = true;
    });
    _playMedia(_currentVideo!, _playlist, _currentIndex);
  }

  void _skipNext() {
    if (_playlist.isNotEmpty && _currentIndex < _playlist.length - 1) {
      _playMedia(_playlist[_currentIndex + 1], _playlist, _currentIndex + 1);
    }
  }

  void _skipPrevious() {
    if (_playlist.isNotEmpty && _currentIndex > 0) {
      _playMedia(_playlist[_currentIndex - 1], _playlist, _currentIndex - 1);
    }
  }

  void _seekRelative(int seconds) {
    if (_isAudioMode) {
      _audioPlayer.seek(_audioPlayer.position + Duration(seconds: seconds));
    } else if (_videoController != null) {
      _videoController!.seekTo(_videoController!.value.position + Duration(seconds: seconds));
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // ==========================================
  // 🎨 CONSTRUCTOR DE LA INTERFAZ FLOTANTE
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final miniPlayerHeight = 65.0;
    final bottomNavHeight = 56.0;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: _primaryColor,
        colorScheme: ColorScheme.dark(primary: _primaryColor),
      ),
      home: Scaffold(
        body: Stack(
          children: [
            // CAPA 1: LA APLICACIÓN NORMAL
            BaseAppScreen(
              primaryColor: _primaryColor,
              onChangeColor: _changeThemeColor,
              onVideoSelected: _playMedia,
            ),

            // CAPA 2: EL REPRODUCTOR FLOTANTE
            if (_isPlayerVisible && _currentVideo != null)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                top: _isPlayerExpanded ? 0 : screenHeight - miniPlayerHeight - bottomNavHeight,
                left: 0,
                right: 0,
                height: _isPlayerExpanded ? screenHeight : miniPlayerHeight,
                child: GestureDetector(
                  onTap: () {
                    if (!_isPlayerExpanded) setState(() => _isPlayerExpanded = true);
                  },
                  child: Container(
                    color: _isPlayerExpanded ? const Color(0xFF121212) : const Color(0xFF2C2C2C),
                    child: _isPlayerExpanded ? _buildExpandedPlayer() : _buildMiniPlayer(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPlayer() {
    return Row(
      children: [
        SizedBox(
          width: 110,
          height: double.infinity,
          child: (!_isAudioMode && _videoController != null && _videoController!.value.isInitialized)
              ? AbsorbPointer(child: VideoPlayer(_videoController!))
              : Image.network(_currentVideo!['thumbnail'], fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_currentVideo!['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
              Text(_currentVideo!['uploader'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            (_isAudioMode ? _audioPlayer.playing : (_videoController?.value.isPlaying ?? false)) ? Icons.pause : Icons.play_arrow,
            color: _primaryColor, size: 32,
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
          icon: const Icon(Icons.close, color: Colors.grey),
          onPressed: () {
            _audioPlayer.stop();
            _videoController?.dispose();
            _videoController = null;
            setState(() {
              _isPlayerVisible = false;
              _isPlayerExpanded = false;
            });
          },
        ),
      ],
    );
  }

  Widget _buildExpandedPlayer() {
    final pos = _isAudioMode ? _audioPlayer.position : (_videoController?.value.position ?? Duration.zero);
    final dur = _isAudioMode ? (_audioPlayer.duration ?? Duration.zero) : (_videoController?.value.duration ?? Duration.zero);

    return SafeArea(
      child: Column(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 36, color: Colors.white),
            onPressed: () => setState(() => _isPlayerExpanded = false),
          ),
          
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: _isLoadingMedia
                  ? Center(child: CircularProgressIndicator(color: _primaryColor))
                  : _errorMessage.isNotEmpty
                      ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)))
                      : _isAudioMode
                          ? Image.network(_currentVideo!['thumbnail'], fit: BoxFit.cover, color: Colors.black54, colorBlendMode: BlendMode.darken)
                          : (_videoController != null && _videoController!.value.isInitialized)
                              ? VideoPlayer(_videoController!)
                              : const SizedBox(),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('🎬 MODO VIDEO'),
                selected: !_isAudioMode,
                onSelected: (val) => _toggleMode(false),
                selectedColor: _primaryColor.withOpacity(0.3),
              ),
              const SizedBox(width: 15),
              ChoiceChip(
                label: const Text('🎧 MODO 2DO PLANO'),
                selected: _isAudioMode,
                onSelected: (val) => _toggleMode(true),
                selectedColor: _primaryColor.withOpacity(0.3),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Text(_currentVideo!['title'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(_currentVideo!['uploader'], style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Text(_formatDuration(pos), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(trackHeight: 3.0, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0), activeTrackColor: _primaryColor, thumbColor: _primaryColor),
                    child: Slider(
                      min: 0.0,
                      max: dur.inSeconds.toDouble() > 0 ? dur.inSeconds.toDouble() : 1.0,
                      value: pos.inSeconds.toDouble().clamp(0.0, dur.inSeconds.toDouble() > 0 ? dur.inSeconds.toDouble() : 1.0),
                      onChanged: (val) {
                        final newPos = Duration(seconds: val.toInt());
                        _isAudioMode ? _audioPlayer.seek(newPos) : _videoController?.seekTo(newPos);
                      },
                    ),
                  ),
                ),
                Text(_formatDuration(dur), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(icon: const Icon(Icons.skip_previous), color: Colors.white, iconSize: 36, onPressed: _skipPrevious),
              IconButton(icon: const Icon(Icons.replay_10), color: Colors.white70, iconSize: 32, onPressed: () => _seekRelative(-10)),
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: _primaryColor.withOpacity(0.2)),
                child: IconButton(
                  iconSize: 64,
                  icon: Icon(
                    (_isAudioMode ? _audioPlayer.playing : (_videoController?.value.isPlaying ?? false)) ? Icons.pause : Icons.play_arrow,
                    color: _primaryColor,
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
              IconButton(icon: const Icon(Icons.skip_next), color: Colors.white, iconSize: 36, onPressed: _skipNext),
            ],
          ),

          const Divider(color: Colors.grey, height: 30),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(alignment: Alignment.centerLeft, child: Text('Siguiente en la lista:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white70))),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _playlist.length,
              itemBuilder: (context, index) {
                final video = _playlist[index];
                final isPlaying = index == _currentIndex;
                return ListTile(
                  tileColor: isPlaying ? _primaryColor.withOpacity(0.1) : Colors.transparent,
                  leading: ClipRRect(borderRadius: BorderRadius.circular(8.0), child: Image.network(video['thumbnail'], width: 60, height: 45, fit: BoxFit.cover)),
                  title: Text(video['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isPlaying ? _primaryColor : Colors.white, fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                  subtitle: Text(video['uploader'], style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  trailing: isPlaying ? Icon(Icons.equalizer, color: _primaryColor) : null,
                  onTap: () => _playMedia(video, _playlist, index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 🏠 PANTALLA BASE NORMAL
// ==========================================
class BaseAppScreen extends StatefulWidget {
  final Color primaryColor;
  final Function(Color) onChangeColor;
  final Function(Map<String, dynamic>, List<Map<String, dynamic>>, int) onVideoSelected;
  
  const BaseAppScreen({super.key, required this.primaryColor, required this.onChangeColor, required this.onVideoSelected});

  @override
  State<BaseAppScreen> createState() => _BaseAppScreenState();
}

class _BaseAppScreenState extends State<BaseAppScreen> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _trendingVideos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _loadTrending();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final favString = prefs.getString('saved_favorites');
    if (favString != null) setState(() => _favorites = List<Map<String, dynamic>>.from(json.decode(favString)));
  }

  Future<void> _saveLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_favorites', json.encode(_favorites));
  }

  Future<void> _loadTrending() async {
    setState(() => _isLoading = true);
    try {
      final ytExplode = yt.YoutubeExplode();
      final searchResults = await ytExplode.search.search('Tendencias música y videos 2026');
      ytExplode.close();
      if (mounted) {
        setState(() {
          _trendingVideos = searchResults.map((v) => {'id': v.id.value, 'title': v.title, 'uploader': v.author, 'thumbnail': v.thumbnails.highResUrl}).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleFavorite(Map<String, dynamic> videoItem) {
    setState(() {
      if (_favorites.any((v) => v['id'] == videoItem['id'])) {
        _favorites.removeWhere((v) => v['id'] == videoItem['id']);
      } else {
        _favorites.add(videoItem);
      }
    });
    _saveLocalData();
  }

  @override
  Widget build(BuildContext context) {
    final activeList = _currentIndex == 0 ? _trendingVideos : _favorites;

    return Scaffold(
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1E1E),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: widget.primaryColor.withOpacity(0.2)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.play_circle_filled, size: 48, color: widget.primaryColor),
                  const SizedBox(height: 10),
                  const Text('Media App', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Cambiar Tema'),
              trailing: PopupMenuButton<Color>(
                icon: Icon(Icons.circle, color: widget.primaryColor),
                onSelected: widget.onChangeColor,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: Colors.purpleAccent, child: Text('Púrpura Neón')),
                  PopupMenuItem(value: Colors.blueAccent, child: Text('Azul Eléctrico')),
                  PopupMenuItem(value: Colors.tealAccent, child: Text('Verde Esmeralda')),
                  PopupMenuItem(value: Colors.redAccent, child: Text('Rojo Carmesí')),
                ],
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Tendencias' : 'Mis Favoritos', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchScreen(
                  primaryColor: widget.primaryColor,
                  onVideoSelected: widget.onVideoSelected,
                )),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: widget.primaryColor))
          : activeList.isEmpty
              ? Center(child: Text(_currentIndex == 0 ? 'No hay tendencias.' : 'Tu lista de favoritos está vacía.', style: const TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: activeList.length,
                  itemBuilder: (context, index) {
                    final video = activeList[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: ClipRRect(borderRadius: BorderRadius.circular(8.0), child: Image.network(video['thumbnail'], width: 80, height: 60, fit: BoxFit.cover)),
                      title: Text(video['title'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(video['uploader'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      onTap: () => widget.onVideoSelected(video, activeList, index),
                      trailing: IconButton(
                        icon: Icon(_favorites.any((v) => v['id'] == video['id']) ? Icons.favorite : Icons.favorite_border, color: _favorites.any((v) => v['id'] == video['id']) ? Colors.redAccent : Colors.grey),
                        onPressed: () => _toggleFavorite(video),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: widget.primaryColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF1F1F1F),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.local_fire_department), label: 'Tendencias'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favoritos'),
        ],
      ),
    );
  }
}

// ==========================================
// 🔍 PANTALLA DE BÚSQUEDA
// ==========================================
class SearchScreen extends StatefulWidget {
  final Color primaryColor;
  final Function(Map<String, dynamic>, List<Map<String, dynamic>>, int) onVideoSelected;

  const SearchScreen({super.key, required this.primaryColor, required this.onVideoSelected});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _searchHistory = [];
  List<String> _suggestions = [];
  List<Map<String, dynamic>> _searchResults = [];
  
  bool _isSearching = false;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _searchHistory = prefs.getStringList('search_history') ?? []);
  }

  Future<void> _saveToHistory(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _searchHistory.remove(query); 
    _searchHistory.insert(0, query); 
    if (_searchHistory.length > 10) _searchHistory = _searchHistory.sublist(0, 10); 
    await prefs.setStringList('search_history', _searchHistory);
  }

  Future<void> _getSuggestions(String query) async {
    if (query.trim().isEmpty) { setState(() => _suggestions = []); return; }
    try {
      final ytExplode = yt.YoutubeExplode();
      final results = await ytExplode.search.getQuerySuggestions(query);
      ytExplode.close();
      if (mounted) setState(() => _suggestions = results);
    } catch (e) {}
  }

  Future<void> _performSearch(String query) async {
    FocusManager.instance.primaryFocus?.unfocus();
    _searchController.text = query;
    _saveToHistory(query);
    setState(() { _showResults = true; _isSearching = true; _suggestions = []; });

    try {
      final ytExplode = yt.YoutubeExplode();
      final results = await ytExplode.search.search(query);
      ytExplode.close();
      if (mounted) {
        setState(() {
          _searchResults = results.map((v) => {'id': v.id.value, 'title': v.title, 'uploader': v.author, 'thumbnail': v.thumbnails.highResUrl}).toList();
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: (val) {
            setState(() => _showResults = false);
            _getSuggestions(val);
          },
          onSubmitted: _performSearch,
          decoration: InputDecoration(
            hintText: 'Buscar...',
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: Icon(Icons.clear, color: widget.primaryColor),
              onPressed: () {
                _searchController.clear();
                setState(() { _showResults = false; _suggestions = []; });
              },
            ),
          ),
        ),
      ),
      body: _showResults ? _buildResults() : _buildAutocompleteAndHistory(),
    );
  }

  Widget _buildAutocompleteAndHistory() {
    if (_searchController.text.isEmpty) {
      if (_searchHistory.isEmpty) return const Center(child: Text('Busca tu música favorita', style: TextStyle(color: Colors.grey)));
      return ListView.builder(
        itemCount: _searchHistory.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.history, color: Colors.grey),
            title: Text(_searchHistory[index], style: const TextStyle(color: Colors.white70)),
            onTap: () => _performSearch(_searchHistory[index]),
            trailing: IconButton(icon: const Icon(Icons.close, size: 20, color: Colors.grey), onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              setState(() => _searchHistory.removeAt(index));
              prefs.setStringList('search_history', _searchHistory);
            }),
          );
        },
      );
    } else {
      return Container(
        color: const Color(0xFFE0E0E0), 
        child: ListView.builder(
          itemCount: _suggestions.length,
          itemBuilder: (context, index) {
            return ListTile(
              leading: Icon(Icons.search, color: widget.primaryColor),
              title: Text(_suggestions[index], style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
              onTap: () => _performSearch(_suggestions[index]),
            );
          },
        ),
      );
    }
  }

  Widget _buildResults() {
    if (_isSearching) return Center(child: CircularProgressIndicator(color: widget.primaryColor));
    if (_searchResults.isEmpty) return const Center(child: Text('No se encontraron resultados', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final video = _searchResults[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: ClipRRect(borderRadius: BorderRadius.circular(8.0), child: Image.network(video['thumbnail'], width: 80, height: 60, fit: BoxFit.cover)),
          title: Text(video['title'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(video['uploader'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          onTap: () {
            Navigator.pop(context); 
            widget.onVideoSelected(video, _searchResults, index); 
          },
        );
      },
    );
  }
}
