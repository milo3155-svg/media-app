import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class ApiService {
  static final _yt = YoutubeExplode();

  // 1. Mantenemos YoutubeExplode para las búsquedas (es el más rápido)
  static Future<List<dynamic>> search(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      var videos = await _yt.search.getVideos(query);
      List<dynamic> formattedResults = [];
      
      for (var video in videos.take(15)) {
        formattedResults.add({
          'id': video.id.value,
          'title': video.title,
          'author': video.author,
        });
      }
      return formattedResults.isNotEmpty ? formattedResults : [{'title': 'Sin resultados', 'author': ''}];
    } catch (e) {
      return [{'title': 'Error de búsqueda', 'author': e.toString()}];
    }
  }

  // 2. NUEVA ESTRATEGIA: Usamos una API externa (Piped) solo para obtener el enlace limpio del audio
  static Future<String?> getAudioUrl(String videoId) async {
    try {
      // Pedimos los enlaces a un servidor proxy público que burla el bloqueo 403
      final url = Uri.parse('https://pipedapi.kavin.rocks/streams/$videoId');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final audioStreams = data['audioStreams'] as List;
        
        if (audioStreams.isNotEmpty) {
          // Tomamos el primer stream de audio disponible (suele ser formato m4a nativo para Android)
          return audioStreams[0]['url'];
        }
      }
      return null;
    } catch (e) {
      print("Error en extracción híbrida: $e");
      return null;
    }
  }
}
