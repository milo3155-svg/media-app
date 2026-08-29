import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

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

      final proxyAudioUrl = 'https://mi-media-proxy.onrender.com/stream?id=$videoId';

      Uri? parsedArtUri;
      if (artUri != null && artUri.isNotEmpty) {
        parsedArtUri = Uri.tryParse(artUri);
      }

      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(proxyAudioUrl),
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
      print('Reproducción iniciada exitosamente para: $trackName');
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
