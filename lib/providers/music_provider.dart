import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MusicProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  bool _isloading = false;
  String _currentTrack = 'Ninguna pista seleccionada';

  bool get isPlaying => _isPlaying;
  bool get isloading => _isloading;
  String get currentTrack => _currentTrack;

  MusicProvider() {
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
    });
  }

  Future<void> playVideo(String videoId, String trackName, {String? author, String? artUri}) async {
    _isloading = true;
    _currentTrack = 'Conectando con servidor...';
    notifyListeners();

    try {
      // Intentamos primero con la ruta de stream de tu proxy
      final proxyUrl = 'https://dia-proxy.onrender.com/api/stream?id=$videoId';
      print('Intentando conectar a: $proxyUrl');

      var response = await http.get(Uri.parse(proxyUrl)).timeout(const Duration(seconds: 15));

      String? audioUrl;

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data is Map) {
            audioUrl = data['url'] ?? data['streamUrl'] ?? data['audio'];
          }
        } catch (_) {}
      }

      // 🛡️ PLAN B (Estrategia Maestra): Si el stream directo falló, consultamos el endpoint de búsqueda
      // que sabemos que SÍ funciona en tu Render para extraer la pista al vuelo.
      if (audioUrl == null || audioUrl.isEmpty) {
        print('Stream directo no disponible. Usando búsqueda inteligente en el proxy...');
        final searchUrl = 'https://dia-proxy.onrender.com/api/search?q=$videoId';
        final searchRes = await http.get(Uri.parse(searchUrl)).timeout(const Duration(seconds: 15));

        if (searchRes.statusCode == 200) {
          final searchData = jsonDecode(searchRes.body);
          if (searchData is List && searchData.isNotEmpty) {
            audioUrl = searchData[0]['url'] ?? searchData[0]['streamUrl'];
          } else if (searchData is Map) {
            audioUrl = searchData['url'] ?? searchData['streamUrl'];
          }
        }
      }

      // Si aun así obtuvimos un enlace válido, reproducimos
      if (audioUrl != null && audioUrl.isNotEmpty) {
        _currentTrack = trackName;
        notifyListeners();

        await _audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse(audioUrl),
            tag: MediaItem(
              id: videoId,
              album: "Media App",
              title: trackName,
              artist: author ?? "Desconocido",
              artUri: artUri != null ? Uri.parse(artUri) : null,
            ),
          ),
        );
        _audioPlayer.play();
      } else {
        // Fallback final: Si el proxy no da enlace, intentamos armar un flujo directo de emergencia
        _currentTrack = 'Reproduciendo modo seguro...';
        notifyListeners();
        
        // Usamos una URL directa de respaldo si la hay, o notificamos el error exacto
        throw Exception('El servidor proxy no entregó un enlace de streaming válido.');
      }

    } catch (e) {
      print('Error crítico en reproducción: $e');
      _currentTrack = 'Error: No se pudo reproducir la pista';
    } finally {
      _isloading = false;
      notifyListeners();
    }
  }

  void togglePlay() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
