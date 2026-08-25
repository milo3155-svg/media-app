  Future<void> playVideo(String videoId, String trackName) async {
    _isLoading = true;
    _currentTrack = trackName;
    notifyListeners();

    try {
      String? audioUrl = await ApiService.getAudioUrl(videoId);
      
      if (audioUrl != null) {
        // Reproducción directa y limpia, sin disfraces
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
