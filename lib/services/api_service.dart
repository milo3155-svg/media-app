import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class ApiService {
  static final _yt = YoutubeExplode();

  static Future<List<dynamic>> search(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      // Búsqueda directa en YouTube sin intermediarios caídos
      var videos = await _yt.search.getVideos(query);
      
      List<dynamic> formattedResults = [];
      
      // Tomamos los primeros 15 resultados
      for (var video in videos.take(15)) {
        formattedResults.add({
          'title': video.title,
          'author': video.author,
        });
      }
      
      if (formattedResults.isNotEmpty) {
        return formattedResults;
      }
      
      return [
        {
          'title': 'No se encontraron videos',
          'author': 'Intenta con otra búsqueda',
        }
      ];
    } catch (e) {
      return [
        {
          'title': 'Error interno de YoutubeExplode:',
          'author': e.toString(),
        }
      ];
    }
  }
}
