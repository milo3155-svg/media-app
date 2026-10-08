import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_fonts/google_fonts.dart';


import 'main.dart'; // Para acceso a globals (audioHandler, appColor)


// ============================================================================
// === SUPER APP SKELETON: CONTENEDOR CON BARRA DE NAVEGACIÓN Y MINIPLAYER ===
// ============================================================================
class SuperAppSkeleton extends StatefulWidget {
  const SuperAppSkeleton({super.key});
  @override State<SuperAppSkeleton> createState() => _SuperAppSkeletonState();
}


class _SuperAppSkeletonState extends State<SuperAppSkeleton> {
  int _currentIndex = 0;
  final List<Widget> _screens = [const HomeScreen(), const SearchScreen(), const VaultScreen()];


  @override Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _screens[_currentIndex],
          Positioned(bottom: 0, left: 0, right: 0, child: _buildMiniPlayer()),
        ]
      ),
      bottomNavigationBar: ValueListenableBuilder<Color>(
        valueListenable: appColor,
        builder: (context, color, _) {
          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: color,
            unselectedItemColor: Colors.grey,
            backgroundColor: const Color(0xFF0A0A0A),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
              BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Radar'),
              BottomNavigationBarItem(icon: Icon(Icons.security), label: 'Bóveda'),
            ]
          );
        }
      )
    );
  }
  Widget _buildMiniPlayer() {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final item = snapshot.data!;
        return Container(
          height: 65, color: const Color(0xFF151515),
          child: Row(
            children: [
              CachedNetworkImage(imageUrl: item.artUri.toString(), width: 65, height: 65, fit: BoxFit.cover),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(item.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]
              )),
              StreamBuilder<PlaybackState>(
                stream: audioHandler.playbackState,
                builder: (context, stateSnapshot) {
                  final playing = stateSnapshot.data?.playing ?? false;
                  return ValueListenableBuilder<Color>(
                    valueListenable: appColor,
                    builder: (context, color, _) => IconButton(
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: color, size: 32),
                      onPressed: () => playing ? audioHandler.pause() : audioHandler.play(),
                    )
                  );
                }
              ),
              ValueListenableBuilder<Color>(
                valueListenable: appColor,
                builder: (context, color, _) => IconButton(icon: Icon(Icons.skip_next, color: color, size: 32), onPressed: () => audioHandler.skipToNext())
              ),
              const SizedBox(width: 10),
            ]
          )
        );
      }
    );
  }
}


// ============================================================================
// === HOME SCREEN: PANTALLA PRINCIPAL (CON DRAWER VIP Y QR) ===
// ============================================================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});


  Future<void> _launchURL(String url) async {
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      debugPrint('No se pudo abrir $url');
    }
  }


  void _showQRDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: const Color(0xFF111111).withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: appColor.value, width: 1)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("COMPARTIR ACCESO", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 8),
                const Text("Escanea para instalar la app VIP", style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: QrImageView(
                    data: "https://wa.me/5211234567890?text=Hola,%20quiero%20descargar%20la%20App%20VIP", // CAMBIA TU NUMERO
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: appColor.value, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CERRAR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
Drawer _buildVIPDrawer(BuildContext context) {
    final box = Hive.box('cerrojo_box');
    final activeToken = box.get('token_activo', defaultValue: 'Sin Sesión');
    final alias = box.get('device_id', defaultValue: 'Usuario Registrado');


    return Drawer(
      backgroundColor: const Color(0xFF0A0A0A),
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: appColor.value, width: 1)), color: const Color(0xFF111111)),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_circle, color: appColor.value, size: 60),
                  const SizedBox(height: 10),
                  Text(alias, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  Text(activeToken, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                ],
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.qr_code_scanner, color: appColor.value),
            title: const Text('Compartir App', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Código de invitación', style: TextStyle(color: Colors.grey, fontSize: 12)),
            onTap: () { Navigator.pop(context); _showQRDialog(context); },
          ),
          ListTile(
            leading: const Icon(Icons.apps, color: Colors.white),
            title: const Text('Ecosistema', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Descargar TV y Bóveda', style: TextStyle(color: Colors.grey, fontSize: 12)),
            onTap: () { Navigator.pop(context); _launchURL('https://linktr.ee/tu_ecosistema_aqui'); },
          ),
          ListTile(
            leading: const Icon(Icons.support_agent, color: Colors.white),
            title: const Text('Soporte VIP', style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(context); _launchURL('https://wa.me/5211234567890?text=Hola,%20necesito%20ayuda'); },
          ),
          const Spacer(),
          Padding(padding: const EdgeInsets.all(16.0), child: Text('Apex Client v1.0', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10)))
        ],
      ),
    );
  }


  Widget _buildHorizontalList(List<Map> items) { 
    return SizedBox(height: 180, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: items.length, itemBuilder: (context, index) { 
      final item = items[index]; 
      return GestureDetector(
        onTap: () async { final mediaItem = MediaItem(id: item['id'], title: item['title'], artist: item['artist'], artUri: Uri.parse(item['artUri']), duration: Duration(milliseconds: item['duration'])); await globalPlay(mediaItem); }, 
        child: Container(width: 120, margin: const EdgeInsets.only(right: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Hero(tag: item['id'], child: ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(imageUrl: item['artUri'], width: 120, height: 120, fit: BoxFit.cover, placeholder: (c,u)=>Container(width:120,height:120,color:Colors.white10)))), 
          const SizedBox(height: 8), Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)), Text(item['artist'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 11))
        ]))
      ); 
    })); 
  }


  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: _buildVIPDrawer(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        iconTheme: IconThemeData(color: appColor.value),
        title: const Text("Inicio", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ValueListenableBuilder(valueListenable: Hive.box('history').listenable(), builder: (context, Box box, _) { 
              if (box.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text("Comienza a escuchar música para activar el radar.", style: TextStyle(color: Colors.grey))); 
              final allItems = box.values.toList().cast<Map>(); 
              final recentItems = List<Map>.from(allItems)..sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0)); 
              final topItems = List<Map>.from(allItems)..sort((a, b) => (b['playCount'] as int? ?? 0).compareTo(a['playCount'] as int? ?? 0)); 
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text("Escuchado Recientemente", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))), 
                _buildHorizontalList(recentItems), 
                const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text("Frecuencia Máxima", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))), 
                _buildHorizontalList(topItems.take(25).toList()), 
                const SizedBox(height: 100)
              ]); 
            })
          ])
        )
      )
    );
  }
}
// ============================================================================
// === SEARCH SCREEN: RADAR CON OJO PIRATA DE FONDO ===
// ============================================================================
class SearchScreen extends StatefulWidget { const SearchScreen({super.key}); @override State<SearchScreen> createState() => _SearchScreenState(); }
class _SearchScreenState extends State<SearchScreen> {
  final searchController = TextEditingController();
  late final YoutubeExplode yt;
  List<Video> videos = [];
  bool isLoading = false;


  @override void initState() { super.initState(); yt = YoutubeExplode(); }
  @override void dispose() { searchController.dispose(); super.dispose(); }


  void searchVideos(String query) async {
    if (query.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() { isLoading = true; videos.clear(); });
    try {
      final results = await yt.search.search(query);
      if (mounted) { setState(() { videos = results.toList(); isLoading = false; }); }
    } catch (e) { if (mounted) { setState(() { isLoading = false; }); } }
  }


  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => Text('Radar', style: TextStyle(fontWeight: FontWeight.bold, color: color))), backgroundColor: Colors.transparent, elevation: 0),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          image: DecorationImage(image: const AssetImage('assets/ojo_pirata.png'), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.85), BlendMode.darken)),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              style: TextStyle(color: appColor.value), // Eliminamos GoogleFonts por seguridad local
              decoration: InputDecoration(
                hintText: 'Ingresar frecuencia a interceptar...', hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: appColor.value), borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(icon: const Icon(Icons.search, color: Colors.grey), onPressed: () => searchVideos(searchController.text))
              ),
              onSubmitted: (val) => searchVideos(val.trim()),
            ),
          ),
          if (isLoading) const Expanded(child: Center(child: CircularProgressIndicator()))
          else Expanded(
            child: StreamBuilder<MediaItem?>(
              stream: audioHandler.mediaItem,
              builder: (context, snapshot) {
                final currentId = snapshot.data?.id;
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100), itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index]; final isPlaying = currentId == video.id.value;
                    return ListTile(
                      leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: video.thumbnails.mediumResUrl, width: 80, height: 50, fit: BoxFit.cover)),
                      title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(video.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
                      trailing: isPlaying ? Icon(Icons.equalizer, color: appColor.value) : const Icon(Icons.play_arrow, color: Colors.grey),
                      onTap: () async {
                        final queueItems = videos.map((vid) => MediaItem(id: vid.id.value, title: vid.title, artist: vid.author, duration: vid.duration, artUri: Uri.parse(vid.thumbnails.highResUrl))).toList();
                        await globalPlayQueue(queueItems, index);
                      },
                    );
                  },
                );
              },
            )
          )
        ]),
      ),
    );
  }
}


// ============================================================================
// === VAULT SCREEN: LA BÓVEDA LOCAL ===
// ============================================================================
class VaultScreen extends StatelessWidget {          
  const VaultScreen({super.key}); 
  @override Widget build(BuildContext context) { 
    return DefaultTabController(
      length: 2, 
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('La Bóveda', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), 
          bottom: TabBar(
            indicatorColor: appColor.value, labelColor: appColor.value, unselectedLabelColor: Colors.grey,
            tabs: const [Tab(icon: Icon(Icons.favorite), text: "Favoritos"), Tab(icon: Icon(Icons.history), text: "Registro")]
          )
        ), 
        body: TabBarView(
          children: [
            _buildHiveList('favorites'),
            _buildHiveList('history'),
          ]
        )
      )
    ); 
  }


  Widget _buildHiveList(String boxName) {
    return ValueListenableBuilder(
      valueListenable: Hive.box(boxName).listenable(),
      builder: (context, Box box, _) {
        if (box.isEmpty) return const Center(child: Text("Bóveda limpia.", style: TextStyle(color: Colors.grey)));
        final items = box.values.toList().reversed.toList();
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: item['artUri'], width: 50, height: 50, fit: BoxFit.cover)),
              title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
              subtitle: Text(item['artist'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
              trailing: IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 20), onPressed: () => box.delete(item['id'])),
              onTap: () async {
                final mediaItem = MediaItem(id: item['id'], title: item['title'], artist: item['artist'], artUri: Uri.parse(item['artUri']), duration: Duration(milliseconds: item['duration'] ?? 0));
                await globalPlay(mediaItem);
              },
            );
          },
        );
      },
    );
  }
}
