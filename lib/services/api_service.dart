import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class ApiService {
  static final _yt = YoutubeExplode();

  // 1. Buscador (ahora captura el ID del video)
  static Future<List<dynamic>> search(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      var videos = await _yt.search.getVideos(query);
      List<dynamic> formattedResults = [];
      
      for (var video in videos.take(15)) {
        formattedResults.add({
          'id': video.id.value, // ¡NUEVO! Vital para poder reproducirlo
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

  // 2. ¡NUEVO MÉTODO! Extrae la URL directa del audio
  static Future<String?> getAudioUrl(String videoId) async {
    try {
      // Obtenemos todos los streams disponibles para este video
      var manifest = await _yt.videos.streamsClient.getManifest(videoId);
      
      // Filtramos para quedarnos SOLO con el audio de mayor calidad
      var streamInfo = manifest.audioOnly.withHighestBitrate();
      
      // Devolvemos la URL pura para que el reproductor la consuma
      return streamInfo.url.toString();
    } catch (e) {
      print("Error al extraer audio: $e");
      return null;
    }
  }
}
