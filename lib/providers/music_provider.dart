import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'http' as http; // Asegúrate de tener importado http
import 'dart:convert';

class MusicProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  bool _isLoading = false;
  String _currentTrack = 'Ninguna pista seleccionada';

  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String get currentTrack => _currentTrack;

  MusicProvider() {
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
    });
  }

  Future<void> playVideo(String videoId, String trackName, {String? author, String? artUri}) async {
    _isLoading = true;
    _currentTrack = trackName;
    notifyListeners();

    try {
      await _audioPlayer.stop();

      // 1. Consultamos al proxy para que nos devuelva el JSON con la URL real de streaming
      final proxyEndpoint = Uri.parse('https://mi-media-proxy.onrender.com/stream?id=$videoId');
      final response = await http.get(proxyEndpoint).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('El servidor respondió con código ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final directAudioUrl = data['url'] ?? data['audioUrl'];

      if (directAudioUrl == null || directAudioUrl.isEmpty) {
        throw Exception('El proxy no devolvió una URL de audio válida');
      }

      Uri? parsedArtUri;
      if (artUri != null && artUri.isNotEmpty) {
        parsedArtUri = Uri.tryParse(artUri);
      }

      // 2. Alimentamos al reproductor con la URL real y limpia extraída del JSON
      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(directAudioUrl),
          tag: MediaItem(
            id: videoId.isNotEmpty ? videoId : 'default_id',
            album: 'Media App Pro',
            title: trackName,
            artist: author ?? 'Desconocido',
            artUri: parsedArtUri,
          ),
        ),
      );

      await _audioPlayer.play();
    } catch (e) {
      print('Error crítico al reproducir: $e');
      _currentTrack = 'Error al reproducir audio';
    } finally {
      _isLoading = false;
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
