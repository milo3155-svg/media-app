import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

late MyAudioHandler _audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.media_app.channel.audio',
      androidNotificationChannelName: 'Media Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  runApp(const MediaApp());
}

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  VoidCallback? onTrackEnded;

  MyAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (onTrackEnded != null) {
          onTrackEnded!();
        }
      }
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
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
      queueIndex: event.currentIndex,
    ));
  }

  Future<void> playStream(String url, MediaItem item) async {
    mediaItem.add(item);
    await _player.setUrl(url);
    await _player.play();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  AudioPlayer get player => _player;
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
        Permission.audio,
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
  List<Map<String, dynamic>> _playlist = [];
  int _currentTrackIndex = -1;

  Map<String, dynamic>? _currentTrack;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadSavedData();

    _audioHandler.onTrackEnded = _playNextTrack;

    _audioHandler.playbackState.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    _audioHandler.player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _audioHandler.player.durationStream.listen((dur) {
      if (mounted) setState(() => _duration = dur ?? Duration.zero);
    });
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

  Future<void> _playTrack(Map<String, dynamic> track, {List<Map<String, dynamic>>? currentList, int? index}) async {
    if (currentList != null) _playlist = currentList;
    if (index != null) _currentTrackIndex = index;

    try {
      if (_currentTrack?['id'] == track['id']) {
        if (_isPlaying) {
          await _audioHandler.pause();
        } else {
          await _audioHandler.play();
        }
        return;
      }

      setState(() {
        _currentTrack = track;
      });

      final mediaItem = MediaItem(
        id: track['id'] ?? '0',
        title: track['title'] ?? 'Sin título',
        artist: track['artist'] ?? 'Artista desconocido',
        artUri: Uri.tryParse(track['thumbnail'] ?? ''),
        duration: track['duration'] != null ? Duration(seconds: track['duration']) : null,
      );

      final streamUrl = 'https://discoveryprovider.audius.co/v1/tracks/${track['id']}/stream?app_name=MediaApp';
      await _audioHandler.playStream(streamUrl, mediaItem);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al reproducir pista')),
      );
    }
  }

  void _playNextTrack() {
    if (_playlist.isNotEmpty && _currentTrackIndex < _playlist.length - 1) {
      _currentTrackIndex++;
      _playTrack(_playlist[_currentTrackIndex], index: _currentTrackIndex);
    }
  }

  void _playPreviousTrack() {
    if (_playlist.isNotEmpty && _currentTrackIndex > 0) {
      _currentTrackIndex--;
      _playTrack(_playlist[_currentTrackIndex], index: _currentTrackIndex);
    }
  }

  void _toggleFavorite(Map<String, dynamic> track) {
    final trackId = track['id'];
    setState(() {
      final exists = _favorites.any((t) => t['id'] == trackId);
      if (exists) {
        _favorites.removeWhere((t) => t['id'] == trackId);
      } else {
        _favorites.add(track);
      }
    });
    _saveLocalData();
  }

  bool _isFavorite(Map<String, dynamic> track) {
    final trackId = track['id'];
    return _favorites.any((t) => t['id'] == trackId);
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
            final isFav = _currentTrack != null && _isFavorite(_currentTrack!);

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
                      const Text('Reproduciendo en vivo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.redAccent : Colors.white,
                        ),
                        onPressed: () {
                          if (_currentTrack != null) {
                            _toggleFavorite(_currentTrack!);
                            setModalState(() {});
                          }
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
                        _currentTrack?['thumbnail'] ?? '',
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
                          _currentTrack?['title'] ?? 'Sin título',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentTrack?['artist'] ?? 'Artista desconocido',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
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
                            onChanged: (value) => _audioHandler.seek(Duration(seconds: value.toInt())),
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
                        icon: const Icon(Icons.skip_previous, size: 36, color: Colors.white),
                        onPressed: () {
                          _playPreviousTrack();
                          setModalState(() {});
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                          size: 68,
                          color: widget.primaryColor,
                        ),
                        onPressed: () {
                          if (_currentTrack != null) {
                            _playTrack(_currentTrack!);
                            setModalState(() {});
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next, size: 36, color: Colors.white),
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
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      SearchTab(
        primaryColor: widget.primaryColor,
        onTrackSelected: (track, list, idx) => _playTrack(track, currentList: list, index: idx),
        currentTrackId: _currentTrack?['id'],
        isPlaying: _isPlaying,
        onToggleFavorite: _toggleFavorite,
        isFavorite: _isFavorite,
      ),
      FavoritesTab(
        primaryColor: widget.primaryColor,
        favorites: _favorites,
        onTrackSelected: (track, list, idx) => _playTrack(track, currentList: list, index: idx),
        currentTrackId: _currentTrack?['id'],
        isPlaying: _isPlaying,
        onToggleFavorite: _toggleFavorite,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0 ? 'Media App' : 'Tus Favoritos',
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
                onChanged: (value) => _audioHandler.seek(Duration(seconds: value.toInt())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6.0),
                    child: Image.network(
                      _currentTrack?['thumbnail'] ?? '',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (c, o, s) => const Icon(Icons.music_note, size: 28),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentTrack?['title'] ?? 'Sin título',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _currentTrack?['artist'] ?? 'Artista desconocido',
                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      color: widget.primaryColor,
                      size: 36,
                    ),
                    onPressed: () => _playTrack(_currentTrack!),
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
  final Function(Map<String, dynamic>, List<Map<String, dynamic>>, int) onTrackSelected;
  final String? currentTrackId;
  final bool isPlaying;
  final Function(Map<String, dynamic>) onToggleFavorite;
  final bool Function(Map<String, dynamic>) isFavorite;

  const SearchTab({
    super.key,
    required this.primaryColor,
    required this.onTrackSelected,
    this.currentTrackId,
    required this.isPlaying,
    required this.onToggleFavorite,
    required this.isFavorite,
  });

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _tracks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchTrendingTracks();
  }

  Future<void> _fetchTrendingTracks() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('https://discoveryprovider.audius.co/v1/tracks/trending?app_name=MediaApp&limit=25'),
      );
      _parseResponse(res);
    } catch (_) {
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchTracks(String query) async {
    if (query.trim().isEmpty) {
      _fetchTrendingTracks();
      return;
    }
    setState(() => _isLoading = true);

    try {
      final res = await http.get(
        Uri.parse('https://discoveryprovider.audius.co/v1/tracks/search?query=${Uri.encodeComponent(query)}&app_name=MediaApp&limit=25'),
      );
      _parseResponse(res);
    } catch (_) {
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _parseResponse(http.Response res) {
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final items = data['data'] as List?;
      if (items != null) {
        setState(() {
          _tracks = items.map((item) {
            final artwork = item['artwork']?['150x150'] ?? item['artwork']?['480x480'] ?? '';
            return {
              'id': item['id'] ?? '',
              'title': item['title'] ?? 'Sin título',
              'artist': item['user']?['name'] ?? 'Artista Audius',
              'thumbnail': artwork,
              'duration': item['duration'],
            };
          }).toList();
        });
      }
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
              hintText: 'Buscar canciones, artistas o géneros...',
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
                  ? const Center(child: Text('No se encontraron canciones'))
                  : ListView.builder(
                      itemCount: _tracks.length,
                      itemBuilder: (context, index) {
                        final track = _tracks[index];
                        final isSelected = widget.currentTrackId == track['id'] && widget.isPlaying;
                        final isFav = widget.isFavorite(track);

                        return Card(
                          color: const Color(0xFF1E1E1E),
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.network(
                                track['thumbnail'] ?? '',
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (c, o, s) => const Icon(Icons.music_note, size: 30),
                              ),
                            ),
                            title: Text(
                              track['title'] ?? 'Sin título',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              track['artist'] ?? 'Artista desconocido',
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
                                  onPressed: () => widget.onToggleFavorite(track),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isSelected ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                    color: widget.primaryColor,
                                    size: 34,
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
  final Function(Map<String, dynamic>, List<Map<String, dynamic>>, int) onTrackSelected;
  final String? currentTrackId;
  final bool isPlaying;
  final Function(Map<String, dynamic>) onToggleFavorite;

  const FavoritesTab({
    super.key,
    required this.primaryColor,
    required this.favorites,
    required this.onTrackSelected,
    this.currentTrackId,
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
        final isSelected = currentTrackId == track['id'] && isPlaying;

        return Card(
          color: const Color(0xFF1E1E1E),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                track['thumbnail'] ?? '',
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (c, o, s) => const Icon(Icons.music_note, size: 30),
              ),
            ),
            title: Text(
              track['title'] ?? 'Sin título',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              track['artist'] ?? 'Artista desconocido',
              style: const TextStyle(fontSize: 11),
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
                    size: 34,
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
