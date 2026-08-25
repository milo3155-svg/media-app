import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Tu backend privado en Render
  static const String _backendUrl = 'https://mi-media-proxy.onrender.com';

  static Future<List<dynamic>> search(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      final uri = Uri.parse('$_backendUrl/api/search?q=${Uri.encodeComponent(query)}');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List ? data : [];
      }
      return [{'title': 'Error del servidor', 'author': 'Código ${response.statusCode}'}];
    } catch (e) {
      // Mensaje de alerta en caso de que Render esté dormido
      return [{'title': 'El proxy está despertando...', 'author': 'Reintenta en 1 minuto'}];
    }
  }

  static Future<String?> getAudioUrl(String videoId) async {
    try {
      final uri = Uri.parse('$_backendUrl/api/stream?id=$videoId');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['url'] ?? data['audioUrl']; 
      }
      return null;
    } catch (e) {
      throw Exception("El proxy en Render falló o está dormido: $e");
    }
  }
}
