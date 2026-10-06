import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'main.dart';
import 'package:google_fonts/google_fonts.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});


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
    return Scaffold(body: SafeArea(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.all(16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => ConspiracyLogo(size: 60, color: color)), 
        IconButton(icon: const Icon(Icons.settings, color: Colors.grey, size: 28), onPressed: () { showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1A1A1A), builder: (context) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Ajustes VIP", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)), 
          const SizedBox(height: 20), 
          const Text("Color del Neón", style: TextStyle(color: Colors.grey)), 
          const SizedBox(height: 10), 
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Colors.cyanAccent, Colors.purpleAccent, Colors.greenAccent, Colors.amberAccent, Colors.blueAccent, Colors.white].map((c) => GestureDetector(onTap: () { appColor.value = c; Navigator.pop(context); }, child: Container(width: 40, height: 40, decoration: BoxDecoration(color: c, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c, blurRadius: 10)], border: Border.all(color: Colors.white24, width: 2))))).toList()), 
          const SizedBox(height: 20), 
          const Divider(color: Colors.white24), 
          const SizedBox(height: 10), 
          ListTile(leading: const Icon(Icons.delete_forever, color: Colors.redAccent), title: const Text("Botón Nuclear (Borrar Todo)", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)), subtitle: const Text("Resetea todo el algoritmo y bóveda", style: TextStyle(color: Colors.grey, fontSize: 12)), onTap: () { Hive.box('history').clear(); Hive.box('favorites').clear(); Hive.box('search_history').clear(); Hive.box('playlists').clear(); audioHandler.updateQueue([]); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Memoria de la app borrada. Renacimiento VIP.'), backgroundColor: Colors.redAccent)); })
        ]))); })
      ])), 
      ValueListenableBuilder(valueListenable: Hive.box('history').listenable(), builder: (context, Box box, _) { 
        if (box.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text("Comienza a escuchar música para activar el radar.", style: TextStyle(color: Colors.grey))); 
        final allItems = box.values.toList().cast<Map>(); 
        final recentItems = List<Map>.from(allItems)..sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0)); 
        final topItems = List<Map>.from(allItems)..sort((a, b) => (b['playCount'] as int? ?? 0).compareTo(a['playCount'] as int? ?? 0)); 
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text("Escuchado Recientemente", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))), 
          _buildHorizontalList(recentItems), 
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text("Tu Frecuencia Máxima (Top 25)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))), 
          _buildHorizontalList(topItems.take(25).toList()), 
          const SizedBox(height: 100)
        ]); 
      })
    ]))));
  }
}


class SearchScreen extends StatefulWidget { const SearchScreen({super.key}); @override State<SearchScreen> createState() => _SearchScreenState(); }


class _SearchScreenState extends State<SearchScreen> {
  final searchController = TextEditingController(); late final YoutubeExplode yt; 
  List<Video> videos = []; List<String> searchSuggestions = []; bool isLoading = false; Timer? _debounce; 


  @override void initState() { super.initState(); yt = YoutubeExplode(); Permission.notification.request(); }
  @override void dispose() { _debounce?.cancel(); searchController.dispose(); super.dispose(); }


  void _saveSearchHistory(String query) { 
    if (query.trim().isEmpty) return; 
    final box = Hive.box('search_history'); 
    List<String> searches = box.values.cast<String>().toList(); 
    searches.remove(query); 
    searches.insert(0, query); 
    if (searches.length > 15) searches = searches.sublist(0, 15); 
    box.clear(); 
    box.addAll(searches); 
  }


  void searchVideos(String query) async {
    if (query.trim().isEmpty) return; FocusScope.of(context).unfocus(); _saveSearchHistory(query); setState(() { isLoading = true; videos.clear(); });
    try { final results = await yt.search.search(query); setState(() { videos = results.toList(); isLoading = false; }); } 
    catch (e) { setState(() { isLoading = false; }); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de conexión con YouTube: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 6))); }
  }


  Widget _buildSearchHistory() {
    return ListView(children: [
      ValueListenableBuilder(valueListenable: Hive.box('search_history').listenable(), builder: (context, Box box, _) { 
        if (box.isEmpty) return const SizedBox.shrink(); 
        final history = box.values.cast<String>().toList(); 
        return Column(children: history.map((query) { 
          int index = history.indexOf(query); 
          return ListTile(leading: const Icon(Icons.history, color: Colors.grey), title: Text(query, style: const TextStyle(color: Colors.white)), onTap: () { searchController.text = query; searchVideos(query); }, trailing: Row(mainAxisSize: MainAxisSize.min, children: [ IconButton(icon: const Icon(Icons.north_west, color: Colors.grey, size: 20), onPressed: () { searchController.text = query; searchController.selection = TextSelection.fromPosition(TextPosition(offset: searchController.text.length)); }), IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 20), onPressed: () { final newHistory = List<String>.from(history)..removeAt(index); box.clear(); box.addAll(newHistory); })])); 
        }).toList()); 
      }),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text("Escuchado Recientemente", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16))),
      ValueListenableBuilder(valueListenable: Hive.box('history').listenable(), builder: (context, Box box, _) { 
        if (box.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text("Aún no hay canciones en tu registro.", style: TextStyle(color: Colors.grey))); 
        final items = box.values.toList().cast<Map>()..sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0)); 
        return Column(children: items.take(15).map((item) { 
          return ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: item['artUri'], width: 50, height: 50, fit: BoxFit.cover)), title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(item['artist'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)), trailing: IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 20), onPressed: () => box.delete(item['id'])), onTap: () async { final mediaItem = MediaItem(id: item['id'], title: item['title'], artist: item['artist'], artUri: Uri.parse(item['artUri']), duration: Duration(milliseconds: item['duration'])); await globalPlay(mediaItem); }); 
        }).toList()); 
      }),
      const SizedBox(height: 100),
    ]);
  }


  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Buscador VIP', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.yellowAccent)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          image: DecorationImage(
            image: const AssetImage('assets/ojo_pirata.png'), // Tu imagen se mantendrá aquí
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.85), BlendMode.darken),
          ),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    style: GoogleFonts.specialElite(color: Colors.yellowAccent),
                    decoration: InputDecoration(
                      hintText: 'Ingresar frecuencia a interceptar...',
                      hintStyle: GoogleFonts.specialElite(color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        searchVideos(val.trim());
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          if (isLoading) const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (videos.isEmpty && searchController.text.isEmpty) Expanded(child: _buildSearchHistory())
          else Expanded(child: StreamBuilder<MediaItem?>(stream: audioHandler.mediaItem, builder: (context, snapshot) { 
            final currentId = snapshot.data?.id; 
            return ListView.builder(padding: const EdgeInsets.only(bottom: 100), itemCount: videos.length, itemBuilder: (context, index) { 
              final video = videos[index]; 
              final isPlaying = currentId == video.id.value; 
              return ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), leading: Stack(children: [ Hero(tag: video.id.value, child: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: video.thumbnails.mediumResUrl, width: 80, height: 50, fit: BoxFit.cover))), Positioned(bottom: 2, right: 2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)), child: Text(formatGlobalDuration(video.duration), style: const TextStyle(color: Colors.white, fontSize: 10)))) ]), title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)), subtitle: Text(video.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [ if (isPlaying) ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => Icon(Icons.equalizer, color: color, size: 24)), ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => IconButton(icon: const Icon(Icons.more_vert, color: Colors.grey), onPressed: () => globalShowOptions(context, video, color))) ]), onTap: () async { final queueItems = videos.map((vid) => MediaItem(id: vid.id.value, title: vid.title, artist: vid.author, duration: vid.duration, artUri: Uri.parse(vid.thumbnails.highResUrl))).toList(); await globalPlayQueue(queueItems, index); }); 
            }); 
          }))
        ]), // Este cierre cierra la lista de children y el Column
      ), // Este cierra el Container
    ); // Y este cierra el Scaffold!
  }
}


class VaultScreen extends StatelessWidget {          
  const VaultScreen({super.key}); 
  @override Widget build(BuildContext context) { 
    return DefaultTabController(length: 3, child: Scaffold(appBar: AppBar(title: const Text('La Bóveda', style: TextStyle(fontWeight: FontWeight.bold)), bottom: TabBar(indicatorColor: appColor.value, tabs: const [Tab(icon: Icon(Icons.history), text: "Historial"), Tab(icon: Icon(Icons.favorite), text: "Favoritos"), Tab(icon: Icon(Icons.queue_music), text: "Playlists")])), body: TabBarView(children: [
      ValueListenableBuilder(valueListenable: Hive.box('history').listenable(), builder: (context, Box box, _) { if (box.isEmpty) return const Center(child: Text("Sin historial aún", style: TextStyle(color: Colors.grey))); final items = box.values.toList().cast<Map>()..sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int)); return ListView.builder(padding: const EdgeInsets.only(bottom: 100), itemCount: items.length, itemBuilder: (context, index) { final item = items[index]; return ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: item['artUri'], width: 50, height: 50, fit: BoxFit.cover)), title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(item['artist'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)), trailing: IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 20), onPressed: () => box.delete(item['id'])), onTap: () async { final mediaItem = MediaItem(id: item['id'], title: item['title'], artist: item['artist'], artUri: Uri.parse(item['artUri']), duration: Duration(milliseconds: item['duration'])); await globalPlay(mediaItem); }); }); }), 
      ValueListenableBuilder(valueListenable: Hive.box('favorites').listenable(), builder: (context, Box box, _) { if (box.isEmpty) return const Center(child: Text("Sin favoritos aún", style: TextStyle(color: Colors.grey))); final items = box.values.toList().cast<Map>(); return ListView.builder(padding: const EdgeInsets.only(bottom: 100), itemCount: items.length, itemBuilder: (context, index) { final item = items[index]; return ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: item['artUri'], width: 50, height: 50, fit: BoxFit.cover)), title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(item['artist'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)), trailing: IconButton(icon: const Icon(Icons.favorite, color: Colors.redAccent), onPressed: () => box.delete(item['id'])), onTap: () async { List<MediaItem> allFavs = items.map((e) => MediaItem(id: e['id'], title: e['title'], artist: e['artist'], artUri: Uri.parse(e['artUri']), duration: Duration(milliseconds: e['duration']))).toList(); await globalPlayQueue(allFavs, index); }); }); }),
      ValueListenableBuilder(valueListenable: Hive.box('playlists').listenable(), builder: (context, Box box, _) { if (box.isEmpty) return const Center(child: Text("Toca los 3 puntitos en una canción para armar listas", style: TextStyle(color: Colors.grey))); final keys = box.keys.toList(); return ListView.builder(padding: const EdgeInsets.only(bottom: 100), itemCount: keys.length, itemBuilder: (context, index) { final playlistName = keys[index].toString(); final List tracks = box.get(playlistName) ?? []; return ExpansionTile(leading: ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => Icon(Icons.album, color: color)), title: Row(children: [ Expanded(child: Text(playlistName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))), ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => IconButton(icon: Icon(Icons.play_circle_fill, color: color, size: 28), onPressed: () async { if (tracks.isEmpty) return; List<MediaItem> allTracks = tracks.map((e) => MediaItem(id: e['id'], title: e['title'], artist: e['artist'], artUri: Uri.parse(e['artUri']), duration: Duration(milliseconds: e['duration']))).toList(); await globalPlayQueue(allTracks, 0); })) ]), subtitle: Text("${tracks.length} pistas", style: const TextStyle(color: Colors.grey)), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => box.delete(playlistName)), children: tracks.asMap().entries.map((entry) { int trackIndex = entry.key; final item = entry.value as Map; return ListTile(contentPadding: const EdgeInsets.only(left: 40, right: 16), leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: CachedNetworkImage(imageUrl: item['artUri'], width: 40, height: 40, fit: BoxFit.cover)), title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)), subtitle: Text(item['artist'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)), trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.grey, size: 20), onPressed: () { tracks.removeWhere((s) => s['id'] == item['id']); box.put(playlistName, tracks); }), onTap: () async { List<MediaItem> allTracks = tracks.map((e) => MediaItem(id: e['id'], title: e['title'], artist: e['artist'], artUri: Uri.parse(e['artUri']), duration: Duration(milliseconds: e['duration']))).toList(); await globalPlayQueue(allTracks, trackIndex); }); }).toList()); }); })
    ]))); 
  } 
}


class SportsScreen extends StatelessWidget { const SportsScreen({super.key}); @override Widget build(BuildContext context) => Scaffold(backgroundColor: const Color(0xFF0A1910), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.sports_soccer, size: 80, color: Colors.greenAccent), const SizedBox(height: 20), const Text('Tablero VIP Deportivo', style: TextStyle(color: Colors.white, fontSize: 18))]))); }


class MiniPlayer extends Stateless