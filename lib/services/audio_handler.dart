import 'dart:convert';
import 'package:http/http.dart' as http;

class AudioHandlerService {
  static Future<String?> getAudioUrl(String videoId) async {
    try {
      final uri = Uri.parse('https://mi-media-proxy.onrender.com/stream?id=$videoId');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['url'] ?? data['audioUrl'];
      }
      return null;
    } catch (e) {
      print("Error obteniendo stream del backend: $e");
      return null;
    }
  }
}
