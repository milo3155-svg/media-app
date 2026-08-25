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
