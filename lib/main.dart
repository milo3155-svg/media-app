import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:audioplayers/audioplayers.dart';

void main() async {
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
  
  String _selectedFilter = "Todo";
  final List<String> _filters = ["Todo", "Música", "Videos", "Deportes"];
  
  String _selectedTopCategory = "Global";
  final List<String> _topCategories = ["Global", "México", "Virales", "Podcasts"];

  String _selectedTeam = "Pachuca";
  IconData _teamIcon = Icons.sports_soccer;

  // --- MOTOR PRINCIPAL ---
  final YoutubeExplode _yt = YoutubeExplode();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<Video> _searchResults = [];
  bool _isLoadingSearch = false;
  
  // --- DATOS DEL TOP ---
  List<Video> _topResults = [];
  bool _isLoadingTop = false;

  Video? _currentMedia;
  bool _isPlaying = false;
  bool _hasActiveMedia = false;
  
  // --- TIEMPOS PARA LA BARRA DE PROGRESO ---
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Conectar sensores de tiempo del reproductor
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });

    // Cargar el Top inicial al abrir la app
    _loadTopContent("Global");
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _yt.close();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Carga automática de listas Top
  Future<void> _loadTopContent(String category) async {
    setState(() {
      _selectedTopCategory = category;
      _isLoadingTop = true;
    });

    // Creamos una búsqueda simulando un "Trending"
    String query = "Top canciones tendencias $category 2026";
    if (category == "Podcasts") query = "Mejores podcasts en español populares";

    try {
      var searchList = await _yt.search.search(query);
      if (mounted) {
        setState(() {
          _topResults = searchList.take(10).toList();
          _isLoadingTop = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTop = false);
    }
  }

  Future<void> _performRealSearch(String query) async {
    if (query.trim().isEmpty) return;
    FocusScope.of(context).unfocus(); 
    _tabController.animateTo(1);
    
    setState(() {
      _isLoadingSearch = true;
    });

    try {
      var searchList = await _yt.search.search(query);
      if (mounted) {
        setState(() {
          _searchResults = searchList.take(15).toList();
          _isLoadingSearch = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSearch = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al buscar. Verifica tu red.')));
      }
    }
  }

  Future<void> _playMedia(Video video) async {
    setState(() {
      _currentMedia = video;
      _hasActiveMedia = true;
      _isPlaying = false;
      _position = Duration.zero; // Reiniciar barra
    });

    try {
      await _audioPlayer.stop(); 
      var manifest = await _yt.videos.streamsClient.getManifest(video.id);
      
      var streamInfo = manifest.muxed.isNotEmpty 
          ? manifest.muxed.first 
          : manifest.audioOnly.first;

      await _audioPlayer.play(UrlSource(streamInfo.url.toString()));
      if (mounted) setState(() => _isPlaying = true);
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Formato no soportado.')));
      }
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.resume();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1E1E),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text("Usuario"),
              accountEmail: Text("Equipo: $_selectedTeam"),
              decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.3)),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.black26,
                child: Icon(Icons.sports_soccer, size: 35, color: Colors.white),
              ),
            ),
            ListTile(leading: const Icon(Icons.favorite, color: Colors.redAccent), title: const Text("Favoritos"), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.download, color: Colors.blueAccent), title: const Text("Gestor de Descargas"), onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
      appBar: AppBar(
        title: _isSearching ? const Text("Búsqueda Global") : const Text("Media App"),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchResults.clear();
            }),
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.home), text: "Inicio"),
            Tab(icon: Icon(Icons.search), text: "Búsqueda"),
            Tab(icon: Icon(Icons.trending_up), text: "Top"),
            Tab(icon: Icon(Icons.sports_soccer), text: "Deportes"),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_isSearching)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFF1E1E1E),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: "Buscar música o videos...",
                          border: const OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.send, color: Colors.purpleAccent),
                            onPressed: () => _performRealSearch(_searchController.text),
                          ),
                        ),
                        onSubmitted: (value) => _performRealSearch(value),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCustomHomeFeed(), 
                    // Pestaña de Búsqueda
                    _isLoadingSearch 
                        ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
                        : _searchResults.isEmpty 
                            ? const Center(child: Text("Realiza una búsqueda", style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final video = _searchResults[index];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(video.thumbnails.lowResUrl, width: 80, height: 60, fit: BoxFit.cover)),
                                    title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                                    subtitle: Text(video.author, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    trailing: const Icon(Icons.play_arrow, color: Colors.purpleAccent),
                                    onTap: () => _playMedia(video),
                                  );
                                },
                              ),
                    // Pestaña TOP REAL
                    _buildTopMulticategoryView(),
                    _buildSportsView(),
                  ],
                ),
              ),
            ],
          ),
          
          if (_hasActiveMedia && _currentMedia != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () => _openExpandedPlayer(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F1F),
                    border: Border(top: BorderSide(color: Colors.purpleAccent.withOpacity(0.4), width: 1)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(_currentMedia!.thumbnails.lowResUrl, width: 45, height: 45, fit: BoxFit.cover)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_currentMedia!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(_currentMedia!.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white), onPressed: _togglePlayPause),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () {
                          _audioPlayer.stop();
                          setState(() => _hasActiveMedia = false);
                        },
                      ),
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
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181818),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                const Text("Reproductor Inmersivo", style: TextStyle(fontSize: 16, color: Colors.grey)),
                const Spacer(),
                ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(_currentMedia!.thumbnails.highResUrl, width: 280, height: 280, fit: BoxFit.cover)),
                const SizedBox(height: 30),
                Text(_currentMedia!.title, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_currentMedia!.author, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const Spacer(),
                
                // --- BARRA DE PROGRESO REAL ---
                LinearProgressIndicator(
                  value: _duration.inSeconds > 0 ? _position.inSeconds / _duration.inSeconds : 0.0,
                  backgroundColor: Colors.grey[800], 
                  color: Colors.purpleAccent
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_position), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(_formatDuration(_duration), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(icon: const Icon(Icons.shuffle, size: 28), onPressed: () {}),
                    IconButton(icon: const Icon(Icons.skip_previous, size: 36), onPressed: () {}),
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.purpleAccent,
                      child: IconButton(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 32),
                        onPressed: () {
                          _togglePlayPause();
                          setModalState(() {}); 
                        },
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.skip_next, size: 36), onPressed: () {}),
                    IconButton(icon: const Icon(Icons.repeat, size: 28), onPressed: () {}),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildTopMulticategoryView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: const Color(0xFF181818),
          child: SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _topCategories.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: _selectedTopCategory == cat,
                  onSelected: (selected) => _loadTopContent(cat),
                ),
              )).toList(),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingTop 
            ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
            : ListView.builder(
                itemCount: _topResults.length,
                itemBuilder: (context, index) {
                  final video = _topResults[index];
                  return ListTile(
                    leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(video.thumbnails.lowResUrl, width: 60, height: 45, fit: BoxFit.cover)),
                    title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(video.author, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: Text("#${index + 1}", style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                    onTap: () => _playMedia(video),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildSportsView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Portal Deportivo", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Card(
          color: Colors.purpleAccent.withOpacity(0.1),
          child: ListTile(
            leading: Icon(_teamIcon, color: Colors.purpleAccent),
            title: Text(_selectedTeam, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Posición: 1er Lugar - Liga MX"),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomHomeFeed() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text("Favoritos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SizedBox(height: 110, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: 4, itemBuilder: (context, index) => Container(width: 100, margin: const EdgeInsets.only(right: 12), color: Colors.grey[800], child: const Icon(Icons.favorite, color: Colors.redAccent)))),
      ],
    );
  }
}
