import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

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
      await _audioPlayer.stop();

      // Construimos la URL completa de YouTube que el proxy de Render procesa de forma segura
      final youtubeUrl = 'https://www.youtube.com/watch?v=$videoId';
      final proxyAudioUrl = 'https://dia-proxy.onrender.com/stream?url=${Uri.encodeComponent(youtubeUrl)}';

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
