import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../services/api_service.dart';

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

  // Agregamos author y artUri opcionales para la carátula y el artista en la notificación
  Future<void> playVideo(String videoId, String trackName, {String? author, String? artUri}) async {
    _isLoading = true;
    _currentTrack = trackName;
    notifyListeners();

    try {
      String? audioUrl = await ApiService.getAudioUrl(videoId);
      
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
    } catch (e) {
      _currentTrack = 'Fallo: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void togglePlay() {
    if (_audioPlayer.playing) {
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
