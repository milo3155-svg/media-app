import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Instancias principales altamente probadas
  static const List<String> _instances = [
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.syncpundit.io',
    'https://piped.video',
    'https://pipedapi.drgns.space'
  ];

  static Future<List<dynamic>> search(String query) async {
    if (query.trim().isEmpty) return [];
    
    String ultimoError = "Buscando en la red...";

    for (String baseUrl in _instances) {
      try {
        final url = Uri.parse('$baseUrl/search?q=${Uri.encodeComponent(query)}&filter=all');
        
        final response = await http.get(
          url,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Android; Mobile; rv:120.0) Gecko/120.0 Firefox/120.0',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 6));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          List items = [];
          if (data is List) {
            items = data;
          } else if (data is Map && data['items'] != null) {
            items = data['items'];
          }
          
          if (items.isNotEmpty) {
            List<dynamic> formattedResults = [];
            for (var item in items) {
              if (item['type'] == 'stream' || item['title'] != null) {
                formattedResults.add({
                  'title': item['title'] ?? 'Sin título',
                  'author': item['uploaderName'] ?? item['uploader'] ?? 'Desconocido',
                });
              }
            }
            if (formattedResults.isNotEmpty) {
              return formattedResults;
            }
          }
        } else {
          ultimoError = "HTTP ${response.statusCode} en $baseUrl";
        }
      } catch (e) {
        ultimoError = "Error de conexión: $e";
        continue; 
      }
    }
    
    return [
      {
        'title': 'Sin resultados estables',
        'author': ultimoError,
      }
    ];
  }
}
