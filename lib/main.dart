import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MediaApp());
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Media App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.purpleAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.purpleAccent,
          secondary: Colors.purpleAccent,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final AudioPlayer _player = AudioPlayer();

  final List<Map<String, dynamic>> _favorites = [];
  final List<Map<String, dynamic>> _downloadedTracks = [];
  List<dynamic> _currentPlaylist = [];
  int _currentTrackIndex = -1;

  Map<String, dynamic>? _currentTrack;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();

    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _position = Duration.zero;
            _playNextTrack(); // Reproducción automática
          }
        });
      }
    });

    _player.positionStream.listen((pos) {
      if (mounted) {
        setState(() => _position = pos);
      }
    });

    _player.durationStream.listen((dur) {
      if (mounted) {
        setState(() => _duration = dur ?? Duration.zero);
      }
    });
  }

  Future<void> _playTrack(Map<String, dynamic> track, {List<dynamic>? playlist, int? index}) async {
    if (playlist != null) {
      _currentPlaylist = playlist;
    }
    if (index != null) {
      _currentTrackIndex = index;
    }

    final audioUrl = track['localPath'] ?? track['previewUrl'] ?? '';
    if (audioUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin audio disponible')),
      );
      return;
    }

    try {
      if (_currentTrack?['previewUrl'] == track['previewUrl'] && _currentTrack?['localPath'] == track['localPath']) {
        if (_isPlaying) {
          await _player.pause();
        } else {
          await _player.play();
        }
      } else {
        setState(() {
          _currentTrack = track;
        });

        if (track['localPath'] != null) {
          await _player.setFilePath(track['localPath']);
        } else {
          await _player.setUrl(audioUrl);
        }
        await _player.play();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al reproducir audio')),
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
  }

  bool _isFavorite(Map<String, dynamic> track) {
    final trackId = track['trackId'] ?? track['previewUrl'];
    return _favorites.any((t) => (t['trackId'] ?? t['previewUrl']) == trackId);
  }

  Future<void> _downloadTrack(Map<String, dynamic> track) async {
    final url = track['previewUrl'];
    if (url == null || url.isEmpty) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Descargando canción...')),
      );

      final dir = await getApplicationDocumentsDirectory();
      final fileName = '${track['trackId'] ?? DateTime.now().millisecondsSinceEpoch}.m4a';
      final filePath = '${dir.path}/$fileName';

      await Dio().download(url, filePath);

      final downloadedTrack = Map<String, dynamic>.from(track);
      downloadedTrack['localPath'] = filePath;

      setState(() {
        _downloadedTracks.add(downloadedTrack);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Descarga completada! 📥')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al descargar')),
      );
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      SearchTab(
        onTrackSelected: (track, playlist, index) => _playTrack(track, playlist: playlist, index: index),
        currentTrackUrl: _currentTrack?['previewUrl'],
        isPlaying: _isPlaying,
        onToggleFavorite: _toggleFavorite,
        isFavorite: _isFavorite,
        onDownload: _downloadTrack,
      ),
      FavoritesTab(
        favorites: _favorites,
        onTrackSelected: (track, playlist, index) => _playTrack(track, playlist: playlist, index: index),
        currentTrackUrl: _currentTrack?['previewUrl'],
        isPlaying: _isPlaying,
        onToggleFavorite: _toggleFavorite,
      ),
      DownloadsTab(
        downloadedTracks: _downloadedTracks,
        onTrackSelected: (track, playlist, index) => _playTrack(track, playlist: playlist, index: index),
        currentTrackPath: _currentTrack?['localPath'],
        isPlaying: _isPlaying,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0
              ? 'Media App - Música'
              : _currentIndex == 1
                  ? 'Tus Favoritos'
                  : 'Descargas Offline',
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1F1F1F),
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
        selectedItemColor: Colors.purpleAccent,
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

    return Container(
      color: const Color(0xFF222222),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
              activeTrackColor: Colors.purpleAccent,
              inactiveTrackColor: Colors.grey[800],
              thumbColor: Colors.purpleAccent,
            ),
            child: Slider(
              value: currentSeconds,
              min: 0.0,
              max: maxSeconds,
              onChanged: (value) => _player.seek(Duration(seconds: value.toInt())),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6.0),
                  child: Image.network(
                    _currentTrack?['artworkUrl100'] ?? '',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (c, o, s) => const Icon(Icons.music_note, size: 30),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentTrack?['trackName'] ?? 'Sin título',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _currentTrack?['artistName'] ?? 'Artista desconocido',
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Botón Anterior ⏮️
                IconButton(
                  icon: const Icon(Icons.skip_previous, color: Colors.white, size: 26),
                  onPressed: _playPreviousTrack,
                ),
                // Play / Pausa ⏯️
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: Colors.purpleAccent,
                    size: 34,
                  ),
                  onPressed: () => _playTrack(_currentTrack!),
                ),
                // Botón Siguiente ⏭️
                IconButton(
                  icon: const Icon(Icons.skip_next, color: Colors.white, size: 26),
                  onPressed: _playNextTrack,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Búsqueda
class SearchTab extends StatefulWidget {
  final Function(Map<String, dynamic>, List<dynamic>, int) onTrackSelected;
  final String? currentTrackUrl;
  final bool isPlaying;
  final Function(Map<String, dynamic>) onToggleFavorite;
  final bool Function(Map<String, dynamic>) isFavorite;
  final Function(Map<String, dynamic>) onDownload;

  const SearchTab({
    super.key,
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
              prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send, color: Colors.purpleAccent),
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
              ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
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
                                  icon: const Icon(Icons.download, color: Colors.grey, size: 22),
                                  onPressed: () => widget.onDownload(track),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isFav ? Icons.favorite : Icons.favorite_border,
                                    color: isFav ? Colors.redAccent : Colors.grey,
                                    size: 22,
                                  ),
                                  onPressed: () => widget.onToggleFavorite(track),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isSelected ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                    color: Colors.purpleAccent,
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

// Favoritos
class FavoritesTab extends StatelessWidget {
  final List<Map<String, dynamic>> favorites;
  final Function(Map<String, dynamic>, List<dynamic>, int) onTrackSelected;
  final String? currentTrackUrl;
  final bool isPlaying;
  final Function(Map<String, dynamic>) onToggleFavorite;

  const FavoritesTab({
    super.key,
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
                  icon: const Icon(Icons.favorite, color: Colors.redAccent, size: 22),
                  onPressed: () => onToggleFavorite(track),
                ),
                IconButton(
                  icon: Icon(
                    isSelected ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: Colors.purpleAccent,
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

// Descargas Offline
class DownloadsTab extends StatelessWidget {
  final List<Map<String, dynamic>> downloadedTracks;
  final Function(Map<String, dynamic>, List<dynamic>, int) onTrackSelected;
  final String? currentTrackPath;
  final bool isPlaying;

  const DownloadsTab({
    super.key,
    required this.downloadedTracks,
    required this.onTrackSelected,
    this.currentTrackPath,
    required this.isPlaying,
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
            trailing: IconButton(
              icon: Icon(
                isSelected ? Icons.pause_circle_filled : Icons.play_circle_fill,
                color: Colors.purpleAccent,
                size: 32,
              ),
              onPressed: () => onTrackSelected(track, downloadedTracks, index),
            ),
          ),
        );
      },
    );
  }
}
