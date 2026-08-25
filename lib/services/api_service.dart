import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class ApiService {
  static final _yt = YoutubeExplode();

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

  static Future<String?> getAudioUrl(String videoId) async {
    final url = Uri.parse('https://pipedapi.syncpundit.io/streams/$videoId');
    
    final response = await http.get(url);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final audioStreams = data['audioStreams'] as List;
      
      if (audioStreams.isNotEmpty) {
        return audioStreams[0]['url'];
      } else {
        throw Exception("El servidor no encontró pistas de audio");
      }
    } else {
      throw Exception("El servidor rechazó la conexión (Error ${response.statusCode})");
    }
  }
}
