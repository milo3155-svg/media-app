import 'package:flutter/material.dart';

void main() => runApp(const MediaApp());

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF121212)),
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
    _tabController = TabController(length: 3, vsync: this); // Música, Top, Deportes
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1E1E),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(accountName: Text("Hola"), accountEmail: Text("Bienvenido")),
            ListTile(leading: const Icon(Icons.video_library), title: const Text("Videos (YouTube)"), onTap: () {}),
            ListTile(leading: const Icon(Icons.music_note), title: const Text("Música (YT Music)"), onTap: () {}),
            const Divider(),
            ListTile(leading: const Icon(Icons.download), title: const Text("Descargas")),
            ListTile(leading: const Icon(Icons.settings), title: const Text("Ajustes")),
          ],
        ),
      ),
      appBar: AppBar(
        title: _isSearching 
            ? TextField(controller: _searchController, decoration: const InputDecoration(hintText: "Buscar..."))
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
          tabs: const [
            Tab(text: "Música/Podcasts"),
            Tab(text: "Top 🔝"),
            Tab(text: "Deportes"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDummyList(), // Aquí irán tus listas
          const Center(child: Text("Top Musical")),
          const Center(child: Text("Sección Deportes")),
        ],
      ),
    );
  }

  // Ejemplo del menú de 3 puntitos que querías
  Widget _buildDummyList() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) => ListTile(
        leading: const Icon(Icons.play_circle_fill),
        title: Text("Contenido $index"),
        trailing: PopupMenuButton<String>(
          onSelected: (value) { /* Lógica de descarga/compartir */ },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'lista', child: Text('Añadir a lista')),
            const PopupMenuItem(value: 'cola', child: Text('Añadir a cola')),
            const PopupMenuItem(value: 'mp3', child: Text('Descargar MP3')),
            const PopupMenuItem(value: 'mp4', child: Text('Descargar MP4')),
            const PopupMenuItem(value: 'share', child: Text('Compartir en WhatsApp')),
          ],
        ),
      ),
    );
  }
}
