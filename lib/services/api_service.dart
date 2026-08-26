import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // OJO: Cambia esta URL si tu servidor en Render tiene un nombre distinto
  static const String _backendUrl = 'https://mi-media-proxy.onrender.com';

  static Future<List<dynamic>> search(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      final uri = Uri.parse('$_backendUrl/api/search?q=${Uri.encodeComponent(query)}');
      // Le damos 15 segundos por si Render está "dormido" y necesita despertar
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List ? data : [];
      }
      return [{'title': 'Error del servidor', 'author': 'Código ${response.statusCode}'}];
    } catch (e) {
      // Si falla, avisamos en la interfaz que el servidor está despertando
      return [{'title': 'El proxy está despertando...', 'author': 'Reintenta en 1 minuto'}];
    }
  }

  static Future<String?> getAudioUrl(String videoId) async {
    try {
      final uri = Uri.parse('$_backendUrl/api/stream?id=$videoId');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Retornamos la URL limpia que nos da Render
        return data['url'] ?? data['audioUrl']; 
      }
      return null;
    } catch (e) {
      print("Error obteniendo stream del backend: $e");
      return null;
    }
  }
}
