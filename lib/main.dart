import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const MediaApp());

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
  
  List<String> _recentSearches = ["Pop 2026", "Liga MX resumen", "Podcast tech"];
  String _selectedFilter = "Todo";
  final List<String> _filters = ["Todo", "Música", "Videos", "Deportes"];
  
  // Lista para almacenar resultados reales de la red
  List<String> _searchResults = [];
  bool _isLoadingSearch = false;

  String _selectedTopCategory = "Global";
  final List<String> _topCategories = ["Global", "México", "Virales", "Podcasts"];

  bool _showDownloadBanner = true;
  String _selectedTeam = "Pachuca";
  IconData _teamIcon = Icons.sports_soccer;

  bool _isPlaying = true;
  bool _hasActiveMedia = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- FUNCIÓN DE BÚSQUEDA CONECTADA A LA RED ---
  Future<void> _performRealSearch(String query) async {
    if (query.isEmpty) return;
    
    setState(() {
      _isLoadingSearch = true;
      if (!_recentSearches.contains(query)) {
        _recentSearches.insert(0, query);
      }
    });

    try {
      // Usamos una API pública de prueba para que veas cómo se conecta y trae datos reales
      final url = Uri.parse('https://jsonplaceholder.typicode.com/posts?title_like=$query');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        setState(() {
          _searchResults = data.take(5).map((item) => "${item['title'].toString().substring(0, 20)}...").toList();
          _isLoadingSearch = false;
        });
      } else {
        setState(() {
          _searchResults = ["Resultado real para: $query", "Contenido multimedia encontrado"];
          _isLoadingSearch = false;
        });
      }
    } catch (e) {
      setState(() {
        _searchResults = ["Sin conexión, mostrando modo offline para: $query"];
        _isLoadingSearch = false;
      });
    }
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
            const Divider(color: Colors.grey),
            ListTile(leading: const Icon(Icons.video_library), title: const Text("Modo Videos"), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.music_note), title: const Text("Modo Música / 2do Plano"), onTap: () => Navigator.pop(context)),
            const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.cleaning_services, color: Colors.orangeAccent),
              title: const Text("Liberar Caché"),
              subtitle: const Text("142 MB usados", style: TextStyle(fontSize: 11, color: Colors.grey)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Caché limpiada con éxito! 🧹')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.color_lens, color: Colors.purpleAccent),
              title: const Text("Tema y Apariencia"),
              subtitle: const Text("Modo Oscuro Activo", style: TextStyle(fontSize: 11, color: Colors.grey)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La aplicación ya utiliza el tema optimizado 🌙')));
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: _isSearching ? const Text("Buscar contenido") : const Text("Media App"),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() => _isSearching = !_isSearching),
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.home), text: "Inicio"),
            Tab(icon: Icon(Icons.music_note), text: "Música"),
            Tab(icon: Icon(Icons.trending_up), text: "Top 🔝"),
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
                        decoration: const InputDecoration(
                          hintText: "Buscar en la red...",
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.search),
                        ),
                        onSubmitted: (value) => _performRealSearch(value),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _filters.map((filter) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(filter, style: const TextStyle(fontSize: 12)),
                              selected: _selectedFilter == filter,
                              onSelected: (selected) => setState(() => _selectedFilter = filter),
                              visualDensity: VisualDensity.compact,
                            ),
                          )).toList(),
                        ),
                      ),
                      // PANEL DE RESULTADOS EN VIVO
                      if (_isLoadingSearch)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: LinearProgressIndicator(color: Colors.purpleAccent),
                        )
                      else if (_searchResults.isNotEmpty)
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.bolt, color: Colors.purpleAccent),
                              title: Text(_searchResults[index], style: const TextStyle(fontSize: 13)),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Reproduciendo: ${_searchResults[index]}'))
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCustomHomeFeed(), 
                    _buildContentList("Música"),
                    _buildTopMulticategoryView(),
                    _buildSportsView(),
                  ],
                ),
              ),
            ],
          ),
          if (_hasActiveMedia)
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
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, -2))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.music_note, color: Colors.purpleAccent),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("Reproduciendo en segundo plano", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text("Artista o Creador • Toque para ampliar", style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                        onPressed: () => setState(() => _isPlaying = !_isPlaying),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => setState(() => _hasActiveMedia = false),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181818),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text("Reproductor Inmersivo", style: TextStyle(fontSize: 16, color: Colors.grey)),
            const Spacer(),
            Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.purpleAccent.withOpacity(0.5)),
              ),
              child: const Icon(Icons.play_circle_filled, size: 80, color: Colors.purpleAccent),
            ),
            const SizedBox(height: 30),
            const Text("Título del Contenido Actual", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Canal o Artista Oficial", style: TextStyle(color: Colors.grey, fontSize: 14)),
            const Spacer(),
            LinearProgressIndicator(value: 0.4, backgroundColor: Colors.grey[800], color: Colors.purpleAccent),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(icon: const Icon(Icons.shuffle, size: 28), onPressed: () {}),
                IconButton(icon: const Icon(Icons.skip_previous, size: 36), onPressed: () {}),
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.purpleAccent,
                  child: IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                    onPressed: () => setState(() => _isPlaying = !_isPlaying),
                  ),
                ),
                IconButton(icon: const Icon(Icons.skip_next, size: 36), onPressed: () {}),
                IconButton(icon: const Icon(Icons.repeat, size: 28), onPressed: () {}),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
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
              children: _topCategories.map((category) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(category),
                  selected: _selectedTopCategory == category,
                  onSelected: (selected) => setState(() => _selectedTopCategory = category),
                ),
              )).toList(),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: 8,
            itemBuilder: (context, index) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.purpleAccent.withOpacity(0.2),
                child: Text("${index + 1}", style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
              ),
              title: Text("Top #${index + 1} de $_selectedTopCategory"),
              subtitle: const Text("Artista o Creador Popular", style: TextStyle(fontSize: 12, color: Colors.grey)),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) => _handleMenuAction(context, value, "Top #${index + 1}"),
                itemBuilder: (context) => _buildMenuItems(),
              ),
            ),
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
            trailing: const Icon(Icons.bar_chart),
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

  Widget _buildContentList(String categoryName) {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) => ListTile(
        title: Text("$categoryName - Item $index"),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) => _handleMenuAction(context, value, "$categoryName - Item $index"),
          itemBuilder: (context) => _buildMenuItems(),
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems() {
    return [
      const PopupMenuItem(value: 'fav', child: Text('Añadir a Favoritos')),
      const PopupMenuItem(value: 'share', child: Text('Compartir...')),
    ];
  }

  void _handleMenuAction(BuildContext context, String value, String itemTitle) {
    if (value == 'share') _showShareBottomSheet(context, itemTitle);
  }

  void _showShareBottomSheet(BuildContext context, String itemTitle) {
    showModalBottomSheet(context: context, builder: (context) => const SizedBox(height: 200, child: Center(child: Text("Opciones de compartir"))));
  }
}
