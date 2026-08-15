import 'package:flutter/material.dart';

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
  
  bool _showDownloadBanner = true;
  String _selectedTeam = "Club Águila";
  IconData _teamIcon = Icons.sports_football;

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
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.black26,
                child: Icon(_teamIcon, size: 35, color: Colors.white),
              ),
            ),
            ListTile(leading: const Icon(Icons.favorite, color: Colors.redAccent), title: const Text("Favoritos"), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.download, color: Colors.blueAccent), title: const Text("Gestor de Descargas"), onTap: () => Navigator.pop(context)),
            const Divider(color: Colors.grey),
            ListTile(leading: const Icon(Icons.video_library), title: const Text("Modo Videos"), onTap: () {}),
            ListTile(leading: const Icon(Icons.music_note), title: const Text("Modo Música / 2do Plano"), onTap: () {}),
            const Divider(color: Colors.grey),
            ListTile(leading: const Icon(Icons.settings), title: const Text("Ajustes y Colores"), onTap: () {}),
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
      body: Column(
        children: [
          if (_isSearching)
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF1E1E1E),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(hintText: "Escribe...", border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.search)),
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
                _buildContentList("Música"),
                _buildContentList("Top"),
                _buildSportsView(), // <--- AQUÍ ESTÁ EL PORTAL
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- PUNTO 2: PORTAL DE DEPORTES ---
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
        const SizedBox(height: 20),
        const Text("Goles y Resúmenes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            itemBuilder: (context, index) => Container(
              width: 180,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle_fill, size: 40, color: Colors.white),
                  SizedBox(height: 8),
                  Text("Golazo Jornada $index"),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- (Tus métodos existentes: _buildCustomHomeFeed, _buildContentList, etc. permanecen igual) ---
  Widget _buildCustomHomeFeed() { return const Center(child: Text("Feed Principal")); }
  Widget _buildContentList(String category) { return const Center(child: Text("Lista")); }
}
