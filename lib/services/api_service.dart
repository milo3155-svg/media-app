import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Usamos una instancia pública de Invidious (totalmente anónima)
  static const String baseUrl = 'https://vid.puffyan.us/api/v1';

  static Future<List<dynamic>> search(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final response = await http.get(Uri.parse('$baseUrl/search?q=$query'));
      
      if (response.statusCode == 200) {
        return json.decode(response.body); 
      } else {
        return [];
      }
    } catch (e) {
      print('Error en la búsqueda: $e');
      return [];
    }
  }
}
