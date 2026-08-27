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
    _currentTrack = trackName;
    notifyListeners();

    try {
      // 🚀 APUNTA A TU URL REAL DE RENDER
      final proxyUrl = 'https://TU-APP-EN-RENDER.onrender.com/api/stream?id=$videoId';
      final response = await http.get(Uri.parse(proxyUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final audioUrl = data['url'];

        if (audioUrl != null) {
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
          _currentTrack = 'Error: El proxy no devolvió enlace de audio';
        }
      } else {
        _currentTrack = 'Error: Fallo de comunicación con el servidor';
      }
    } catch (e) {
      _currentTrack = 'Fallo: $e';
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
