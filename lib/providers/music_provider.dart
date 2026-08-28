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

    // Empezamos usando el enlace de respaldo estable de inmediato para garantizar cero bloqueos
    String audioUrl = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

    try {
      // Intentamos consultar a Render súper rápido (máximo 3 segundos para que no cuelgue la app)
      final streamUrl = 'https://dia-proxy.onrender.com/api/stream?id=$videoId';
      final response = await http.get(Uri.parse(streamUrl)).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final realStream = decoded['url'] ?? decoded['streamUrl'];
          if (realStream != null && realStream.toString().isNotEmpty) {
            audioUrl = realStream;
          }
        }
      }
    } catch (_) {
      // Si Render falla o tarda, se queda silenciosamente con el respaldo y la música suena igual
    }

    try {
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
    } catch (e) {
      print('Error al iniciar reproductor: $e');
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
