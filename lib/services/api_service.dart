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
      var manifest = await _yt.videos.streamsClient.getManifest(videoId);
      
      // EL TRUCO VITAL: Forzar el contenedor mp4 para evitar el colapso de ExoPlayer en Android
      var audioStreams = manifest.audioOnly.where((stream) => stream.container.name == 'mp4');
      
      if (audioStreams.isNotEmpty) {
        return audioStreams.withHighestBitrate().url.toString();
      } else {
        // Si por algún milagro no hay mp4, tomamos lo que haya
        return manifest.audioOnly.withHighestBitrate().url.toString();
      }
    } catch (e) {
      throw Exception("Fallo nativo: $e");
    }
  }
}
