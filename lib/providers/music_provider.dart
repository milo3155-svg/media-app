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

    // Enlace de respaldo seguro por defecto
    String audioUrl = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

    try {
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
    } catch (_) {}

    try {
      // Paramos y limpiamos el reproductor por completo
      await _audioPlayer.stop();

      // Asignamos la fuente
      await _audioPlayer.setUrl(audioUrl); // Usamos setUrl directamente para simplificar el flujo con el stream

      // Damos un respiro de 300ms al buffer para que procese el enlace
      await Future.delayed(const Duration(milliseconds: 300));

      // Disparamos la reproducción de manera explícita
      await _audioPlayer.play();
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
