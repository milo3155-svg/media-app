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
  
  // --- VARIABLES PARA EL TOP MULTICATEGORÍA ---
  String _selectedTopCategory = "Global";
  final List<String> _topCategories = ["Global", "México", "Virales", "Podcasts"];

  bool _showDownloadBanner = true;
  String _selectedTeam = "Pachuca";
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
                _buildTopMulticategoryView(), // <--- AQUÍ ESTÁ EL NUEVO TOP MULTICATEGORÍA
                _buildSportsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- PUNTO 4: VISTA TOP MULTICATEGORÍA ---
  Widget _buildTopMulticategoryView() {
    return Column(
      children: [
        // Subfiltros horizontales para el Top
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
                  onSelected: (selected) {
                    setState(() => _selectedTopCategory = category);
                  },
                ),
              )).toList(),
            ),
          ),
        ),
        // Lista dinámica basada en la categoría seleccionada
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
                onSelected: (value) => _handleMenuAction(context, value, "Top #${index + 1} ($_selectedTopCategory)"),
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
