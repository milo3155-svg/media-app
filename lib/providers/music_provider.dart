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
    _currentTrack = 'Consultando proxy...';
    notifyListeners();

    try {
      final query = Uri.encodeComponent(trackName);
      final searchUrl = 'https://dia-proxy.onrender.com/api/search?q=$query';
      
      final response = await http.get(Uri.parse(searchUrl)).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        // Mostramos literal lo que respondió el servidor en la barra de la app
        _currentTrack = 'Resp: ${response.body.length > 50 ? response.body.substring(0, 50) : response.body}';
        notifyListeners();
        print('RESPUESTA JSON COMPLETA: ${response.body}');
        return;
      } else {
        _currentTrack = 'Error HTTP: ${response.statusCode}';
        notifyListeners();
      }

    } catch (e) {
      _currentTrack = 'Catch: $e';
      notifyListeners();
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
