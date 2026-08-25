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

  // Lista de servidores independientes de respaldo automático
  static const List<String> _pipedInstances = [
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.syncpundit.io',
    'https://piped-api.privacy.com.de',
    'https://api.piped.projectsegfau.lt',
  ];

  static Future<String?> getAudioUrl(String videoId) async {
    // Probamos cada servidor en orden hasta que uno responda con éxito
    for (String instance in _pipedInstances) {
      try {
        final url = Uri.parse('$instance/streams/$videoId');
        final response = await http.get(url).timeout(const Duration(seconds: 4));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final audioStreams = data['audioStreams'] as List;
          
          if (audioStreams.isNotEmpty) {
            return audioStreams[0]['url'];
          }
        }
      } catch (e) {
        // Si un servidor falla, pasa silenciosamente al siguiente
        continue; 
      }
    }
    
    // Si los servidores externos fallan, intentamos el método nativo como última carta
    try {
      var manifest = await _yt.videos.streamsClient.getManifest(videoId);
      var audioStream = manifest.audioOnly.withHighestBitrate();
      return audioStream.url.toString();
    } catch (e) {
      throw Exception("Bloqueo total de YouTube en todas las rutas.");
    }
  }
}
