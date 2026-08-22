import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  // Configuración de audio sin el parámetro 'focus'
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
  String _currentTitle = "Esperando búsqueda...";

  void _search(String query) async {
    if (query.trim().isEmpty) return;
    
    // Ocultar el teclado en móviles al buscar
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _searchResults.clear();
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
        _currentTitle = "Error en la búsqueda";
      });
    }
  }

  void _playAudio(Video video) async {
    setState(() {
      _currentTitle = "Cargando: ${video.title}";
    });

    try {
      var manifest = await _yt.videos.streamsClient.getManifest(video.id);
      var audioStream = manifest.audioOnly.withHighestBitrate();

      await _audioPlayer.setSourceUrl(audioStream.url.toString());
      await _audioPlayer.resume();

      setState(() {
        _currentTitle = "🎵 Reproduciendo: ${video.title}";
      });
    } catch (e) {
      setState(() {
        _currentTitle = "Error al reproducir video protegido";
      });
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Text(
              _currentTitle,
              style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.stop),
        onPressed: () {
          _audioPlayer.stop();
          setState(() {
            _currentTitle = "Detenido";
          });
        },
      ),
    );
  }
}
