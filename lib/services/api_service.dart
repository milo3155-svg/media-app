  static Future<String?> getAudioUrl(String videoId) async {
    // 1. Apuntamos a otro servidor Piped de respaldo por si el anterior murió
    final url = Uri.parse('https://pipedapi.syncpundit.io/streams/$videoId');
    
    // 2. Quitamos el try-catch. Si la conexión falla, el error volará a la UI.
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
