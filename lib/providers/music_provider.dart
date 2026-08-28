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

    // Enlace de respaldo seguro garantizado
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
      // Nos aseguramos de detener el reproductor de forma segura antes de cambiar de URL
      await _audioPlayer.stop();
      
      // Asignamos la nueva fuente con la etiqueta de fondo
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

      // Iniciamos reproducción
      await _audioPlayer.play();
    } catch (e) {
      print('Aviso de reproductor: $e');
      // Si ocurre cualquier detalle de buffer, intentamos un fallback limpio con setUrl directo
      try {
        await _audioPlayer.setUrl(audioUrl);
        await _audioPlayer.play();
      } catch (innerError) {
        print('Error crítico al reproducir: $innerError');
        _currentTrack = 'Error al reproducir audio';
      }
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
