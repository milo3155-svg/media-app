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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
              accountEmail: const Text("Bienvenido"),
              decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.3)),
              currentAccountPicture: const CircleAvatar(child: Icon(Icons.person, size: 40)),
            ),
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
          isScrollable: true,
          indicatorColor: Colors.purpleAccent,
          labelColor: Colors.purpleAccent,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "Inicio"),
            Tab(text: "Música / Podcasts"),
            Tab(text: "Top 🔝"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCustomHomeFeed(), // <--- AQUÍ ESTÁ NUESTRO FEED PERSONALIZADO (Opción 2)
          _buildContentList("Música y Podcasts"),
          _buildContentList("Top Chart 🔝"),
        ],
      ),
    );
  }

  // 🌟 PANTALLA DE INICIO DINÁMICA (FEED PERSONALIZADO)
  Widget _buildCustomHomeFeed() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // 1. SECCIÓN DE FAVORITOS RÁPIDOS (Horizontal)
        const Text("Tus Favoritos Recientes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            itemBuilder: (context, index) => Container(
              width: 110,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(color: Colors.grey[800], child: const Icon(Icons.favorite, color: Colors.redAccent, size: 30)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text("Favorito $index", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 2. SECCIÓN DE DESCARGAS OFFLINE (Banner rápido)
        Container(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Descargas Disponibles", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text("3 elementos listos para modo offline", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 3. TENDENCIAS DEL DÍA (Vertical tradicional)
        const Text("Tendencias del Día", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
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
              onSelected: (value) {},
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'fav', child: Text('Añadir a Favoritos')),
                const PopupMenuItem(value: 'mp3', child: Text('Descargar MP3')),
                const PopupMenuItem(value: 'mp4', child: Text('Descargar MP4')),
                const PopupMenuItem(value: 'share', child: Text('Compartir en WhatsApp')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Vista genérica para las otras pestañas
  Widget _buildContentList(String categoryName) {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) => ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(width: 60, height: 45, color: Colors.grey[800], child: const Icon(Icons.play_arrow)),
        ),
        title: Text("$categoryName - Item $index", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text("Artista o Creador", style: TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          onSelected: (value) {},
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'fav', child: Text('Añadir a Favoritos')),
            const PopupMenuItem(value: 'mp3', child: Text('Descargar MP3')),
            const PopupMenuItem(value: 'mp4', child: Text('Descargar MP4')),
            const PopupMenuItem(value: 'share', child: Text('Compartir en WhatsApp')),
          ],
        ),
      ),
    );
  }
}
