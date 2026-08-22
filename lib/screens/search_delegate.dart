import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/music_provider.dart';

class VideoSearchDelegate extends SearchDelegate {
  @override
  String get searchFieldLabel => 'Buscar música, artistas...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      appBarTheme: const AppBarTheme(backgroundColor: Colors.deepPurple),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white54),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear, color: Colors.white),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return Container(
        color: const Color(0xFF121212),
        child: const Center(
          child: Text('Escribe algo para buscar...', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return Container(
      color: const Color(0xFF121212),
      child: FutureBuilder<List<dynamic>>(
        future: ApiService.search(query),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No se encontraron resultados', style: TextStyle(color: Colors.grey)));
          }

          final results = snapshot.data!;

          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final item = results[index];
              if (item['type'] != 'video') return const SizedBox.shrink();

              final title = item['title'] ?? 'Sin título';
              final author = item['author'] ?? 'Desconocido';
              final thumb = (item['videoThumbnails'] != null && item['videoThumbnails'].isNotEmpty)
                  ? item['videoThumbnails'][0]['url']
                  : '';

              return ListTile(
                contentPadding: const EdgeInsets.all(8.0),
                leading: thumb.isNotEmpty 
                    ? Image.network(thumb, width: 80, height: 60, fit: BoxFit.cover)
                    : Container(width: 80, height: 60, color: Colors.grey),
                title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                subtitle: Text(author, style: const TextStyle(color: Colors.grey)),
                onTap: () {
                  context.read<MusicProvider>().setTrack(title);
                  close(context, null);
                },
              );
            },
          );
        },
      ),
    );
  }
}
