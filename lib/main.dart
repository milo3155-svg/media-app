import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart'; // ¡Aquí activamos el audio!

void main() {
  runApp(const MediaApp());
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iTunes Music',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF121212)),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer(); // Nuestro reproductor
  List<dynamic> _tracks = [];
  bool _isLoading = false;

  Future<void> _playPreview(String url) async {
    await _audioPlayer.stop(); // Detiene cualquier audio anterior
    await _audioPlayer.play(UrlSource(url)); // Reproduce la muestra de 30s
  }

  Future<void> _searchTracks(String query) async {
    if (query.trim().isEmpty) return;
    setState(() { _isLoading = true; });

    final url = Uri.parse('https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&media=music&limit=25');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() { _tracks = data['results'] ?? []; });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de conexión')));
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('iTunes Music'), centerTitle: true, backgroundColor: const Color(0xFF1F1F1F)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(hintText: 'Buscar...', suffixIcon: IconButton(icon: const Icon(Icons.send), onPressed: () => _searchTracks(_searchController.text))),
              onSubmitted: _searchTracks,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _tracks.length,
              itemBuilder: (context, index) {
                final track = _tracks[index];
                return Card(
                  color: const Color(0xFF1E1E1E),
                  child: ListTile(
                    leading: Image.network(track['artworkUrl60'] ?? ''),
                    title: Text(track['trackName'] ?? 'Sin nombre'),
                    subtitle: Text(track['artistName'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_circle_fill, color: Colors.purpleAccent, size: 36),
                      onPressed: () => _playPreview(track['previewUrl'] ?? ''),
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
