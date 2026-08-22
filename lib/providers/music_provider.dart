import 'package:flutter/material.dart';

class MusicProvider extends ChangeNotifier {
  bool _isPlaying = false;
  String _currentTrack = 'Pista simulada - Artista';

  // "Getters" para que las pantallas puedan leer el estado
  bool get isPlaying => _isPlaying;
  String get currentTrack => _currentTrack;

  // Función para alternar entre Play y Pausa
  void togglePlay() {
    _isPlaying = !_isPlaying;
    notifyListeners(); // ¡Esta línea es mágica! Avisa a todas las pantallas que se actualicen al instante
  }

  // Función para cambiar de canción (la usaremos más adelante)
  void setTrack(String trackName) {
    _currentTrack = trackName;
    notifyListeners();
  }
}
