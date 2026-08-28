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
    _currentTrack = 'Cargando pista...';
    notifyListeners();

    try {
      // Apuntamos directo al endpoint de stream con el ID
      final streamUrl = 'https://dia-proxy.onrender.com/api/stream?id=$videoId';
      print('Consultando stream: $streamUrl');

      final response = await http.get(Uri.parse(streamUrl)).timeout(const Duration(seconds: 20));

      print('Código HTTP recibido: ${response.statusCode}');
      print('Cuerpo de respuesta: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        String? audioUrl;

        if (decoded is Map) {
          audioUrl = decoded['url'] ?? decoded['streamUrl'] ?? decoded['audio'] ?? decoded['link'];
        } else if (decoded is String) {
          audioUrl = decoded;
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

      throw Exception('El servidor respondió con código ${response.statusCode}');

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
