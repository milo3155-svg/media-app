import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
      await [
        Permission.notification,
      ].request();
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

  Map<String, dynamic>? _currentVideo;
  VideoPlayerController? _videoController;
  bool _isPlayerLoading = false;

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

  Future<void> _playVideo(Map<String, dynamic> videoItem) async {
    final videoId = videoItem['id'] ?? '';
    if (videoId.isEmpty) return;

    setState(() {
      _currentVideo = videoItem;
      _isPlayerLoading = true;
    });

    if (_videoController != null) {
      await _videoController!.dispose();
      _videoController = null;
    }

    try {
      // 1. EXTRAER URL RAW (Bypass de restricción VEVO)
      final ytExplode = yt.YoutubeExplode();
      final manifest = await ytExplode.videos.streamsClient.getManifest(videoId);
      
      // Obtenemos el flujo muxed (Video + Audio en un solo MP4) de mejor calidad (usualmente 720p)
      final streamInfo = manifest.muxed.withHighestBitrate();
      final streamUrl = streamInfo.url.toString();
      ytExplode.close();

      // 2. REPRODUCIR ARCHIVO NATIVAMENTE
      final controller = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
      await controller.initialize();
      
      setState(() {
        _videoController = controller;
        _isPlayerLoading = false;
      });
      
      await _videoController!.play();
      
      // Actualizar UI cuando termine o cambie estado
      _videoController!.addListener(() {
        if (mounted) setState(() {});
      });

    } catch (e) {
      setState(() {
        _isPlayerLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo extraer el archivo de este video.')),
      );
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
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      SearchTab(
        primaryColor: widget.primaryColor,
        onVideoSelected: (video) => _playVideo(video),
        currentVideoId: _currentVideo?['id'],
        onToggleFavorite: _toggleFavorite,
        isFavorite: _isFavorite,
      ),
      FavoritesTab(
        primaryColor: widget.primaryColor,
        favorites: _favorites,
        onVideoSelected: (video) => _playVideo(video),
        currentVideoId: _currentVideo?['id'],
        onToggleFavorite: _toggleFavorite,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0 ? 'Media App (Raw Video)' : 'Tus Favoritos',
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1F1F1F),
        actions: [
          PopupMenuButton<Color>(
            icon: Icon(Icons.palette_rounded, color: widget.primaryColor),
            onSelected: widget.onChangeColor,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: Colors.purpleAccent,
                child: Row(children: [CircleAvatar(backgroundColor: Colors.purpleAccent, radius: 8), SizedBox(width: 8), Text('Púrpura Neón')]),
              ),
              const PopupMenuItem(
                value: Colors.blueAccent,
                child: Row(children: [CircleAvatar(backgroundColor: Colors.blueAccent, radius: 8), SizedBox(width: 8), Text('Azul Eléctrico')]),
              ),
              const PopupMenuItem(
                value: Colors.tealAccent,
                child: Row(children: [CircleAvatar(backgroundColor: Colors.tealAccent, radius: 8), SizedBox(width: 8), Text('Verde Esmeralda')]),
              ),
              const PopupMenuItem(
                value: Colors.redAccent,
                child: Row(children: [CircleAvatar(backgroundColor: Colors.redAccent, radius: 8), SizedBox(width: 8), Text('Rojo Carmesí')]),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_currentVideo != null) _buildVideoPlayerArea(),
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
          const BottomNavigationBarItem(icon: Icon(Icons.video_library), label: 'Videos'),
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

  Widget _buildVideoPlayerArea() {
    return Container(
      width: double.infinity,
      height: 220,
      color: Colors.black,
      child: _isPlayerLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: widget.primaryColor),
                  const SizedBox(height: 12),
                  const Text('Extrayendo archivo original...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            )
          : _videoController != null && _videoController!.value.isInitialized
              ? Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
                    VideoProgressIndicator(
                      _videoController!,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      colors: VideoProgressColors(
                        playedColor: widget.primaryColor,
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.black45,
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: IconButton(
                        iconSize: 60,
                        icon: Icon(
                          _videoController!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        onPressed: () {
                          setState(() {
                            if (_videoController!.value.isPlaying) {
                              _videoController!.pause();
                            } else {
                              _videoController!.play();
                            }
                          });
                        },
                      ),
                    ),
                  ],
                )
              : const Center(child: Text('Error al cargar video', style: TextStyle(color: Colors.grey))),
    );
  }
}

class SearchTab extends StatefulWidget {
  final Color primaryColor;
  final Function(Map<String, dynamic>) onVideoSelected;
  final String? currentVideoId;
  final Function(Map<String, dynamic>) onToggleFavorite;
  final bool Function(Map<String, dynamic>) isFavorite;

  const SearchTab({
    super.key,
    required this.primaryColor,
    required this.onVideoSelected,
    this.currentVideoId,
    required this.onToggleFavorite,
    required this.isFavorite,
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
          _videos = searchResults.map((video) {
            return {
              'id': video.id.value,
              'title': video.title,
              'uploader': video.author,
              'thumbnail': video.thumbnails.highResUrl,
            };
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _videos = [];
        });
      }
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
              hintText: 'Buscar música, VEVO, resúmenes...',
              prefixIcon: Icon(Icons.search, color: widget.primaryColor),
              suffixIcon: IconButton(
                icon: Icon(Icons.send, color: widget.primaryColor),
                onPressed: () => _searchVideos(_searchController.text),
              ),
              filled: true,
              fillColor: const Color(0xFF2C2C2C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (value) => _searchVideos(value),
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: widget.primaryColor))
              : _videos.isEmpty
                  ? const Center(child: Text('No se encontraron videos'))
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
                              child: video['thumbnail'].isNotEmpty
                                  ? Image.network(
                                      video['thumbnail'],
                                      width: 70,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, o, s) => const Icon(Icons.videocam, size: 30),
                                    )
                                  : const Icon(Icons.videocam, size: 30),
                            ),
                            title: Text(
                              video['title'] ?? 'Sin título',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              video['uploader'] ?? 'Canal',
                              style: const TextStyle(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    isFav ? Icons.favorite : Icons.favorite_border,
                                    color: isFav ? Colors.redAccent : Colors.grey,
                                    size: 20,
                                  ),
                                  onPressed: () => widget.onToggleFavorite(video),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isSelected ? Icons.play_circle_filled : Icons.play_arrow_rounded,
                                    color: widget.primaryColor,
                                    size: 34,
                                  ),
                                  onPressed: () => widget.onVideoSelected(video),
                                ),
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
  final Function(Map<String, dynamic>) onVideoSelected;
  final String? currentVideoId;
  final Function(Map<String, dynamic>) onToggleFavorite;

  const FavoritesTab({
    super.key,
    required this.primaryColor,
    required this.favorites,
    required this.onVideoSelected,
    this.currentVideoId,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      return const Center(
        child: Text(
          'Aún no has agregado videos a favoritos.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

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
              child: video['thumbnail'].isNotEmpty
                  ? Image.network(
                      video['thumbnail'],
                      width: 70,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (c, o, s) => const Icon(Icons.videocam, size: 30),
                    )
                  : const Icon(Icons.videocam, size: 30),
            ),
            title: Text(
              video['title'] ?? 'Sin título',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              video['uploader'] ?? 'Canal',
              style: const TextStyle(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
                  onPressed: () => onToggleFavorite(video),
                ),
                IconButton(
                  icon: Icon(
                    isSelected ? Icons.play_circle_filled : Icons.play_arrow_rounded,
                    color: primaryColor,
                    size: 34,
                  ),
                  onPressed: () => onVideoSelected(video),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
