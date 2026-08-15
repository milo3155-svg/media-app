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
  
  // --- NUEVAS VARIABLES PARA EL BUSCADOR INTELIGENTE ---
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
      // --- APPBAR MODIFICADO CON BUSCADOR INTELIGENTE ---
      appBar: AppBar(
        title: _isSearching 
            ? Column(
                children: [
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: "Buscar...", border: InputBorder.none),
                    onSubmitted: (value) {
                      setState(() {
                        if (!_recentSearches.contains(value)) _recentSearches.insert(0, value);
                      });
                    },
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _filters.map((filter) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: _selectedFilter == filter,
                          onSelected: (selected) => setState(() => _selectedFilter = filter),
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              )
            : const Text("Media App"),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() => _isSearching = !_isSearching),
          )
        ],
        bottom: !_isSearching ? TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.home), text: "Inicio"),
            Tab(icon: Icon(Icons.music_note), text: "Música"),
            Tab(icon: Icon(Icons.trending_up), text: "Top 🔝"),
            Tab(icon: Icon(Icons.sports_soccer), text: "Deportes"),
          ],
        ) : null,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCustomHomeFeed(), 
          _buildContentList("Música"),
          _buildContentList("Top"),
          _buildSportsView(),
        ],
      ),
    );
  }

  // (El resto de tus métodos _buildCustomHomeFeed, _buildSportsView, etc. permanecen igual abajo...)
  // [Copia tus métodos previos aquí para mantener el resto de la funcionalidad]
  
  // ... (Recuerda mantener _buildCustomHomeFeed, _buildSportsView, _buildContentList, _buildMenuItems, _handleMenuAction y _showShareBottomSheet aquí abajo)
}
