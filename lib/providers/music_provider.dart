import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
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

  Future<void> playVideo(String videoId, String trackName) async {
    _isLoading = true;
    _currentTrack = trackName;
    notifyListeners();

    try {
      String? audioUrl = await ApiService.getAudioUrl(videoId);
      
      if (audioUrl != null) {
        // En lugar de setUrl directo, usamos setAudioSource con el disfraz de Chrome
        await _audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse(audioUrl),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Referer': 'https://www.youtube.com/',
            },
          ),
        );
        _audioPlayer.play();
      } else {
        _currentTrack = 'Error: No se pudo obtener el audio';
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
