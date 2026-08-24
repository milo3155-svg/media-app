import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Instancias públicas alternativas para evitar bloqueos 403
  static const List<String> _instances = [
    'https://yewtu.be/api/v1',
    'https://invidious.privacyredirect.com/api/v1',
    'https://inv.nadeko.net/api/v1',
    'https://invidious.nerdvpn.de/api/v1'
  ];

  static Future<List<dynamic>> search(String query) async {
    if (query.trim().isEmpty) return [];
    
    String ultimoError = "Ninguna instancia respondió";

    for (String baseUrl in _instances) {
      try {
        final url = Uri.parse('$baseUrl/search?q=${Uri.encodeComponent(query)}');
        
        final response = await http.get(
          url,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:123.0) Gecko/20100101 Firefox/123.0',
            'Accept': 'application/json, text/plain, */*',
            'Accept-Language': 'en-US,en;q=0.5',
          },
        ).timeout(const Duration(seconds: 8));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is List && data.isNotEmpty) {
             return data;
          }
        } else {
          ultimoError = "HTTP ${response.statusCode} en $baseUrl";
        }
      } catch (e) {
        ultimoError = e.toString();
        continue; 
      }
    }
    
    return [
      {
        'type': 'video',
        'title': 'Error de conexión con servidores:',
        'author': ultimoError,
        'videoThumbnails': []
      }
    ];
  }
}
