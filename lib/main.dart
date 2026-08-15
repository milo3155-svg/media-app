import 'package:flutter/material.dart';

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
  
  String _selectedFilter = "Todo";
  final List<String> _filters = ["Todo", "Música", "Videos", "Deportes"];
  
  String _selectedTopCategory = "Global";
  final List<String> _topCategories = ["Global", "México", "Virales", "Podcasts"];

  String _selectedTeam = "Pachuca";
  IconData _teamIcon = Icons.sports_soccer;

  bool _hasActiveMedia = true;
  bool _isPlaying = false;

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
            ListTile(
              leading: const Icon(Icons.cleaning_services, color: Colors.orangeAccent),
              title: const Text("Liberar Caché"),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Caché limpiada con éxito! 🧹')));
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: _isSearching ? const Text("Búsqueda Global") : const Text("Media App"),
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
                        decoration: const InputDecoration(
                          hintText: "Buscar música o videos...",
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.search),
                        ),
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
                    ],
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCustomHomeFeed(), 
                    const Center(child: Text("Sección de Música (Próximamente real)")),
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
                            Text("Pista de prueba", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text("Toca para abrir el reproductor", style: TextStyle(color: Colors.grey, fontSize: 11)),
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
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.play_circle_fill, size: 80, color: Colors.purpleAccent),
                ),
                const SizedBox(height: 30),
                const Text("Pista de prueba", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("Artista Desconocido", style: TextStyle(color: Colors.grey, fontSize: 14)),
                const Spacer(),
                LinearProgressIndicator(value: 0.3, backgroundColor: Colors.grey[800], color: Colors.purpleAccent),
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
                          setState(() => _isPlaying = !_isPlaying);
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
                  onSelected: (selected) => setState(() => _selectedTopCategory = cat),
                ),
              )).toList(),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: 8,
            itemBuilder: (context, index) => ListTile(
              leading: CircleAvatar(backgroundColor: Colors.purpleAccent.withOpacity(0.2), child: Text("${index + 1}", style: const TextStyle(color: Colors.purpleAccent))),
              title: Text("Top #${index + 1} de $_selectedTopCategory"),
              subtitle: const Text("Contenido de prueba", style: TextStyle(fontSize: 12, color: Colors.grey)),
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
}
