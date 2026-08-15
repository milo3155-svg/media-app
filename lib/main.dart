import 'package:flutter/material.dart';

class MainNavigation extends StatefulWidget {
  final Color primaryColor;
  final Function(Color) onColorChange;
  const MainNavigation({super.key, required this.primaryColor, required this.onColorChange});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- MENÚ LATERAL ---
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1E1E),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text("Usuario"),
              accountEmail: const Text("Bienvenido"),
              decoration: BoxDecoration(color: widget.primaryColor.withOpacity(0.3)),
            ),
            ListTile(leading: const Icon(Icons.download), title: const Text("Gestor de Descargas")),
            ListTile(leading: const Icon(Icons.favorite), title: const Text("Favoritos")),
            // ... (Resto de tus opciones)
          ],
        ),
      ),

      // --- APBAR + TABS SUPERIORES ---
      appBar: AppBar(
        title: const Text("Media App"),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: widget.primaryColor,
          labelColor: widget.primaryColor,
          unselectedLabelColor: Colors.grey,
          isScrollable: true, // Útil para que quepan bien los 4 textos
          tabs: const [
            Tab(text: "Inicio"),
            Tab(text: "Música/Podcasts"),
            Tab(text: "Top 🔝"),
            Tab(text: "Deportes"),
          ],
        ),
      ),

      // --- CONTENIDO ---
      body: TabBarView(
        controller: _tabController,
        children: const [
          Center(child: Text("Inicio")),
          Center(child: Text("Música/Podcasts")),
          Center(child: Text("Top 🔝")),
          Center(child: Text("Deportes")),
        ],
      ),
    );
  }
}
