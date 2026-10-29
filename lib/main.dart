// --- MOTOR ORIGINAL EXITOSO (FUSIÓN) ---
Future<String> _getStreamUrl(String videoId) async {
  final yt = YoutubeExplode();
  try {
    // El HttpOverrides global de main.dart protegerá esta conexión
    final manifest = await yt.videos.streamsClient.getManifest(videoId);
    yt.close();
    return manifest.audioOnly.withHighestBitrate().url.toString();
  } catch (e) {
    yt.close();
    throw Exception("Fallo extracción original: $e");
  }
}

@override
Future<void> playMediaItem(MediaItem item) async {
  mediaItem.add(item); 
  final historyBox = Hive.box('history'); 
  int playCount = 1; int savedPosition = 0; 
  
  if (historyBox.containsKey(item.id)) { 
    final existingItem = historyBox.get(item.id); 
    playCount = (existingItem['playCount'] ?? 0) + 1; 
    savedPosition = existingItem['savedPosition'] ?? 0; 
  }
  historyBox.put(item.id, {
    'id': item.id, 'title': item.title, 'artist': item.artist, 'artUri': item.artUri?.toString() ?? '', 'duration': item.duration?.inMilliseconds ?? 0, 'timestamp': DateTime.now().millisecondsSinceEpoch, 'playCount': playCount, 'savedPosition': 0
  });

  try {
    playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.loading, playing: true));
    await _player.stop(); 
    await _player.seek(Duration.zero); 
    
    final streamUrl = await _getStreamUrl(item.id);
    
    // Le pasamos exactamente la misma firma de Windows Chrome al ExoPlayer
    // para que Google no note el cambio de manos
    final source = AudioSource.uri(
      Uri.parse(streamUrl), 
      tag: item,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'
      }
    );
    
    await _player.setAudioSource(source);
    
    if (savedPosition > 0) { await _player.seek(Duration(milliseconds: savedPosition)); } 
    await _player.play();
  } catch (e) { 
    print("Playback Error: $e");
    playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.error, playing: false)); 
  }
}
