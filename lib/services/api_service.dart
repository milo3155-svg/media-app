import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Ahora usamos PIPED, que es mucho más estable y no pide autenticación
  static const List<String> _instances = [
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.syncpundit.io',
    'https://piped-api.garudalinux.org'
  ];

  static Future<List<dynamic>> search(String query) async {
    if (query.trim().isEmpty) return [];
    
    String ultimoError = "Ninguna API respondió";

    for (String baseUrl in _instances) {
      try {
        // La ruta de búsqueda en Piped es un poco diferente
        final url = Uri.parse('$baseUrl/search?q=${Uri.encodeComponent(query)}&filter=all');
        
        final response = await http.get(
          url,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          // Piped devuelve los resultados dentro de un arreglo llamado 'items'
          if (data['items'] != null && data['items'] is List) {
            List<dynamic> formattedResults = [];
            
            for (var item in data['items']) {
              if (item['type'] == 'stream') { // 'stream' significa que es un video
                formattedResults.add({
                  'title': item['title'],
                  'author': item['uploaderName'] ?? 'Desconocido',
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
