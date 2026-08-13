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

  // Estado del reproductor
  Map<String, dynamic>? _currentTrack;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();

    // Escuchar el estado de reproducción
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

    // Escuchar la posición actual de la canción
    _player.positionStream.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
        });
      }
    });

    // Escuchar la duración total del audio
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
      ),
      const FavoritesTab(),
    ];

    return Scaffold(
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Buscar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favoritos',
          ),
        ],
      ),
    );
  }

  // Reproductor inferior flotante
  Widget _buildMiniPlayer() {
    final double maxSeconds = _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0;
    final double currentSeconds = _position.inSeconds.toDouble().clamp(0.0, maxSeconds);

    return Container(
      color: const Color(0xFF222222),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de progreso desizable
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
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentTrack?['trackName'] ?? 'Sin título',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _currentTrack?['artistName'] ?? 'Artista desconocido',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: Colors.purpleAccent,
                    size: 36,
                  ),
                  onPressed: () => _playTrack(_currentTrack!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

// Pestana de Búsqueda
class SearchTab extends StatefulWidget {
  final Function(Map<String, dynamic>) onTrackSelected;
  final String? currentTrackUrl;
  final bool isPlaying;

  const SearchTab({
    super.key,
    required this.onTrackSelected,
    this.currentTrackUrl,
    required this.isPlaying,
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
      // Manejar error silenciosamente
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media App - iTunes'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1F1F1F),
      ),
      body: Column(
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
                              trailing: IconButton(
                                icon: Icon(
                                  isSelected ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                  color: Colors.purpleAccent,
                                  size: 36,
                                ),
                                onPressed: () => widget.onTrackSelected(track),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// Pestaña de Favoritos (Estructura lista para el siguiente paso)
class FavoritesTab extends StatelessWidget {
  const FavoritesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoritos'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1F1F1F),
      ),
      body: const Center(
        child: Text(
          'Aún no has agregado canciones a tus favoritos.',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
