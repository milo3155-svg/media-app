import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Servidores oficiales y principales de Piped con alta disponibilidad
  static const List<String> _instances = [
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.syncpundit.io',
    'https://pipedapi.tokhmi.xyz',
    'https://pipedapi.moomoo.me'
  ];

  static Future<List<dynamic>> search(String query) async {
    if (query.trim().isEmpty) return [];
    
    String ultimoError = "Ninguna API respondió";

    for (String baseUrl in _instances) {
      try {
        final url = Uri.parse('$baseUrl/search?q=${Uri.encodeComponent(query)}&filter=all');
        
        final response = await http.get(
          url,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 8));
        
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
        ultimoError = e.toString();
        continue; 
      }
    }
    
    return [
      {
        'title': 'Error de servidores Piped:',
        'author': ultimoError,
      }
    ];
  }
}
