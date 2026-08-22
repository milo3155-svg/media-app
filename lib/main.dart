// ... (Mantén los imports y la clase SimpleAudioHandler igual) ...

  Future<void> _playMedia(Video video) async {
    setState(() {
      _currentMedia = video;
      _hasActiveMedia = true;
      _isPlaying = false;
      _isLoadingMedia = true; 
      _position = Duration.zero; 
      _duration = Duration.zero; 
    });
    _syncSystemState(); 
    _uiUpdater.value++; 

    try {
      await _audioPlayer.stop(); 
      await _audioPlayer.release(); 
      
      if (_videoController != null) {
        await _videoController!.dispose();
        _videoController = null;
      }

      var manifest = await _yt.videos.streamsClient.getManifest(video.id);
      StreamInfo? streamInfo;

      // --- MOTOR DE RESPALDO HÍBRIDO ---
      // Priorizamos Audio si estamos en modo Audio, si falla, usamos Muxed (Video+Audio)
      if (!_globalVideoMode) {
        streamInfo = manifest.audioOnly.withHighestBitrate();
      }
      
      // Si el stream de audio es nulo o falla, usamos el mejor stream Muxed (Video+Audio)
      streamInfo ??= manifest.muxed.withHighestBitrate();

      if (_globalVideoMode) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(streamInfo.url.toString()));
        await _videoController!.initialize();
        _videoController!.setLooping(_isRepeating);
        
        if (mounted) {
          setState(() { _isLoadingMedia = false; _isPlaying = true; });
          _syncSystemState(); 
          _uiUpdater.value++; 
        }
        
        _videoController!.addListener(() {
          if (mounted && _videoController != null) {
            setState(() {
              _position = _videoController!.value.position;
              if (_duration != _videoController!.value.duration) {
                _duration = _videoController!.value.duration;
                _syncSystemState();
              }
            });
            _uiUpdater.value++; 
          }
        });
        
        await _videoController!.play();
      } else {
        // En modo audio, usamos el AudioPlayer con el stream obtenido
        await _audioPlayer.setReleaseMode(_isRepeating ? ReleaseMode.loop : ReleaseMode.release);
        await _audioPlayer.play(UrlSource(streamInfo.url.toString()));
        
        if (mounted) {
          setState(() { _isPlaying = true; _isLoadingMedia = false; });
          _syncSystemState(); 
          _uiUpdater.value++;
        }
      }
      
    } catch (e) {
      debugPrint("Error en reproducción híbrida: $e");
      if (mounted) {
        setState(() { _isLoadingMedia = false; _isPlaying = false; });
        _syncSystemState();
        _uiUpdater.value++;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reintenta, procesando formato...')));
      }
    }
  }
// ... (El resto del código sigue igual) ...
