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
    _currentTrack = 'Buscando enlace...';
    notifyListeners();

    try {
      // 1. Primero consultamos el stream directo usando el ID que ya tenemos
      final streamUrl = 'https://dia-proxy.onrender.com/api/stream?id=$videoId';
      print('Consultando stream: $streamUrl');

      var response = await http.get(Uri.parse(streamUrl)).timeout(const Duration(seconds: 20));

      String? audioUrl;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          audioUrl = decoded['url'] ?? decoded['streamUrl'];
        }
      }

      // 2. PLAN B: Si el stream directo falló, usamos el endpoint de búsqueda que vimos en tu captura
      if (audioUrl == null || audioUrl.isEmpty) {
        final searchUrl = 'https://dia-proxy.onrender.com/api/search?q=${Uri.encodeComponent(trackName)}';
        print('Intentando plan B con búsqueda: $searchUrl');
        
        response = await http.get(Uri.parse(searchUrl)).timeout(const Duration(seconds: 20));
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is List && decoded.isNotEmpty) {
            // Tomamos el ID del primer resultado de la búsqueda
            final realId = decoded[0]['id'];
            if (realId != null) {
              final secondAttemptUrl = 'https://dia-proxy.onrender.com/api/stream?id=$realId';
              final streamRes = await http.get(Uri.parse(secondAttemptUrl));
              if (streamRes.statusCode == 200) {
                final streamDecoded = jsonDecode(streamRes.body);
                audioUrl = streamDecoded['url'] ?? streamDecoded['streamUrl'];
              }
            }
          }
        }
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

      throw Exception('No se pudo obtener una ruta de audio válida');

    } catch (e) {
      print('Error al reproducir: $e');
      _currentTrack = 'Error al reproducir audio';
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
