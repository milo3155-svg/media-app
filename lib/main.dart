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
  
  // Estado de la tarjeta de descargas en inicio
  bool _showDownloadBanner = true;
  
  // Equipo de deportes seleccionado (simulado para el escudo)
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
            // CABECERA DEL MENÚ CON EL ESCUDO / EQUIPO DINÁMICO
            UserAccountsDrawerHeader(
              accountName: const Text("Usuario"),
              accountEmail: Text("Equipo: $_selectedTeam"),
              decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.3)),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.black26,
                child: Icon(_teamIcon, size: 35, color: Colors.white),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.favorite, color: Colors.redAccent),
              title: const Text("Favoritos"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.blueAccent),
              title: const Text("Gestor de Descargas"),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(color: Colors.grey),
            ListTile(leading: const Icon(Icons.video_library), title: const Text("Modo Videos"), onTap: () {}),
            ListTile(leading: const Icon(Icons.music_note), title: const Text("Modo Música / 2do Plano"), onTap: () {}),
            const Divider(color: Colors.grey),
            ListTile(leading: const Icon(Icons.settings), title: const Text("Ajustes y Colores"), onTap: () {}),
          ],
        ),
      ),
      appBar: AppBar(
        title: _isSearching 
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: "Buscar contenido...",
                  border: InputBorder.none,
                ),
              )
            : const Text("Media App"),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() => _isSearching = !_isSearching),
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorColor: Colors.purpleAccent,
          labelColor: Colors.purpleAccent,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.home), text: "Inicio"),
            Tab(icon: Icon(Icons.music_note), text: "Música"),
            Tab(icon: Icon(Icons.trending_up), text: "Top 🔝"),
            Tab(icon: Icon(Icons.sports_soccer), text: "Deportes"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCustomHomeFeed(), 
          _buildContentList("Música y Podcasts"),
          _buildContentList("Top Chart 🔝"),
          _buildSportsView(),
        ],
      ),
    );
  }

  // 🏠 INICIO CON TARJETA DESLIZABLE (DISMISSIBLE)
  Widget _buildCustomHomeFeed() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text("Tus Favoritos Recientes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            itemBuilder: (context, index) => Container(
              width: 100,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(color: Colors.grey[800], child: const Icon(Icons.favorite, color: Colors.redAccent, size: 28)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text("Fav $index", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 🌟 TARJETA DE DESCARGAS DESLIZABLE
        if (_showDownloadBanner)
          Dismissible(
            key: const Key('download_banner'),
            direction: DismissDirection.horizontal,
            onDismissed: (direction) {
              setState(() => _showDownloadBanner = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notificación de descargas descartada')),
              );
            },
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              color: Colors.blueAccent.withOpacity(0.5),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            child: GestureDetector(
              onTap: () {
                setState(() => _showDownloadBanner = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Abriendo Gestor de Descargas...')),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.download_done, color: Colors.purpleAccent, size: 30),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Descargas Disponibles (Desliza para quitar)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text("3 elementos listos para modo offline", style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                    Icon(Icons.close, size: 18, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),

        const SizedBox(height: 20),
        const Text("Tendencias del Día", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          itemBuilder: (context, index) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(width: 70, height: 50, color: Colors.grey[800], child: const Icon(Icons.play_arrow)),
            ),
            title: Text("Tendencia Global $index", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text("Creador o Canal", style: TextStyle(color: Colors.grey, fontSize: 12)),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (value) => _handleMenuAction(context, value, "Tendencia Global $index"),
              itemBuilder: (context) => _buildMenuItems(),
            ),
          ),
        ),
      ],
    );
  }

  // ⚽ SECCIÓN DE DEPORTES
  Widget _buildSportsView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Tu Equipo Favorito", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                icon: const Icon(Icons.shield),
                label: Text(_selectedTeam),
                onPressed: () {
                  setState(() {
                    _selectedTeam = "Club Águila";
                    _teamIcon = Icons.sports_football;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('¡Equipo actualizado! Revisa el menú de las 3 líneas ⚽')),
                  );
                },
              ),
            ],
          ),
          const Divider(height: 40, color: Colors.grey),
          const Text("Próximos Partidos y Marcadores", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                Card(
                  color: const Color(0xFF1E1E1E),
                  child: ListTile(
                    leading: const Icon(Icons.sports_soccer, color: Colors.greenAccent),
                    title: Text("$_selectedTeam vs Rival X"),
                    subtitle: const Text("Hoy - 20:00 hrs | Liga MX"),
                    trailing: const Text("VS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🎵 LISTA GENÉRICA CON MENÚ CONTEXTUAL
  Widget _buildContentList(String categoryName) {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) => ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(width: 60, height: 45, color: Colors.grey[800], child: const Icon(Icons.play_arrow)),
        ),
        title: Text("$categoryName - Item $index", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text("Artista o Creador", style: TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          onSelected: (value) => _handleMenuAction(context, value, "$categoryName - Item $index"),
          itemBuilder: (context) => _buildMenuItems(),
        ),
      ),
    );
  }

  // Opciones del menú de 3 puntitos
  List<PopupMenuEntry<String>> _buildMenuItems() {
    return [
      const PopupMenuItem(value: 'fav', child: Text('Añadir a Favoritos')),
      const PopupMenuItem(value: 'lista', child: Text('Añadir a lista')),
      const PopupMenuItem(value: 'cola', child: Text('Añadir a cola')),
      const PopupMenuItem(value: 'mp3', child: Text('Descargar MP3')),
      const PopupMenuItem(value: 'mp4', child: Text('Descargar MP4')),
      const PopupMenuItem(value: 'share', child: Text('Compartir...')),
    ];
  }

  // --- LÓGICA DE LOS 3 PUNTITOS ---
  void _handleMenuAction(BuildContext context, String value, String itemTitle) {
    switch (value) {
      case 'fav':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${itemTitle}" añadido a Favoritos ❤️')),
        );
        break;
      case 'lista':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${itemTitle}" añadido a la lista de reproducción 📂')),
        );
        break;
      case 'cola':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${itemTitle}" añadido a la cola de reproducción 🎶')),
        );
        break;
      case 'mp3':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Iniciando descarga de MP3 para: $itemTitle 📥')),
        );
        break;
      case 'mp4':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Iniciando descarga de MP4 para: $itemTitle 🎥')),
        );
        break;
      case 'share':
        _showShareBottomSheet(context, itemTitle);
        break;
    }
  }

  // --- VENTANA FLOTANTE PARA COMPARTIR ---
  void _showShareBottomSheet(BuildContext context, String itemTitle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Compartir vía WhatsApp",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 15),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.greenAccent),
              title: Text("Compartir contenido: $itemTitle"),
              subtitle: const Text("Manda este video/canción a un chat", style: TextStyle(fontSize: 12, color: Colors.grey)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Abriendo WhatsApp con el enlace del contenido... 🚀')),
                );
              },
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.phone_android, color: Colors.purpleAccent),
              title: const Text("Compartir la aplicación"),
              subtitle: const Text("Invita a otros a descargar esta Media App", style: TextStyle(fontSize: 12, color: Colors.grey)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Abriendo WhatsApp para recomendar la App... 📱')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
