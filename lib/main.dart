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
            // --- SECCIÓN BIBLIOTECA ---
            ListTile(
              leading: const Icon(Icons.favorite, color: Colors.redAccent),
              title: const Text("Favoritos"),
              onTap: () {
                Navigator.pop(context);
                _openLibraryPage(context, "Mis Favoritos");
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.blueAccent),
              title: const Text("Gestor de Descargas"),
              onTap: () {
                Navigator.pop(context);
                _openLibraryPage(context, "Descargas Locales");
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.orangeAccent),
              title: const Text("Reproducciones Recientes"),
              onTap: () {
                Navigator.pop(context);
                _openLibraryPage(context, "Historial");
              },
            ),
            const Divider(color: Colors.grey),
            // --- PLATAFORMAS EXTERNAS / MODOS ---
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
            : const Text("Inicio"),
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
            Tab(text: "Música / Podcasts"),
            Tab(text: "Top 🔝"),
            Tab(text: "Deportes"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildContentList("Contenido de Música y Podcasts"),
          _buildContentList("Top Chart 🔝"),
          _buildContentList("Sección de Deportes"),
        ],
      ),
    );
  }

  // Vista genérica para simular listas con el menú de 3 puntitos
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
          onSelected: (value) {
            // Aquí programaremos las acciones de los 3 puntitos
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'fav', child: Text('Añadir a Favoritos')),
            const PopupMenuItem(value: 'lista', child: Text('Añadir a lista de reproducción')),
            const PopupMenuItem(value: 'cola', child: Text('Añadir a cola')),
            const PopupMenuItem(value: 'mp3', child: Text('Descargar MP3')),
            const PopupMenuItem(value: 'mp4', child: Text('Descargar MP4')),
            const PopupMenuItem(value: 'share', child: Text('Compartir en WhatsApp')),
          ],
        ),
      ),
    );
  }

  // Pantalla temporal para abrir las opciones de la biblioteca desde el menú lateral
  void _openLibraryPage(BuildContext context, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Center(child: Text("Aquí verás tus elementos de: $title", style: const TextStyle(fontSize: 16))),
        ),
      ),
    );
  }
}
