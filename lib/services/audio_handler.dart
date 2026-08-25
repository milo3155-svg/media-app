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
      
      if (formattedResults.isNotEmpty) {
        return formattedResults;
      }
      return [{'title': 'Sin resultados', 'author': 'Intenta otra búsqueda'}];
    } catch (e) {
      return [{'title': 'Error interno', 'author': e.toString()}];
    }
  }

  static Future<String?> getAudioUrl(String videoId) async {
    try {
      var manifest = await _yt.videos.streamsClient.getManifest(videoId);
      
      // ¡EL TRUCO! Filtramos específicamente por el contenedor mp4/m4a
      // Android maneja esto nativamente y evita errores de decodificación.
      var audioStreams = manifest.audioOnly.where((stream) => stream.container.name == 'mp4');
      
      if (audioStreams.isEmpty) {
        audioStreams = manifest.audioOnly; // Respaldo de emergencia
      }
      
      var streamInfo = audioStreams.withHighestBitrate();
      return streamInfo.url.toString();
    } catch (e) {
      print("Error al extraer audio: $e");
      return null;
    }
  }
}
