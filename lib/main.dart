import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  AudioPlayer.global.setAudioContext(AudioContextConfig(
    route: AudioContextConfigRoute.system,
    respectSilence: false,
    duckAudio: false,
  ).build());

  runApp(const MediaApp());
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Media App',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
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
  final YoutubeExplode _yt = YoutubeExplode();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _searchController = TextEditingController();

  List<Video> _searchResults = [];
  bool _isLoading = false;
  String _currentTitle = "Listo para buscar";
  String _errorMessage = "";
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    // Escuchar el estado del reproductor para cambiar el botón de Play/Pause automáticamente
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  void _search(String query) async {
    if (query.trim().isEmpty) return;
    
    // Ocultar teclado
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _searchResults.clear();
      _errorMessage = "";
    });

    try {
      var results = await _yt.search.search(query);
      setState(() {
        _searchResults = results.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Fallo de conexión: $e";
      });
    }
  }

  void _playAudio(Video video) async {
    setState(() {
      _currentTitle = "Cargando audio...";
      _errorMessage = "";
    });

    try {
      var manifest = await _yt.videos.streamsClient.getManifest(video.id);
      var audioStream = manifest.audioOnly.withHighestBitrate();

      await _audioPlayer.stop(); // Detener el anterior por si acaso
      await _audioPlayer.setSourceUrl(audioStream.url.toString());
      await _audioPlayer.resume();

      setState(() {
        _currentTitle = video.title;
      });
    } catch (e) {
      setState(() {
        _currentTitle = "Video bloqueado por YouTube";
        _errorMessage = e.toString(); // Aquí veremos el error técnico real
      });
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.resume();
    }
  }

  @override
  void dispose() {
    _yt.close();
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media App Search'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar canción o video...',
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: _search,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  child: IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () => _search(_searchController.text),
                  ),
                ),
              ],
            ),
          ),
          
          // Mensaje de error (si existe)
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            
          // Lista de resultados
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      var video = _searchResults[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(video.thumbnails.lowResUrl, width: 80, fit: BoxFit.cover),
                        ),
                        title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(video.author, style: TextStyle(color: Colors.grey[400])),
                        onTap: () => _playAudio(video),
                      );
                    },
                  ),
          ),
          
          // NUEVA INTERFAZ: Mini Reproductor Inferior
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.deepPurple.shade900,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _currentTitle,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 32),
                  onPressed: _togglePlayPause,
                ),
                IconButton(
                  icon: const Icon(Icons.stop, color: Colors.white, size: 32),
                  onPressed: () {
                    _audioPlayer.stop();
                    setState(() {
                      _currentTitle = "Detenido";
                    });
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
