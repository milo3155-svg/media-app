import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Lista de servidores Invidious de respaldo (Tu app saltará de uno a otro si fallan)
  static const List<String> _instances = [
    'https://invidious.nerdvpn.de/api/v1',
    'https://inv.nadeko.net/api/v1',
    'https://invidious.fdn.fr/api/v1',
    'https://vid.puffyan.us/api/v1'
  ];

  static Future<List<dynamic>> search(String query) async {
    if (query.isEmpty) return [];
    
    // Intentamos buscar en cada servidor de la lista uno por uno
    for (String baseUrl in _instances) {
      try {
        final response = await http.get(Uri.parse('$baseUrl/search?q=$query'));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          // Si el servidor contestó con datos reales, los enviamos a la pantalla
          if (data is List && data.isNotEmpty) {
             return data;
          }
        }
      } catch (e) {
        // Si este servidor está caído, ignoramos el error y pasamos al siguiente
        continue;
      }
    }
    
    // Si TODOS los servidores fallan (o si tu teléfono bloqueó el internet), 
    // mostraremos esto en pantalla para saber qué pasó.
    return [
      {
        'type': 'video',
        'title': 'Error: Todos los servidores están bloqueados o sin internet',
        'author': 'Revisa tu conexión o permisos',
        'videoThumbnails': []
      }
    ];
  }
}
