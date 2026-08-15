import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==========================================
// 🌍 VARIABLES GLOBALES (El secreto para que no se corte)
// ==========================================
final AudioPlayer globalAudioPlayer = AudioPlayer();

enum AppMode { video, music }
AppMode globalAppMode = AppMode.video; // Modo por defecto

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
// 🏠 PANTALLA PRINCIPAL (CON MINI-REPRODUCTOR)
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

  Future<void> _loadTrending() async {
    setState(() => _isLoading = true);
    try {
      final ytExplode = yt.YoutubeExplode();
      final searchResults = await ytExplode.search.search('Lo más escuchado en México 2026');
      ytExplode.close();

      if (mounted) {
        setState(() {
          _trendingVideos = searchResults.map((video) => {
            'id': video.id.value,
            'title': video.title,
            'uploader': video.author,
            'thumbnail': video.thumbnails.highResUrl,
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
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
              leading: Icon(Icons.video_library, color: globalAppMode == AppMode.video ? widget.primaryColor : Colors.white),
              title: Text('Video', style: TextStyle(fontSize: 16, color: globalAppMode == AppMode.video ? widget.primaryColor : Colors.white, fontWeight: globalAppMode == AppMode.video ? FontWeight.bold : FontWeight.normal)),
              onTap: () {
                setState(() => globalAppMode = AppMode.video);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Modo Video Activado'), backgroundColor: widget.primaryColor, duration: const Duration(seconds: 1)));
              },
            ),
            ListTile(
              leading: Icon(Icons.music_note, color: globalAppMode == AppMode.music ? widget.primaryColor : Colors.white),
              title: Text('Música', style: TextStyle(fontSize: 16, color: globalAppMode == AppMode.music ? widget.primaryColor : Colors.white, fontWeight: globalAppMode == AppMode.music ? FontWeight.bold : FontWeight.normal)),
              onTap: () {
                setState(() => globalAppMode = AppMode.music);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Modo Música Activado'), backgroundColor: widget.primaryColor, duration: const Duration(seconds: 1)));
              },
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Cambiar Tema'),
              trailing: PopupMenuButton<Color>(
                icon: Icon(Icons.circle, color: widget.primaryColor),
                onSelected: widget.onChangeColor,
                itemBuilder: (context) => [
                  const PopupMenuItem(value: Colors.purpleAccent, child: Text('Púrpura Neón')),
                  const PopupMenuItem(value: Colors.blueAccent, child: Text('Azul Eléctrico')),
                  const PopupMenuItem(value: Colors.tealAccent, child: Text('Verde Esmeralda')),
                  const PopupMenuItem(value: Colors.redAccent, child: Text('Rojo Carmesí')),
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
                  favorites: _favorites,
                  onToggleFavorite: _toggleFavorite,
                  onVideoSelected: _openPlayer,
                )),
              ).then((_) => setState(() {}));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: widget.primaryColor))
                : activeList.isEmpty
                    ? Center(child: Text(_currentIndex == 0 ? 'No hay tendencias.' : 'Tu lista de favoritos está vacía.', style: const TextStyle(color: Colors.grey)))
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
          // 🎵 MINI REPRODUCTOR FLOTANTE PARA LA MÚSICA
          StreamBuilder<SequenceState?>(
            stream: globalAudioPlayer.sequenceStateStream,
            builder: (context, snapshot) {
              final state = snapshot.data;
              if (state?.currentSource == null || globalAppMode != AppMode.music) return const SizedBox.shrink();
              
              final mediaItem = state!.currentSource!.tag as MediaItem;
              return GestureDetector(
                onTap: () {
                  // Volver a abrir el player en grande
                  _openPlayer(
                    {'id': mediaItem.id, 'title': mediaItem.title, 'uploader': mediaItem.artist, 'thumbnail': mediaItem.artUri.toString()}, 
                    [], 0 // Pasamos vacío temporalmente porque ya está reproduciendo
                  );
                },
                child: Container(
                  color: const Color(0xFF2C2C2C),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(mediaItem.artUri.toString(), width: 40, height: 40, fit: BoxFit.cover)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(mediaItem.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                            Text(mediaItem.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      StreamBuilder<PlayerState>(
                        stream: globalAudioPlayer.playerStateStream,
                        builder: (context, snap) {
                          final playing = snap.data?.playing ?? false;
                          return IconButton(
                            icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: widget.primaryColor, size: 30),
                            onPressed: () => playing ? globalAudioPlayer.pause() : globalAudioPlayer.play(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
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
          BottomNavigationBarItem(icon: Icon(Icons.local_fire_department), label: 'Tendencias'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favoritos'),
        ],
      ),
    );
  }
}

// ==========================================
// 🔍 PANTALLA DE BÚSQUEDA DEDICADA
// ==========================================
class SearchScreen extends StatefulWidget {
  final Color primaryColor;
  final List<Map<String, dynamic>> favorites;
  final Function(Map<String, dynamic>) onToggleFavorite;
  final Function(Map<String, dynamic>, List<Map<String, dynamic>>, int) onVideoSelected;

  const SearchScreen({super.key, required this.primaryColor, required this.favorites, required this.onToggleFavorite, required this.onVideoSelected});

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
    setState(() {
      _searchHistory = prefs.getStringList('search_history') ?? [];
    });
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
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
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
    
    setState(() {
      _showResults = true;
      _isSearching = true;
      _suggestions = [];
    });

    try {
      final ytExplode = yt.YoutubeExplode();
      final results = await ytExplode.search.search(query);
      ytExplode.close();

      if (mounted) {
        setState(() {
          _searchResults = results.map((video) => {
            'id': video.id.value,
            'title': video.title,
            'uploader': video.author,
            'thumbnail': video.thumbnails.highResUrl,
          }).toList();
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
                setState(() {
                  _showResults = false;
                  _suggestions = [];
                });
              },
            ),
          ),
        ),
      ),
      body: _showResults 
          ? _buildResults() 
          : _buildAutocompleteAndHistory(),
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
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 20, color: Colors.grey),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                setState(() => _searchHistory.removeAt(index));
                prefs.setStringList('search_history', _searchHistory);
              },
            ),
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
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.network(video['thumbnail'], width: 80, height: 60, fit: BoxFit.cover),
          ),
          title: Text(video['title'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(video['uploader'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          onTap: () {
            // Regresa y abre el reproductor
            Navigator.pop(context);
            widget.onVideoSelected(video, _searchResults, index);
          },
        );
      },
    );
  }
}

// ==========================================
// 🎥 PANTALLA DEL REPRODUCTOR INTELIGENTE
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
  
  List<yt.MuxedStreamInfo> _videoStreams = [];
  String _errorMessage = '';
  
  bool _isLoading = true;
  String _currentQualityLabel = 'Cargando...';

  @override
  void initState() {
    super.initState();
    _currentVideo = widget.initialVideo;
    _currentIndex = widget.initialIndex;
    _initEngine();
  }

  // EL CEREBRO DE LA APP: Decide qué motor encender
  Future<void> _initEngine() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final ytExplode = yt.YoutubeExplode();
      final manifest = await ytExplode.videos.streamsClient.getManifest(_currentVideo['id']);
      ytExplode.close();

      if (globalAppMode == AppMode.video) {
        // MODO VIDEO
        _videoStreams = manifest.muxed.sortByVideoQuality().toList();
        if (_videoStreams.isNotEmpty) {
          // Si el audio estaba sonando, lo apagamos para no mezclar
          await globalAudioPlayer.stop(); 
          _currentQualityLabel = '${_videoStreams.first.videoQuality.name}p';
          await _startVideo(_videoStreams.first.url.toString());
        }
      } else {
        // MODO MÚSICA (2DO PLANO AUTOMÁTICO)
        // Evitamos reiniciar si ya estamos escuchando la misma canción
        if (globalAudioPlayer.sequenceState?.currentSource?.tag.id != _currentVideo['id']) {
          _videoController?.dispose(); // Matamos el video
          _videoController = null;

          String audioUrl = '';
          final mp4Audio = manifest.audioOnly.where((s) => s.container.name == 'mp4' || s.audioCodec.contains('mp4a'));
          if (mp4Audio.isNotEmpty) {
             audioUrl = mp4Audio.withHighestBitrate().url.toString();
          } else {
             audioUrl = manifest.muxed.withHighestBitrate().url.toString(); // Fallback seguro
          }
          await _startAudio(audioUrl);
        } else {
           setState(() => _isLoading = false); // Ya estaba sonando
        }
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = 'Error al cargar este contenido.'; });
    }
  }

  Future<void> _startVideo(String url) async {
    final oldController = _videoController;
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    
    await _videoController!.initialize();
    _videoController!.play();
    _videoController!.addListener(() { if (mounted) setState(() {}); });

    if (mounted) setState(() => _isLoading = false);
    oldController?.dispose();
  }

  Future<void> _startAudio(String url) async {
    try {
      await globalAudioPlayer.stop();
      await globalAudioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: _currentVideo['id'],
            title: _currentVideo['title'],
            artist: _currentVideo['uploader'],
            artUri: Uri.parse(_currentVideo['thumbnail']),
          ),
        ),
      );
      globalAudioPlayer.play();
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = 'Error al reproducir.'; });
    }
  }

  Future<void> _changeVideoQuality(String url, String label) async {
    Navigator.pop(context); // Cierra menú
    setState(() { _isLoading = true; _currentQualityLabel = label; });
    final pos = _videoController!.value.position;
    await _startVideo(url);
    _videoController!.seekTo(pos);
  }

  void _changeVideo(int newIndex) {
    if (newIndex >= 0 && newIndex < widget.playlist.length) {
      _videoController?.pause();
      setState(() {
        _currentIndex = newIndex;
        _currentVideo = widget.playlist[newIndex];
      });
      _initEngine();
    }
  }

  void _seekRelative(int seconds) {
    if (globalAppMode == AppMode.music) {
      globalAudioPlayer.seek(globalAudioPlayer.position + Duration(seconds: seconds));
    } else if (_videoController != null) {
      _videoController!.seekTo(_videoController!.value.position + Duration(seconds: seconds));
    }
  }

  void _toggleFullScreen() {
    if (_videoController == null || globalAppMode == AppMode.music) return;
    
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
    // IMPORTANTE: Matamos el video al salir, pero DEJAMOS VIVA LA MÚSICA
    if (globalAppMode == AppMode.video) {
      _videoController?.dispose();
    }
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
          // Solo mostrar engrane en modo video
          if (globalAppMode == AppMode.video)
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: const Color(0xFF1E1E1E),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(padding: EdgeInsets.all(16), child: Text('Calidad de Video', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
                        ..._videoStreams.map((stream) => ListTile(
                          leading: const Icon(Icons.hd, color: Colors.white70),
                          title: Text('${stream.videoQuality.name}p', style: const TextStyle(color: Colors.white)),
                          onTap: () => _changeVideoQuality(stream.url.toString(), '${stream.videoQuality.name}p'),
                        )),
                      ],
                    ),
                  ),
                );
              },
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
                      : _errorMessage.isNotEmpty
                          ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)))
                          : globalAppMode == AppMode.music
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
                          if (globalAppMode == AppMode.video)
                             Text('Calidad: $_currentQualityLabel', style: TextStyle(fontSize: 12, color: widget.primaryColor)),
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

              // BARRA DE PROGRESO REACTIVA
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: StreamBuilder<Duration>(
                  stream: globalAppMode == AppMode.music ? globalAudioPlayer.positionStream : Stream.empty(),
                  builder: (context, snapshot) {
                    final pos = globalAppMode == AppMode.music ? (snapshot.data ?? Duration.zero) : (_videoController?.value.position ?? Duration.zero);
                    final dur = globalAppMode == AppMode.music ? (globalAudioPlayer.duration ?? Duration.zero) : (_videoController?.value.duration ?? Duration.zero);
                    
                    return Row(
                      children: [
                        Text(_formatDuration(pos), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(trackHeight: 3.0, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0), activeTrackColor: widget.primaryColor, thumbColor: widget.primaryColor),
                            child: Slider(
                              min: 0.0,
                              max: dur.inSeconds.toDouble() > 0 ? dur.inSeconds.toDouble() : 1.0,
                              value: pos.inSeconds.toDouble().clamp(0.0, dur.inSeconds.toDouble() > 0 ? dur.inSeconds.toDouble() : 1.0),
                              onChanged: (val) {
                                final newPos = Duration(seconds: val.toInt());
                                globalAppMode == AppMode.music ? globalAudioPlayer.seek(newPos) : _videoController?.seekTo(newPos);
                              },
                            ),
                          ),
                        ),
                        Text(_formatDuration(dur), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    );
                  }
                ),
              ),

              const SizedBox(height: 10),

              // CONTROLES
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(icon: const Icon(Icons.skip_previous), color: Colors.white, iconSize: 36, onPressed: () => _changeVideo(_currentIndex - 1)),
                  IconButton(icon: const Icon(Icons.replay_10), color: Colors.white70, iconSize: 32, onPressed: () => _seekRelative(-10)),
                  Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: widget.primaryColor.withOpacity(0.2)),
                    child: StreamBuilder<PlayerState>(
                      stream: globalAppMode == AppMode.music ? globalAudioPlayer.playerStateStream : Stream.empty(),
                      builder: (context, snapshot) {
                        final isPlaying = globalAppMode == AppMode.music 
                             ? (snapshot.data?.playing ?? false) 
                             : (_videoController?.value.isPlaying ?? false);
                             
                        return IconButton(
                          iconSize: 64,
                          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: widget.primaryColor),
                          onPressed: () {
                            if (globalAppMode == AppMode.music) {
                              isPlaying ? globalAudioPlayer.pause() : globalAudioPlayer.play();
                            } else {
                              setState(() => isPlaying ? _videoController!.pause() : _videoController!.play());
                            }
                          },
                        );
                      }
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.forward_10), color: Colors.white70, iconSize: 32, onPressed: () => _seekRelative(10)),
                  IconButton(icon: const Icon(Icons.skip_next), color: Colors.white, iconSize: 36, onPressed: () => _changeVideo(_currentIndex + 1)),
                ],
              ),
              const SizedBox(height: 10),
              if (globalAppMode == AppMode.video)
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
                    Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(10))),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(child: AspectRatio(aspectRatio: widget.controller.value.aspectRatio, child: VideoPlayer(widget.controller))),
            if (_showControls)
              Container(
                color: Colors.black54,
                child: Stack(
                  children: [
                    Positioned(top: 10, left: 10, child: IconButton(icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 32), onPressed: () => Navigator.pop(context))),
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
