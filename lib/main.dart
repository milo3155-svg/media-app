// ... (mismo inicio de archivo hasta YMusicPlayerProvider)
class YMusicPlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final String _backendUrl = 'https://mi-media-proxy.onrender.com';

  MediaItemModel? _currentItem;
  bool _isLoading = false;
  bool _isPlaying = false;
  String? _errorMessage; // Nuevo: para ver qué falla

  MediaItemModel? get currentItem => _currentItem;
  bool get isLoading => _isLoading;
  bool get isPlaying => _isPlaying;
  String? get errorMessage => _errorMessage;

  YMusicPlayerProvider() {
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isLoading = state.processingState == ProcessingState.loading || state.processingState == ProcessingState.buffering;
      notifyListeners();
    });
    
    // Nuevo: Escuchar errores reales del reproductor
    _player.playbackEventStream.listen((event) {}, onError: (Object e, StackTrace st) {
      _errorMessage = "Error de reproductor: $e";
      _isLoading = false;
      notifyListeners();
    });
  }
  
  // ... (método searchMusic igual)

  Future<void> playItem(MediaItemModel item) async {
    _currentItem = item;
    _isLoading = true;
    _errorMessage = null; // Limpiar error anterior
    notifyListeners();

    try {
      await _player.stop();
      final String? audioUrl = item.directStreamUrl;

      if (audioUrl == null || audioUrl.isEmpty) {
        throw Exception("URL de audio vacía");
      }

      // Intentar reproducción directa sin restricciones de metadatos complejos
      await _player.setUrl(audioUrl); 
      _player.play();
      
    } catch (e) {
      _isLoading = false;
      _errorMessage = "Fallo al cargar: ${e.toString()}";
      notifyListeners();
    }
  }
  // ... (resto del código igual)
