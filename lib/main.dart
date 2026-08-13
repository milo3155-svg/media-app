import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:just_audio/just_audio.dart';

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

  // Lista de Favoritos guardada en memoria
  final List<Map<String, dynamic>> _favorites = [];

  // Calidad de Audio (Alta / Ahorro)
  String _audioQuality = 'Alta';

  // Estado del reproductor
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
          }
        });
      }
    });

    _player.positionStream.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
        });
      }
    });

    _player.durationStream.listen((dur) {
      if (mounted) {
        setState(() {
          _duration = dur ?? Duration.zero;
        });
      }
    });
  }

  Future<void> _playTrack(Map<String, dynamic> track) async {
    final previewUrl = track['previewUrl'] ?? '';
    if (previewUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin vista previa de audio')),
      );
      return;
    }

    try {
      if (_currentTrack?['previewUrl'] == previewUrl) {
        if (_isPlaying) {
          await _player.pause();
        } else {
          await _player.play();
        }
      } else {
        setState(() {
          _currentTrack = track;
        });
        await _player.setUrl(previewUrl);
        await _player.play();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al reproducir audio')),
      );
    }
  }

  void _toggleFavorite(Map<String, dynamic> track) {
    final trackId = track['trackId'] ?? track['previewUrl'];
    setState(() {
      final exists = _favorites.any((t) => (t['trackId'] ?? t['previewUrl']) == trackId);
      if (exists) {
        _favorites.removeWhere((t) => (t['trackId'] ?? t['previewUrl']) == trackId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removido de Favoritos')),
        );
      } else {
        _favorites.add(track);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agregado a Favoritos ❤️')),
        );
      }
    });
  }

  bool _isFavorite(Map<String, dynamic> track) {
    final trackId = track['trackId'] ?? track['previewUrl'];
    return _favorites.any((t) => (t['trackId'] ?? t['previewUrl']) == trackId);
  }

  void _seekRelative(int seconds) {
    final newPosition = _position + Duration(seconds: seconds);
    if (newPosition < Duration.zero) {
      _player.seek(Duration.zero);
    } else if (newPosition > _duration) {
      _player.seek(_duration);
    } else {
      _player.seek(newPosition);
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
        onTrackSelected: _playTrack,
        currentTrackUrl: _currentTrack?['previewUrl'],
        isPlaying: _isPlaying,
        onToggleFavorite: _toggleFavorite,
        isFavorite: _isFavorite,
      ),
      FavoritesTab(
        favorites: _favorites,
        onTrackSelected: _playTrack,
        currentTrackUrl: _currentTrack?['previewUrl'],
        isPlaying: _isPlaying,
        onToggleFavorite: _toggleFavorite,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Media App - Música' : 'Tus Favoritos'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1F1F1F),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings, color: Colors.purpleAccent),
            onSelected: (val) {
              setState(() {
                _audioQuality = val;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Calidad de audio ajustada a: $val')),
              );
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'Alta (HQ)',
                child: Row(
                  children: [
                    Icon(Icons.high_quality, color: _audioQuality == 'Alta (HQ)' ? Colors.purpleAccent : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Alta Calidad (320kbps)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Ahorro de datos',
                child: Row(
                  children: [
                    Icon(Icons.data_saver_on, color: _audioQuality == 'Ahorro de datos' ? Colors.purpleAccent : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Ahorro de Datos (128kbps)'),
                  ],
                ),
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
        selectedItemColor: Colors.purpleAccent,
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF1F1F1F),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Buscar',
          ),
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

  // Reproductor Flotante Completo con Controles +10s / -10s
  Widget _buildMiniPlayer() {
    final double maxSeconds = _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0;
    final double currentSeconds = _position.inSeconds.toDouble().clamp(0.0, maxSeconds);
    final isFav = _isFavorite(_currentTrack!);

    return Container(
      color: const Color(0xFF222222),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
              activeTrackColor: Colors.purpleAccent,
              inactiveTrackColor: Colors.grey[800],
              thumbColor: Colors.purpleAccent,
            ),
            child: Slider(
              value: currentSeconds,
              min: 0.0,
              max: maxSeconds,
              onChanged: (value) {
                _player.seek(Duration(seconds: value.toInt()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6.0),
                  child: Image.network(
                    _currentTrack?['artworkUrl100'] ?? '',
                    width: 45,
                    height: 45,
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _currentTrack?['artistName'] ?? 'Artista desconocido',
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Botón -10s
                IconButton(
                  icon: const Icon(Icons.replay_10, color: Colors.white, size: 24),
                  onPressed: () => _seekRelative(-10),
                ),
                // Play / Pausa
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: Colors.purpleAccent,
                    size: 34,
                  ),
                  onPressed: () => _playTrack(_currentTrack!),
                ),
                // Botón +10s
                IconButton(
                  icon: const Icon(Icons.forward_10, color: Colors.white, size: 24),
                  onPressed: () => _seekRelative(10),
                ),
                // Botón Favorito en mini player
                IconButton(
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? Colors.redAccent : Colors.grey,
                    size: 22,
                  ),
                  onPressed: () => _toggleFavorite(_currentTrack!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Pestaña de Búsqueda
class SearchTab extends StatefulWidget {
  final Function(Map<String, dynamic>) onTrackSelected;
  final String? currentTrackUrl;
  final bool isPlaying;
  final Function(Map<String, dynamic>) onToggleFavorite;
  final bool Function(Map<String, dynamic>) isFavorite;

  const SearchTab({
    super.key,
    required this.onTrackSelected,
    this.currentTrackUrl,
    required this.isPlaying,
    required this.onToggleFavorite,
    required this.isFavorite,
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
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (c, o, s) => const Icon(Icons.music_note, size: 40),
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
                                  icon: Icon(
                                    isFav ? Icons.favorite : Icons.favorite_border,
                                    color: isFav ? Colors.redAccent : Colors.grey,
                                  ),
                                  onPressed: () => widget.onToggleFavorite(track),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isSelected ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                    color: Colors.purpleAccent,
                                    size: 34,
                                  ),
                                  onPressed: () => widget.onTrackSelected(track),
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

// Pestaña de Favoritos
class FavoritesTab extends StatelessWidget {
  final List<Map<String, dynamic>> favorites;
  final Function(Map<String, dynamic>) onTrackSelected;
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
          'Aún no has agregado canciones a tus favoritos.\nToca el ❤️ en cualquier canción.',
          textAlign: TextAlign.center,
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
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (c, o, s) => const Icon(Icons.music_note, size: 40),
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
                  icon: const Icon(Icons.favorite, color: Colors.redAccent),
                  onPressed: () => onToggleFavorite(track),
                ),
                IconButton(
                  icon: Icon(
                    isSelected ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: Colors.purpleAccent,
                    size: 34,
                  ),
                  onPressed: () => onTrackSelected(track),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
