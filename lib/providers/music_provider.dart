import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/api_service.dart';

class MusicProvider extends ChangeNotifier {
  // 1. Inicializamos el motor de audio
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  bool _isLoading = false; // Útil para mostrar un "cargando..." en la UI
  String _currentTrack = 'Ninguna pista seleccionada';

  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String get currentTrack => _currentTrack;

  MusicProvider() {
    // 2. Escuchamos automáticamente los cambios del reproductor
    // Así la UI se actualiza sola si la canción termina o se pausa
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
    });
  }

  // 3. ¡La función estrella! Carga y reproduce el audio
  Future<void> playVideo(String videoId, String trackName) async {
    _isLoading = true;
    _currentTrack = trackName;
    notifyListeners();

    try {
      // Pedimos la URL directa del MP3 a nuestro servicio
      String? audioUrl = await ApiService.getAudioUrl(videoId);
      
      if (audioUrl != null) {
        // Cargamos la URL en el motor y le damos play
        await _audioPlayer.setUrl(audioUrl);
        _audioPlayer.play();
      } else {
        _currentTrack = 'Error al extraer el audio';
      }
    } catch (e) {
      _currentTrack = 'Fallo de red: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 4. El botón de Play/Pausa ahora controla el audio real
  void togglePlay() {
    if (_audioPlayer.playing) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  // Buena práctica: liberar memoria cuando la app se cierre
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
