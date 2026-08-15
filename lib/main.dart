import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MediaApp());
}

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
  Color _primaryColor = Colors.purpleAccent;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Fondo explícito
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1E1E),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text("Usuario"),
              accountEmail: const Text("Bienvenido"),
              decoration: BoxDecoration(color: _primaryColor.withOpacity(0.3)),
            ),
            ListTile(leading: const Icon(Icons.download), title: const Text("Descargas")),
            ListTile(leading: const Icon(Icons.favorite), title: const Text("Favoritos")),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text("Media App"),
        actions: [IconButton(icon: const Icon(Icons.search), onPressed: () {})],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _primaryColor,
          labelColor: _primaryColor,
          unselectedLabelColor: Colors.grey,
          isScrollable: true,
          tabs: const [
            Tab(text: "Inicio"),
            Tab(text: "Música/Podcasts"),
            Tab(text: "Top 🔝"),
            Tab(text: "Deportes"),
          ],
        ),
      ),
      // Añadimos un pequeño retraso o estructura para asegurar que renderice
      body: TabBarView(
        controller: _tabController,
        children: const [
          Center(child: Text("Inicio", style: TextStyle(color: Colors.white))),
          Center(child: Text("Música/Podcasts", style: TextStyle(color: Colors.white))),
          Center(child: Text("Top 🔝", style: TextStyle(color: Colors.white))),
          Center(child: Text("Deportes", style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
}
