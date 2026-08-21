import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';

// ==========================================
// 1. EL CEREBRO DEL SEGUNDO PLANO
// ==========================================
class SimpleAudioHandler extends BaseAudioHandler {
  Function()? onPlayCommand;
  Function()? onPauseCommand;
  Function(Duration)? onSeekCommand;
  Function()? onRewindCommand;
  Function()? onFastForwardCommand;

  @override
  Future<void> play() async => onPlayCommand?.call();

  @override
  Future<void> pause() async => onPauseCommand?.call();

  @override
  Future<void> seek(Duration position) async => onSeekCommand?.call(position);

  @override
  Future<void> rewind() async => onRewindCommand?.call();

  @override
  Future<void> fastForward() async => onFastForwardCommand?.call();
}

SimpleAudioHandler? globalAudioHandler;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MediaApp());
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.purpleAccent,
        colorScheme: const ColorScheme.dark(primary: Colors.purpleAccent),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  
  String _selectedTopCategory = "Global";
  final List<String> _topCategories = ["Global", "México", "Virales", "Podcasts"];

  String _selectedTeam = "Pachuca";
  IconData _teamIcon = Icons.sports_soccer;

  final YoutubeExplode _yt = YoutubeExplode();
  final AudioPlayer _audioPlayer = AudioPlayer();
  VideoPlayerController? _videoController;
  
  final ValueNotifier<int> _uiUpdater = ValueNotifier(0);
  
  bool _globalVideoMode = true; 
  List<Video> _searchResults = [];
  bool _isLoadingSearch = false;
  List<Video> _topResults = [];
  bool _isLoadingTop = false;

  Video? _currentMedia;
  bool _isPlaying = false;
  bool _isLoadingMedia = false; 
  bool _hasActiveMedia = false;
  bool _isRepeating = false;
  
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    final audioContext = AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: true, 
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
      ),
    );
    _audioPlayer.setAudioContext(audioContext);
    
    _initAppServices();
    
    _audioPlayer.onDurationChanged.listen((d) { 
      if (mounted) { setState(() => _duration = d); _syncSystemState(); _uiUpdater.value++; } 
    });
    _audioPlayer.onPositionChanged.listen((p) { 
      if (mounted) { setState(() => _position = p); _uiUpdater.value++; } 
    });
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) { 
        if (!_isRepeating) { setState(() { _isPlaying = false; _position = Duration.zero; }); _syncSystemState(); }
        _uiUpdater.value++; 
      }
    });

    _loadTopContent("Global");
  }

  Future<void> _initAppServices() async {
    await Permission.notification.request();

    try {
      globalAudioHandler = await AudioService.init(
        builder: () => SimpleAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.milo.media_app.channel.audio',
          androidNotificationChannelName: 'Reproductor Multimedia',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidShowNotificationBadge: true,
        ),
      );
      
      globalAudioHandler?.onPlayCommand = _togglePlayPause;
      globalAudioHandler?.onPauseCommand = _togglePlayPause;
      globalAudioHandler?.onRewindCommand = () => _seekRelative(-10);
      globalAudioHandler?.onFastForwardCommand = () => _seekRelative(10);
      globalAudioHandler?.onSeekCommand = (pos) {
        setState(() => _position = pos);
        if (_globalVideoMode && _videoController != null) {
          _videoController!.seekTo(pos);
        } else {
          _audioPlayer.seek(pos);
        }
        _syncSystemState();
        _uiUpdater.value++;
      };
    } catch (e) {
      debugPrint("Error servicio audio: $e");
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _yt.close();
    _audioPlayer.dispose();
    _videoController?.dispose();
    _uiUpdater.dispose();
    super.dispose();
  }

  void _syncSystemState() {
    if (_currentMedia == null || globalAudioHandler == null) return;
    
    globalAudioHandler!.mediaItem.add(MediaItem(
      id: _currentMedia!.id.value,
      title: _currentMedia!.title,
      artist: _currentMedia!.author,
      artUri: Uri.parse(_currentMedia!.thumbnails.highResUrl),
      duration: _duration,
    ));

    // FIX: Añadimos 'speed: 1.0' y controles obligatorios para Android 14
    globalAudioHandler!.playbackState.add(PlaybackState(
      processingState: _isLoadingMedia ? AudioProcessingState.buffering : AudioProcessingState.ready,
      controls: [
        MediaControl.rewind,
        _isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.fastForward,
      ],
      systemActions: const { 
        MediaAction.seek, 
        MediaAction.seekForward, 
        MediaAction.seekBackward,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.playPause
      },
      playing: _isPlaying,
      updatePosition: _position,
      speed: 1.0, // ESTO EVITA QUE ANDROID ESCONDA LOS BOTONES
    ));
  }

  Future<void> _loadTopContent(String category) async {
    setState(() { _selectedTopCategory = category; _isLoadingTop = true; });
    String query = "Top canciones tendencias $category 2026";
    if (category == "Podcasts") query = "Mejores podcasts en español populares";

    try {
      var searchList = await _yt.search.search(query);
      if (mounted) setState(() { _topResults = searchList.take(10).toList(); _isLoadingTop = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingTop = false);
    }
  }

  Future<void> _performRealSearch(String query) async {
    if (query.trim().isEmpty) return;
    FocusScope.of(context).unfocus(); 
    _tabController.animateTo(1);
    
    setState(() => _isLoadingSearch = true);

    try {
      var searchList = await _yt.search.search(query);
      if (mounted) setState(() { _searchResults = searchList.take(15).toList(); _isLoadingSearch = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSearch = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de red al buscar.')));
      }
    }
  }

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
      if (_videoController != null) {
        await _videoController!.dispose();
        _videoController = null;
      }

      var manifest = await _yt.videos.streamsClient.getManifest(video.id);
      StreamInfo? streamInfo;

      // FIX: Plan B para extracción. Si no hay un formato, usa el otro sin causar error.
      if (_globalVideoMode) {
        if (manifest.muxed.isNotEmpty) {
          streamInfo = manifest.muxed.withHighestBitrate();
        } else {
          streamInfo = manifest.audioOnly.withHighestBitrate();
        }
      } else {
        if (manifest.audioOnly.isNotEmpty) {
          streamInfo = manifest.audioOnly.withHighestBitrate();
        } else {
          streamInfo = manifest.muxed.withHighestBitrate();
        }
      }

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
        await _audioPlayer.setReleaseMode(_isRepeating ? ReleaseMode.loop : ReleaseMode.release);
        await _audioPlayer.play(UrlSource(streamInfo.url.toString()));
        
        if (mounted) {
          setState(() { _isPlaying = true; _isLoadingMedia = false; });
          _syncSystemState(); 
          _uiUpdater.value++;
        }
      }
      
    } catch (e) {
      // FIX: Reseteamos los botones si falla para que no se queden congelados
      if (mounted) {
        setState(() { _isLoadingMedia = false; _isPlaying = false; });
        _syncSystemState();
        _uiUpdater.value++;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Formato protegido. Intenta otro video.')));
      }
    }
  }

  void _togglePlayPause() {
    setState(() => _isPlaying = !_isPlaying);
    _syncSystemState(); 
    _uiUpdater.value++; 

    if (_globalVideoMode && _videoController != null) {
      _isPlaying ? _videoController!.play() : _videoController!.pause();
    } else {
      _isPlaying ? _audioPlayer.resume() : _audioPlayer.pause();
    }
  }

  void _seekRelative(int seconds) {
    if (_duration == Duration.zero) return;
    Duration newPos = _position + Duration(seconds: seconds);
    if (newPos < Duration.zero) newPos = Duration.zero;
    if (newPos > _duration) newPos = _duration;

    setState(() => _position = newPos);
    _syncSystemState(); 
    _uiUpdater.value++;

    if (_globalVideoMode && _videoController != null) {
      _videoController!.seekTo(newPos);
    } else {
      _audioPlayer.seek(newPos);
    }
  }

  void _toggleRepeat() {
    setState(() => _isRepeating = !_isRepeating);
    if (_globalVideoMode && _videoController != null) {
      _videoController!.setLooping(_isRepeating);
    } else {
      _audioPlayer.setReleaseMode(_isRepeating ? ReleaseMode.loop : ReleaseMode.release);
    }
    _uiUpdater.value++;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isRepeating ? 'Repetir activado 🔁' : 'Repetir desactivado'), duration: const Duration(seconds: 1)));
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _openFullScreenVideo(BuildContext context) {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.purpleAccent.withOpacity(0.6),
          onPressed: () => Navigator.pop(context),
          child: const Icon(Icons.fullscreen_exit, color: Colors.white),
        ),
      );
    }));
  }

  void _showVideoOptions(BuildContext context, Video video) {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1E1E1E), builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(video.thumbnails.lowResUrl, width: 50, height: 40, fit: BoxFit.cover)), title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis)), const Divider(), ListTile(leading: const Icon(Icons.favorite_border), title: const Text('Agregar a Favoritos'), onTap: () => Navigator.pop(context)), ListTile(leading: const Icon(Icons.download), title: const Text('Descargar'), onTap: () => Navigator.pop(context))])));
  }

  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1E1E1E), builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [const ListTile(title: Text("Configuración", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent)), trailing: Icon(Icons.settings, color: Colors.purpleAccent)), const Divider(), ListTile(leading: const Icon(Icons.high_quality), title: const Text('Calidad de Video'), trailing: const Text('Auto >', style: TextStyle(color: Colors.grey)), onTap: () => Navigator.pop(context))])));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1E1E),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(accountName: const Text("Usuario"), accountEmail: Text("Equipo: $_selectedTeam"), decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.3)), currentAccountPicture: const CircleAvatar(backgroundColor: Colors.black26, child: Icon(Icons.sports_soccer, size: 35, color: Colors.white))),
            SwitchListTile(
              title: const Text("Modo Video", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_globalVideoMode ? "Reproduciendo video y audio" : "Solo Audio (Segundo plano ideal)", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              secondary: Icon(_globalVideoMode ? Icons.videocam : Icons.audiotrack, color: Colors.purpleAccent),
              activeColor: Colors.purpleAccent,
              value: _globalVideoMode,
              onChanged: (val) {
                setState(() => _globalVideoMode = val);
                Navigator.pop(context);
              },
            ),
            const Divider(color: Colors.grey),
            ListTile(leading: const Icon(Icons.favorite, color: Colors.redAccent), title: const Text("Favoritos"), onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
      appBar: AppBar(
        title: _isSearching ? const Text("Búsqueda Global") : const Text("Media App"),
        actions: [IconButton(icon: Icon(_isSearching ? Icons.close : Icons.search), onPressed: () => setState(() { _isSearching = !_isSearching; if (!_isSearching) _searchResults.clear(); }))],
        bottom: TabBar(controller: _tabController, tabs: const [ Tab(icon: Icon(Icons.home), text: "Inicio"), Tab(icon: Icon(Icons.search), text: "Búsqueda"), Tab(icon: Icon(Icons.trending_up), text: "Top"), Tab(icon: Icon(Icons.sports_soccer), text: "Deportes") ]),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_isSearching) Container(padding: const EdgeInsets.all(12), color: const Color(0xFF1E1E1E), child: TextField(controller: _searchController, textInputAction: TextInputAction.search, decoration: InputDecoration(hintText: "Buscar música o videos...", border: const OutlineInputBorder(), isDense: true, prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(icon: const Icon(Icons.send, color: Colors.purpleAccent), onPressed: () => _performRealSearch(_searchController.text))), onSubmitted: (value) => _performRealSearch(value))),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCustomHomeFeed(), 
                    _isLoadingSearch ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)) : _searchResults.isEmpty ? const Center(child: Text("Realiza una búsqueda", style: TextStyle(color: Colors.grey))) : ListView.builder(itemCount: _searchResults.length, itemBuilder: (context, index) { final video = _searchResults[index]; return ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(video.thumbnails.lowResUrl, width: 80, height: 60, fit: BoxFit.cover)), title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)), subtitle: Text(video.author, style: const TextStyle(fontSize: 12, color: Colors.grey)), onTap: () => _playMedia(video), trailing: IconButton(icon: const Icon(Icons.more_vert, color: Colors.grey), onPressed: () => _showVideoOptions(context, video))); }),
                    _buildTopMulticategoryView(),
                    _buildSportsView(),
                  ],
                ),
              ),
            ],
          ),
          
          if (_hasActiveMedia && _currentMedia != null)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: GestureDetector(
                onTap: () => _openExpandedPlayer(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF1F1F1F), border: Border(top: BorderSide(color: Colors.purpleAccent.withOpacity(0.4), width: 1))),
                  child: Row(
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(_currentMedia!.thumbnails.lowResUrl, width: 45, height: 45, fit: BoxFit.cover)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(_currentMedia!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), Text(_currentMedia!.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 11))])),
                      if (_isLoadingMedia) const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent))) else IconButton(icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white), onPressed: _togglePlayPause),
                      IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () { _audioPlayer.stop(); _videoController?.dispose(); _videoController = null; globalAudioHandler?.stop(); setState(() => _hasActiveMedia = false); }),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openExpandedPlayer(BuildContext context) {
    if (_currentMedia == null) return;
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF181818), builder: (context) { return StreamBuilder<Duration>(stream: Stream.periodic(const Duration(milliseconds: 500), (_) => _position), builder: (context, snapshot) { return ValueListenableBuilder<int>(valueListenable: _uiUpdater, builder: (context, value, child) { return Container(height: MediaQuery.of(context).size.height * 0.90, padding: const EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(icon: const Icon(Icons.keyboard_arrow_down, size: 32), onPressed: () => Navigator.pop(context)), const Text("Reproduciendo Ahora", style: TextStyle(fontSize: 14, color: Colors.grey)), IconButton(icon: const Icon(Icons.settings), onPressed: () => _showSettingsMenu(context))]), const SizedBox(height: 15), Container(height: 250, width: double.infinity, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: _isLoadingMedia ? Stack(alignment: Alignment.center, children: [ Image.network(_currentMedia!.thumbnails.highResUrl, fit: BoxFit.cover, width: double.infinity, color: Colors.black45, colorBlendMode: BlendMode.darken), const CircularProgressIndicator(color: Colors.purpleAccent) ]) : (_globalVideoMode && _videoController != null && _videoController!.value.isInitialized ? Stack(children: [Center(child: AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: VideoPlayer(_videoController!))), Positioned(bottom: 8, right: 8, child: IconButton(icon: const Icon(Icons.fullscreen, color: Colors.white, size: 30), onPressed: () => _openFullScreenVideo(context)))]) : Image.network(_currentMedia!.thumbnails.highResUrl, fit: BoxFit.cover)))), const SizedBox(height: 20), Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(_currentMedia!.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(_currentMedia!.author, style: const TextStyle(color: Colors.grey, fontSize: 16)) ])), IconButton(icon: const Icon(Icons.thumb_up_alt_outlined), onPressed: () {})]), const Spacer(), Column(children: [SliderTheme(data: SliderThemeData(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), overlayShape: const RoundSliderOverlayShape(overlayRadius: 14), activeTrackColor: Colors.purpleAccent, inactiveTrackColor: Colors.grey[800], thumbColor: Colors.purpleAccent), child: Slider(value: _duration.inSeconds > 0 ? _position.inSeconds.toDouble() : 0.0, min: 0.0, max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0, onChanged: (val) { final newPos = Duration(seconds: val.toInt()); setState(() => _position = newPos); if (_globalVideoMode && _videoController != null) { _videoController!.seekTo(newPos); } else { _audioPlayer.seek(newPos); } _syncSystemState(); })), Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text(_formatDuration(_position), style: const TextStyle(fontSize: 12, color: Colors.grey)), Text(_formatDuration(_duration), style: const TextStyle(fontSize: 12, color: Colors.grey)) ]))]), const SizedBox(height: 10), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [IconButton(icon: const Icon(Icons.shuffle, size: 28), color: Colors.grey, onPressed: () {}), IconButton(icon: const Icon(Icons.replay_10, size: 36), onPressed: () => _seekRelative(-10)), CircleAvatar(radius: 35, backgroundColor: Colors.purpleAccent, child: _isLoadingMedia ? const CircularProgressIndicator(color: Colors.white) : IconButton(icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 35), onPressed: () => _togglePlayPause())), IconButton(icon: const Icon(Icons.forward_10, size: 36), onPressed: () => _seekRelative(10)), IconButton(icon: Icon(Icons.repeat, size: 28), color: _isRepeating ? Colors.purpleAccent : Colors.grey, onPressed: () => _toggleRepeat())]), const SizedBox(height: 10)])); }); }); });
  }

  Widget _buildTopMulticategoryView() { return Column(children: [Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), color: const Color(0xFF181818), child: SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: _topCategories.map((cat) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(cat), selected: _selectedTopCategory == cat, onSelected: (s) => _loadTopContent(cat)))).toList()))), Expanded(child: _isLoadingTop ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)) : ListView.builder(itemCount: _topResults.length, itemBuilder: (context, index) { final video = _topResults[index]; return ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(video.thumbnails.lowResUrl, width: 60, height: 45, fit: BoxFit.cover)), title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)), subtitle: Text(video.author, style: const TextStyle(fontSize: 12, color: Colors.grey)), onTap: () => _playMedia(video)); }))]); }
  Widget _buildSportsView() { return ListView(padding: const EdgeInsets.all(16), children: [const Text("Portal Deportivo", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 10), Card(color: Colors.purpleAccent.withOpacity(0.1), child: ListTile(leading: Icon(_teamIcon, color: Colors.purpleAccent), title: Text(_selectedTeam, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text("Posición: 1er Lugar - Liga MX")))]); }
  Widget _buildCustomHomeFeed() { return ListView(padding: const EdgeInsets.all(16.0), children: [const Text("Favoritos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 10), SizedBox(height: 110, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: 4, itemBuilder: (context, index) => Container(width: 100, margin: const EdgeInsets.only(right: 12), color: Colors.grey[800], child: const Icon(Icons.favorite, color: Colors.redAccent))))]); }
}
