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
  String _selectedTeam = "Seleccionar Equipo";
  IconData _teamIcon = Icons.sports_soccer;

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
          // PANEL DE BÚSQUEDA INTELIGENTE DESPLEGABLE
          if (_isSearching)
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF1E1E1E),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: "Escribe para buscar...",
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
          
          // CONTENIDO PRINCIPAL DE LAS PESTAÑAS
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCustomHomeFeed(), 
                _buildContentList("Música"),
                _buildContentList("Top"),
                _buildSportsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomHomeFeed() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text("Favoritos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SizedBox(height: 110, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: 4, itemBuilder: (context, index) => Container(width: 100, margin: const EdgeInsets.only(right: 12), color: Colors.grey[800], child: const Icon(Icons.favorite, color: Colors.redAccent)))),
        const SizedBox(height: 20),
        if (_showDownloadBanner)
          Dismissible(
            key: const Key('download_banner'),
            onDismissed: (_) => setState(() => _showDownloadBanner = false),
            child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Text("Descargas disponibles (Desliza para quitar)")),
          ),
      ],
    );
  }

  Widget _buildSportsView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.shield),
            label: Text(_selectedTeam),
            onPressed: () => setState(() { _selectedTeam = "Club Águila"; _teamIcon = Icons.sports_football; }),
          ),
        ],
      ),
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
