import 'package0:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
        primaryColor: Colors.deepPurple,
      ),
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
  List<dynamic> _tracks = [];
  bool _isLoading = false;

  final String _clientId = '5672a80f';

  @override
  void initState() {
    super.initState();
    _searchTracks('rock');
  }

  Future<void> _searchTracks(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    // Usamos namesearch que es el parametro oficial de Jamendo para buscar por texto
    final url = Uri.parse(
      'https://api.jamendo.com/v3.0/tracks/?client_id=$_clientId&format=json&limit=20&namesearch=${Uri.encodeComponent(query)}',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _tracks = data['results'] ?? [];
        });
      } else {
        _showSnackBar('Error al consultar Jamendo (Código: ${response.statusCode})');
      }
    } catch (e) {
      _showSnackBar('Error de conexión: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media App - Jamendo'),
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
                hintText: 'Buscar artista, canción o género...',
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

                          return Card(
                            color: const Color(0xFF1E1E1E),
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.network(
                                  track['album_image'] ?? '',
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.music_note, size: 40),
                                ),
                              ),
                              title: Text(
                                track['name'] ?? 'Sin título',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                track['artist_name'] ?? 'Artista desconocido',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(
                                Icons.music_note,
                                color: Colors.purpleAccent,
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
