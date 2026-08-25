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
    try {
      // Tu código de oro de la línea 76 de main.dart
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final audioStreams = manifest.audioOnly;
      
      if (audioStreams.isNotEmpty) {
        return audioStreams.withHighestBitrate().url.toString();
      }
      return null;
    } catch (e) {
      throw Exception("Fallo en YoutubeExplode: $e");
    }
  }
}
