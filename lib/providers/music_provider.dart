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
    _currentTrack = 'Buscando pista...';
    notifyListeners();

    try {
      // Usamos el endpoint de búsqueda que SÍ existe en Render, pasando el nombre de la pista
      final query = Uri.encodeComponent(trackName);
      final searchUrl = 'https://dia-proxy.onrender.com/api/search?q=$query';
      print('Consultando buscador del proxy: $searchUrl');

      final response = await http.get(Uri.parse(searchUrl)).timeout(const Duration(seconds: 20));

      print('Código HTTP de búsqueda: ${response.statusCode}');
      print('Cuerpo de búsqueda: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        String? audioUrl;

        if (decoded is List && decoded.isNotEmpty) {
          // Buscamos la URL de audio dentro del primer resultado de la lista
          final firstItem = decoded[0];
          audioUrl = firstItem['url'] ?? firstItem['streamUrl'] ?? firstItem['audio'] ?? firstItem['link'];
        } else if (decoded is Map) {
          audioUrl = decoded['url'] ?? decoded['streamUrl'] ?? decoded['audio'] ?? decoded['link'];
        }

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
          return;
        }
      }

      throw Exception('La búsqueda no devolvió un enlace de audio reproducible');

    } catch (e) {
      print('Error crítico en reproducción: $e');
      _currentTrack = 'Error: $e';
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
