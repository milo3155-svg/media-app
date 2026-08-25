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
      return [{'title': 'Error interno', 'author': e.toString()}];
    }
  }

  static Future<String?> getAudioUrl(String videoId) async {
    try {
      var manifest = await _yt.videos.streamsClient.getManifest(videoId);
      // Tomamos el audio de mayor calidad sin discriminar formato (.webm o .mp4)
      var streamInfo = manifest.audioOnly.withHighestBitrate();
      return streamInfo.url.toString();
    } catch (e) {
      print("Error extrayendo URL: $e");
      return null;
    }
  }
}
