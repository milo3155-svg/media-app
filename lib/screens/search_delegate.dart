import 'package:flutter/material.dart';
import '../services/api_service.dart';

class VideoSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  // Esto se muestra cuando el usuario presiona "Buscar" en el teclado
  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().isEmpty) {
      return const Center(
        child: Text(
          'Escribe algo para buscar',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: ApiService.search(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No se encontraron resultados o falló la red',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final results = snapshot.data!;
        
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final video = results[index];
            return ListTile(
              title: Text(
                video['title'] ?? 'Sin título',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                video['author'] ?? '',
                style: const TextStyle(color: Colors.grey),
              ),
              onTap: () {
                // Aquí manejaremos la reproducción más adelante
                close(context, video['title']);
              },
            );
          },
        );
      },
    );
  }

  // Esto se muestra mientras escribes (evitamos saturar la red haciendo búsquedas aquí)
  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(
      child: Text(
        'Escribe y presiona la lupa o enter en tu teclado para buscar',
        style: TextStyle(color: Colors.grey),
        textAlign: TextAlign.center,
      ),
    );
  }
}
