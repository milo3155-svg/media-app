import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const List<String> _instances = [
    'https://invidious.nerdvpn.de/api/v1',
    'https://inv.nadeko.net/api/v1',
    'https://invidious.fdn.fr/api/v1',
    'https://vid.puffyan.us/api/v1'
  ];

  static Future<List<dynamic>> search(String query) async {
    if (query.isEmpty) return [];
    
    for (String baseUrl in _instances) {
      try {
        // Le ponemos un "disfraz" a la petición para que crean que somos Google Chrome
        final response = await http.get(
          Uri.parse('$baseUrl/search?q=$query'),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 5)); // Si tarda más de 5 segundos, pasamos al siguiente servidor
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is List && data.isNotEmpty) {
             return data;
          }
        }
      } catch (e) {
        continue; // Si falla o se tarda, salta al siguiente servidor silenciosamente
      }
    }
    
    return [
      {
        'type': 'video',
        'title': 'Error: Todos los servidores están bloqueados o sin internet',
        'author': 'Intenta de nuevo o revisa tu conexión',
        'videoThumbnails': []
      }
    ];
  }
}
