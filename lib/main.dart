import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.media_app.channel.audio',
    androidNotificationChannelName: 'Media Playback',
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
    _configureAudioSession();
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
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
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _downloadedTracks = [];
  List<dynamic> _currentPlaylist = [];
  int _currentTrackIndex = -1;

  Map<String, dynamic>? _currentTrack;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadSavedData();

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _position = Duration.zero;
            _playNextTrack();
          }
        });
      }
    });

    _audioPlayer.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _audioPlayer.durationStream.listen((dur) {
      if (mounted) setState(() => _duration = dur ?? Duration.zero);
    });
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final favString = prefs.getString('saved_favorites');
    final downString = prefs.getString('saved_downloads');

    if (favString != null) {
      setState(() {
        _favorites = List<Map<String, dynamic>>.from(json.decode(favString));
      });
    }

    if (downString != null) {
      setState(() {
        _downloadedTracks = List<Map<String, dynamic>>.from(json.decode(downString));
      });
    }
  }

  Future<void> _saveLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_favorites', json.encode(_favorites));
    await prefs.setString('saved_downloads', json.encode(_downloadedTracks));
  }

  Future<void> _playTrack(Map<String, dynamic> track, {List<dynamic>? playlist, int? index}) async {
    if (playlist != null) _currentPlaylist = playlist;
    if (index != null) _currentTrackIndex = index;

    final mediaUrl = track['localPath'] ?? track['previewUrl'] ?? '';
    if (mediaUrl.isEmpty) return;

    try {
      if (_currentTrack?['previewUrl'] == track['previewUrl'] && _currentTrack?['localPath'] == track['localPath']) {
        if (_isPlaying) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.play();
        }
      } else {
        setState(() {
          _currentTrack = track;
        });

        final mediaItem = MediaItem(
          id: track['trackId']?.toString() ?? track['previewUrl'] ?? '0',
          album: track['collectionName'] ?? 'Álbum',
          title: track['trackName'] ?? 'Sin título',
          artist: track['artistName'] ?? 'Artista desconocido',
          artUri: Uri.parse(track['artworkUrl100'] ?? ''),
        );

        if (track['localPath'] != null) {
          await _audioPlayer.setAudioSource(
            AudioSource.uri(Uri.file(track['localPath']), tag: mediaItem),
          );
        } else {
          await _audioPlayer.setAudioSource(
            AudioSource.uri(Uri.parse(mediaUrl), tag: mediaItem),
          );
        }

        await _audioPlayer.play();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al reproducir')),
      );
    }
  }

  void _playNextTrack() {
    if (_currentPlaylist.isNotEmpty && _currentTrackIndex < _currentPlaylist.length - 1) {
      _currentTrackIndex++;
      _playTrack(_currentPlaylist[_currentTrackIndex], index: _currentTrackIndex);
    }
  }

  void _playPreviousTrack() {
    if (_currentPlaylist.isNotEmpty && _currentTrackIndex > 0) {
      _currentTrackIndex--;
      _playTrack(_currentPlaylist[_currentTrackIndex], index: _currentTrackIndex);
    }
  }

  void _seekRelative(int seconds) {
    final newPosition = _position + Duration(seconds: seconds);
    if (newPosition < Duration.zero) {
      _audioPlayer.seek(Duration.zero);
    } else if (newPosition > _duration) {
      _audioPlayer.seek(_duration);
    } else {
      _audioPlayer.seek(newPosition);
    }
  }

  void _toggleFavorite(Map<String, dynamic> track) {
    final trackId = track['trackId'] ?? track['previewUrl'];
    setState(() {
      final exists = _favorites.any((t) => (t['trackId'] ?? t['previewUrl']) == trackId);
      if (exists) {
        _favorites.removeWhere((t) => (t['trackId'] ?? t['previewUrl']) == trackId);
      } else {
        _favorites.add(track);
      }
    });
    _saveLocalData();
  }

  bool _isFavorite(Map<String, dynamic> track) {
    final trackId = track['trackId'] ?? track['previewUrl'];
    return _favorites.any((t) => (t['trackId'] ?? t['previewUrl']) == trackId);
  }

  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
      if (dirs != null && dirs.isNotEmpty) {
        return dirs.first;
      }
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<void> _downloadTrack(Map<String, dynamic> track) async {
    final url = track['previewUrl'];
    if (url == null || url.isEmpty) return;

    await Permission.audio.request();

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Descargando pista...')),
      );

      final dir = await _getDownloadDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final rawName = track['trackName'] ?? 'Track';
      final cleanName = rawName.toString().replaceAll(RegExp(r'[^\w\s\.-]'), '');
      final fileName = '${cleanName}_${track['trackId'] ?? DateTime.now().millisecondsSinceEpoch}.m4a';
      final filePath = '${dir.path}/$fileName';

      await Dio().download(url, filePath);

      final downloadedTrack = Map<String, dynamic>.from(track);
      downloadedTrack['localPath'] = filePath;

      setState(() {
        _downloadedTracks.add(downloadedTrack);
      });

      await _saveLocalData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Guardado correctamente! 📥')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al descargar')),
      );
    }
  }

  Future<void> _deleteDownloadedTrack(Map<String, dynamic> track) async {
    try {
      final localPath = track['localPath'];
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      setState(() {
        _downloadedTracks.removeWhere((t) => t['localPath'] == track['localPath']);
        if (_currentTrack?['localPath'] == track['localPath']) {
          _audioPlayer.stop();
          _currentTrack = null;
        }
      });

      await _saveLocalData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Canción eliminada 🗑️')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al eliminar archivo')),
      );
    }
  }

  void _openExpandedPlayer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181818),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double maxSeconds = _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0;
            final double currentSeconds = _position.inSeconds.toDouble().clamp(0.0, maxSeconds);
            final isFav = _isFavorite(_currentTrack!);

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.9,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text('Reproduciendo ahora', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.redAccent : Colors.white,
                        ),
                        onPressed: () {
                          _toggleFavorite(_currentTrack!);
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16.0),
                      child: Image.network(
                        _currentTrack?['artworkUrl100']?.replaceAll('100x100bb', '600x600bb') ?? '',
                        width: 280,
                        height: 280,
                        fit: BoxFit.cover,
                        errorBuilder: (c, o, s) => const Icon(Icons.music_note, size: 120),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        Text(
                          _currentTrack?['trackName'] ?? 'Sin título',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentTrack?['artistName'] ?? 'Artista desconocido',
                          style: const TextStyle(color: Colors.grey, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4.0,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                            activeTrackColor: widget.primaryColor,
                            inactiveTrackColor: Colors.grey[800],
                            thumbColor: widget.primaryColor,
                          ),
                          child: Slider(
                            value: currentSeconds,
                            min: 0.0,
                            max: maxSeconds,
                            onChanged: (value) => _audioPlayer.seek(Duration(seconds: value.toInt())),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(_position), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            Text(_formatDuration(_duration), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous, size: 38, color: Colors.white),
                        onPressed: () {
                          _playPreviousTrack();
                          setModalState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.replay_10, size: 30, color: Colors.grey),
                        onPressed: () {
                          _seekRelative(-10);
                          setModalState(() {});
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                          size: 64,
                          color: widget.primaryColor,
                        ),
                        onPressed: () {
                          _playTrack(_currentTrack!);
                          setModalState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_10, size: 30, color: Colors.grey),
                        onPressed: () {
                          _seekRelative(10);
                          setModalState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next, size: 38, color: Colors.white),
                        onPressed: () {
                          _playNextTrack();
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      SearchTab(
        primaryColor: widget.primaryColor,
        onTrackSelected: (track, playlist, index) => _playTrack(track, playlist: playlist, index: index),
        currentTrackUrl: _currentTrack?['previewUrl'],
        isPlaying: _isPlaying,
        onToggleFavorite: _toggleFavorite,
        isFavorite: _isFavorite,
        onDownload: _downloadTrack,
      ),
      FavoritesTab(
        primaryColor: widget.primaryColor,
        favorites: _favorites,
        onTrackSelected: (track, playlist, index) => _playTrack(track, playlist: playlist, index: index),
        currentTrackUrl: _currentTrack?['previewUrl'],
        isPlaying: _isPlaying,
        onToggleFavorite: _toggleFavorite,
      ),
      DownloadsTab(
        primaryColor: widget.primaryColor,
        downloadedTracks: _downloadedTracks,
        onTrackSelected: (track, playlist, index) => _playTrack(track, playlist: playlist, index: index),
        currentTrackPath: _currentTrack?['localPath'],
        isPlaying: _isPlaying,
        onDelete: _deleteDownloadedTrack,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0
              ? 'Media App'
              : _currentIndex == 1
                  ? 'Tus Favoritos'
                  : 'Descargas Offline',
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
          Expanded(child: pages[_currentIndex]),
          if (_currentTrack != null) _buildMiniPlayer(),
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
          BottomNavigationBarItem(
            icon: const Icon(Icons.download_done_rounded),
            label: 'Offline (${_downloadedTracks.length})',
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer() {
    final double maxSeconds = _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0;
    final double currentSeconds = _position.inSeconds.toDouble().clamp(0.0, maxSeconds);

    return GestureDetector(
      onTap: _openExpandedPlayer,
      child: Container(
        color: const Color(0xFF222222),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                activeTrackColor: widget.primaryColor,
                inactiveTrackColor: Colors.grey[800],
                thumbColor: widget.primaryColor,
              ),
              child: Slider(
                value: currentSeconds,
                min: 0.0,
                max: maxSeconds,
                onChanged: (value) => _audioPlayer.seek(Duration(seconds: value.toInt())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6.0),
                    child: Image.network(
                      _currentTrack?['artworkUrl100'] ?? '',
                      width: 38,
                      height: 38,
                      fit: BoxFit.cover,
                      errorBuilder: (c, o, s) => const Icon(Icons.music_note, size: 28),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentTrack?['trackName'] ?? 'Sin título',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _currentTrack?['artistName'] ?? 'Artista desconocido',
                          style: const TextStyle(color: Colors.grey, fontSize: 9),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: Colors.white, size: 22),
                    onPressed: _playPreviousTrack,
                  ),
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      color: widget.primaryColor,
                      size: 32,
                    ),
                    onPressed: () => _playTrack(_currentTrack!),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white, size: 22),
                    onPressed: _playNextTrack,
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

class SearchTab extends StatefulWidget {
  final Color primaryColor;
  final Function(Map<String, dynamic>, List<dynamic>, int) onTrackSelected;
  final String? currentTrackUrl;
  final bool isPlaying;
  final Function(Map<String, dynamic>) onToggleFavorite;
  final bool Function(Map<String, dynamic>) isFavorite;
  final Function(Map<String, dynamic>) onDownload;

  const SearchTab({
    super.key,
    required this.primaryColor,
    required this.onTrackSelected,
    this.currentTrackUrl,
    required this.isPlaying,
    required this.onToggleFavorite,
    required this.isFavorite,
    required this.onDownload,
  });

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _tracks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchTracks('rock');
  }

  Future<void> _searchTracks(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);

    final url = Uri.parse(
      'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&media=music&limit=25',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _tracks = data['results'] ?? [];
        });
      }
    } catch (e) {
      // Manejo silencioso
    } finally {
      setState(() => _isLoading = false);
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
              hintText: 'Buscar artista o canción...',
              prefixIcon: Icon(Icons.search, color: widget.primaryColor),
              suffixIcon: IconButton(
                icon: Icon(Icons.send, color: widget.primaryColor),
                onPressed: () => _searchTracks(_searchController.text),
              ),
              filled: true,
              fillColor: const Color(0xFF2C2C2C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (value) => _searchTracks(value),
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: widget.primaryColor))
              : _tracks.isEmpty
                  ? const Center(child: Text('No se encontraron resultados'))
                  : ListView.builder(
                      itemCount: _tracks.length,
                      itemBuilder: (context, index) {
                        final track = _tracks[index];
                        final previewUrl = track['previewUrl'] ?? '';
                        final isSelected = widget.currentTrackUrl == previewUrl && widget.isPlaying;
                        final isFav = widget.isFavorite(track);

                        return Card(
                          color: const Color(0xFF1E1E1E),
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.network(
                                track['artworkUrl100'] ?? '',
                                width: 45,
                                height: 45,
                                fit: BoxFit.cover,
                                errorBuilder: (c, o, s) => const Icon(Icons.music_note, size: 30),
                              ),
                            ),
                            title: Text(
                              track['trackName'] ?? 'Sin título',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              track['artistName'] ?? 'Artista desconocido',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.download, color: Colors.grey, size: 20),
                                  onPressed: () => widget.onDownload(track),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isFav ? Icons.favorite : Icons.favorite_border,
                                    color: isFav ? Colors.redAccent : Colors.grey,
                                    size: 20,
                                  ),
                                  onPressed: () => widget.onToggleFavorite(track),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isSelected ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                    color: widget.primaryColor,
                                    size: 32,
                                  ),
                                  onPressed: () => widget.onTrackSelected(track, _tracks, index),
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
  final Function(Map<String, dynamic>, List<dynamic>, int) onTrackSelected;
  final String? currentTrackUrl;
  final bool isPlaying;
  final Function(Map<String, dynamic>) onToggleFavorite;

  const FavoritesTab({
    super.key,
    required this.primaryColor,
    required this.favorites,
    required this.onTrackSelected,
    this.currentTrackUrl,
    required this.isPlaying,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      return const Center(
        child: Text(
          'Aún no has agregado canciones a favoritos.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final track = favorites[index];
        final previewUrl = track['previewUrl'] ?? '';
        final isSelected = currentTrackUrl == previewUrl && isPlaying;

        return Card(
          color: const Color(0xFF1E1E1E),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                track['artworkUrl100'] ?? '',
                width: 45,
                height: 45,
                fit: BoxFit.cover,
                errorBuilder: (c, o, s) => const Icon(Icons.music_note, size: 30),
              ),
            ),
            title: Text(
              track['trackName'] ?? 'Sin título',
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              track['artistName'] ?? 'Artista desconocido',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
                  onPressed: () => onToggleFavorite(track),
                ),
                IconButton(
                  icon: Icon(
                    isSelected ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: primaryColor,
                    size: 32,
                  ),
                  onPressed: () => onTrackSelected(track, favorites, index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DownloadsTab extends StatelessWidget {
  final Color primaryColor;
  final List<Map<String, dynamic>> downloadedTracks;
  final Function(Map<String, dynamic>, List<dynamic>, int) onTrackSelected;
  final String? currentTrackPath;
  final bool isPlaying;
  final Function(Map<String, dynamic>) onDelete;

  const DownloadsTab({
    super.key,
    required this.primaryColor,
    required this.downloadedTracks,
    required this.onTrackSelected,
    this.currentTrackPath,
    required this.isPlaying,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (downloadedTracks.isEmpty) {
      return const Center(
        child: Text(
          'No tienes canciones descargadas.\nToca el icono 📥 en la lista para bajar alguna.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: downloadedTracks.length,
      itemBuilder: (context, index) {
        final track = downloadedTracks[index];
        final localPath = track['localPath'] ?? '';
        final isSelected = currentTrackPath == localPath && isPlaying;

        return Card(
          color: const Color(0xFF1E1E1E),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                track['artworkUrl100'] ?? '',
                width: 45,
                height: 45,
                fit: BoxFit.cover,
                errorBuilder: (c, o, s) => const Icon(Icons.music_note, size: 30),
              ),
            ),
            title: Text(
              track['trackName'] ?? 'Sin título',
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: const Text('Descargado (Offline)', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                  onPressed: () => onDelete(track),
                ),
                IconButton(
                  icon: Icon(
                    isSelected ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: primaryColor,
                    size: 32,
                  ),
                  onPressed: () => onTrackSelected(track, downloadedTracks, index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
