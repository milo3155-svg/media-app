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
    
    // Aquí guardaremos el chisme de qué falló exactamente
    String ultimoError = "Error desconocido";

    for (String baseUrl in _instances) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/search?q=$query'),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 15)); // Le damos 15 segundos para contestar
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is List && data.isNotEmpty) {
             return data;
          }
        } else {
          // Si el servidor responde pero con un bloqueo (ej. error 403 o 500)
          ultimoError = "Servidor rechazó la conexión: Código ${response.statusCode}";
        }
      } catch (e) {
        // Si hay error de internet o timeout, guardamos el mensaje nativo de Android
        ultimoError = e.toString();
        continue; 
      }
    }
    
    // Si todos fallaron, mostramos el error técnico en la pantalla
    return [
      {
        'type': 'video',
        'title': 'Fallo técnico detectado:',
        'author': ultimoError, // <- ESTO NOS DIRÁ LA VERDAD
        'videoThumbnails': []
      }
    ];
  }
}
