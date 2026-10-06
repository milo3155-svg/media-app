Home_screen_dart

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
          // MEJORA VIP: Hero y Caché de Imágenes
          Hero(tag: item['id'], child: ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(imageUrl: item['artUri'], width: 120, height: 120, fit: BoxFit.cover, placeholder: (c,u)=>Container(width:120,height:120,color:Colors.white10)))), 
          const SizedBox(height: 8), Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)), Text(item['artist'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 11))
        ]))
      ); 
    })); 
  }
  @override Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => ConspiracyLogo(size: 60, color: color)), IconButton(icon: const Icon(Icons.settings, color: Colors.grey, size: 28), onPressed: () { showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1A1A1A), builder: (context) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Ajustes VIP", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 20), const Text("Color del Neón", style: TextStyle(color: Colors.grey)), const SizedBox(height: 10), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Colors.cyanAccent, Colors.purpleAccent, Colors.greenAccent, Colors.amberAccent, Colors.blueAccent, Colors.white].map((c) => GestureDetector(onTap: () { appColor.value = c; Navigator.pop(context); }, child: Container(width: 40, height: 40, decoration: BoxDecoration(color: c, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c, blurRadius: 10)], border: Border.all(color: Colors.white24, width: 2))))).toList()), const SizedBox(height: 20), const Divider(color: Colors.white24), const SizedBox(height: 10), ListTile(leading: const Icon(Icons.delete_forever, color: Colors.redAccent), title: const Text("Botón Nuclear (Borrar Todo)", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)), subtitle: const Text("Resetea todo el algoritmo y bóveda", style: TextStyle(color: Colors.grey, fontSize: 12)), onTap: () { Hive.box('history').clear(); Hive.box('favorites').clear(); Hive.box('search_history').clear(); Hive.box('playlists').clear(); audioHandler.updateQueue([]); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Memoria de la app borrada. Renacimiento VIP.'), backgroundColor: Colors.redAccent)); })]))); })])), ValueListenableBuilder(valueListenable: Hive.box('history').listenable(), builder: (context, Box box, _) { if (box.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text("Comienza a escuchar música para activar el radar.", style: TextStyle(color: Colors.grey))); final allItems = box.values.toList().cast<Map>(); final recentItems = List<Map>.from(allItems)..sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0)); final topItems = List<Map>.from(allItems)..sort((a, b) => (b['playCount'] as int? ?? 0).compareTo(a['playCount'] as int? ?? 0)); return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text("Escuchado Recientemente", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))), _buildHorizontalList(recentItems), const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text("Tu Frecuencia Máxima (Top 25)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))), _buildHorizontalList(topItems.take(25).toList()), const SizedBox(height: 100)]); })]))));
  }
}

class SearchScreen extends StatefulWidget { const SearchScreen({super.key}); @override State<SearchScreen> createState() => _SearchScreenState(); }
class _SearchScreenState extends State<SearchScreen> {
  final searchController = TextEditingController(); late final YoutubeExplode yt; 
  List<Video> videos = []; List<String> searchSuggestions = []; bool isLoading = false; Timer? _debounce; 
  @override void initState() { super.initState(); yt = YoutubeExplode(); Permission.notification.request(); }
  @override void dispose() { _debounce?.cancel(); searchController.dispose(); super.dispose(); }
  void _saveSearchHistory(String query) { if (query.trim().isEmpty) return; final box = Hive.box('search_history'); List<String> searches = box.values.cast<String>().toList(); searches.remove(query); searches.insert(0, query); if (searches.length > 15) searches = searches.sublist(0, 15); box.clear(); box.addAll(searches); }
  void searchVideos(String query) async {
    if (query.trim().isEmpty) return; FocusScope.of(context).unfocus(); _saveSearchHistory(query); setState(() { isLoading = true; videos.clear(); });
    try { final results = await yt.search.search(query); setState(() { videos = results.toList(); isLoading = false; }); } 
    catch (e) { setState(() { isLoading = false; }); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de conexión con YouTube: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 6))); }
  }
  Widget _buildSearchHistory() {
    return ListView(children: [
      ValueListenableBuilder(valueListenable: Hive.box('search_history').listenable(), builder: (context, Box box, _) { if (box.isEmpty) return const SizedBox.shrink(); final history = box.values.cast<String>().toList(); return Column(children: history.map((query) { int index = history.indexOf(query); return ListTile(leading: const Icon(Icons.history, color: Colors.grey), title: Text(query, style: const TextStyle(color: Colors.white)), onTap: () { searchController.text = query; searchVideos(query); }, trailing: Row(mainAxisSize: MainAxisSize.min, children: [ IconButton(icon: const Icon(Icons.north_west, color: Colors.grey, size: 20), onPressed: () { searchController.text = query; searchController.selection = TextSelection.fromPosition(TextPosition(offset: searchController.text.length)); }), IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 20), onPressed: () { final newHistory = List<String>.from(history)..removeAt(index); box.clear(); box.addAll(newHistory); })])); }).toList()); }),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text("Escuchado Recientemente", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16))),
      ValueListenableBuilder(valueListenable: Hive.box('history').listenable(), builder: (context, Box box, _) { if (box.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text("Aún no hay canciones en tu registro.", style: TextStyle(color: Colors.grey))); final items = box.values.toList().cast<Map>()..sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0)); return Column(children: items.take(15).map((item) { return ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: item['artUri'], width: 50, height: 50, fit: BoxFit.cover)), title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(item['artist'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)), trailing: IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 20), onPressed: () => box.delete(item['id'])), onTap: () async { final mediaItem = MediaItem(id: item['id'], title: item['title'], artist: item['artist'], artUri: Uri.parse(item['artUri']), duration: Duration(milliseconds: item['duration'])); await globalPlay(mediaItem); }); }).toList()); }),
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
            image: const AssetImage('assets/ojo_pirata.png'), // <-- PON AQUÍ EL NOMBRE EXACTO DE TU IMAGEN
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
        else Expanded(child: StreamBuilder<MediaItem?>(stream: audioHandler.mediaItem, builder: (context, snapshot) { final currentId = snapshot.data?.id; return ListView.builder(padding: const EdgeInsets.only(bottom: 100), itemCount: videos.length, itemBuilder: (context, index) { final video = videos[index]; final isPlaying = currentId == video.id.value; return ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), leading: Stack(children: [ Hero(tag: video.id.value, child: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: video.thumbnails.mediumResUrl, width: 80, height: 50, fit: BoxFit.cover))), Positioned(bottom: 2, right: 2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)), child: Text(formatGlobalDuration(video.duration), style: const TextStyle(color: Colors.white, fontSize: 10)))) ]), title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)), subtitle: Text(video.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [ if (isPlaying) ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => Icon(Icons.equalizer, color: color, size: 24)), ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => IconButton(icon: const Icon(Icons.more_vert, color: Colors.grey), onPressed: () => globalShowOptions(context, video, color))) ]), onTap: () async { final queueItems = videos.map((vid) => MediaItem(id: vid.id.value, title: vid.title, artist: vid.author, duration: vid.duration, artUri: Uri.parse(vid.thumbnails.highResUrl))).toList(); await globalPlayQueue(queueItems, index); }); }); }))
      ])
    );
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

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});
  @override Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(stream: audioHandler.mediaItem, builder: (context, snapshot) { final mediaItem = snapshot.data; if (mediaItem == null) return const SizedBox.shrink(); return Dismissible(key: const Key('miniplayer_dismiss'), direction: DismissDirection.down, onDismissed: (_) => audioHandler.customAction('kill'), child: GestureDetector(onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => const FullScreenPlayer()), child: ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) { return Container(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: Colors.black.withOpacity(0.95), borderRadius: BorderRadius.circular(16), border: Border.all(color: color, width: 1.5), boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 12, spreadRadius: 3)]), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: Padding(padding: const EdgeInsets.all(8.0), child: Row(children: [ ClipRRect(borderRadius: BorderRadius.circular(10), child: CachedNetworkImage(imageUrl: mediaItem.artUri.toString(), width: 45, height: 45, fit: BoxFit.cover)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [ Text(mediaItem.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), Text(mediaItem.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)) ])), StreamBuilder<PlaybackState>(stream: audioHandler.playbackState, builder: (context, snapshot) { final playing = snapshot.data?.playing ?? false; return IconButton(icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 32), onPressed: () => playing ? audioHandler.pause() : audioHandler.play()); }), IconButton(icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 32), onPressed: () => audioHandler.skipToNext()) ]))))); }))); });
  }
}

class FullScreenPlayer extends StatelessWidget {
  const FullScreenPlayer({super.key});
  void _showSleepTimerDialog(BuildContext context) { showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF1A1A1A), title: const Text('Temporizador', style: TextStyle(color: Colors.white)), content: Column(mainAxisSize: MainAxisSize.min, children: [15, 30, 45, 60].map((mins) => ListTile(title: Text('$mins minutos', style: const TextStyle(color: Colors.white)), onTap: () { audioHandler.customAction('setSleepTimer', {'minutes': mins}); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Temporizador: $mins min'))); })).toList()), actions: [ TextButton(onPressed: () { audioHandler.customAction('cancelSleepTimer'); Navigator.pop(context); }, child: const Text('Cancelar Temporizador', style: TextStyle(color: Colors.redAccent))) ])); }
  String _formatDuration(Duration d) { final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0'); final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0'); return "${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds"; }
  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: StreamBuilder<MediaItem?>(stream: audioHandler.mediaItem, builder: (context, snapshot) {
        final mediaItem = snapshot.data; if (mediaItem == null) return const SizedBox.shrink();
        return Column(children: [
          Padding(padding: const EdgeInsets.only(top: 60.0, left: 12.0, right: 12.0, bottom: 8.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 36), onPressed: () => Navigator.pop(context)),
            Row(children: [
              // MEJORA VIP: Botón en la nevera principal
              Visibility(visible: false, child: IconButton(icon: const Icon(Icons.download, color: Colors.white, size: 28), onPressed: () => downloadAudio(context, mediaItem))),
              IconButton(icon: const Icon(Icons.timer_outlined, color: Colors.white, size: 28), onPressed: () => _showSleepTimerDialog(context)),
              ValueListenableBuilder(valueListenable: Hive.box('favorites').listenable(), builder: (context, Box box, _) { final isFav = box.containsKey(mediaItem.id); return IconButton(icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : Colors.white, size: 28), onPressed: () { if (isFav) { box.delete(mediaItem.id); } else { box.put(mediaItem.id, {'id': mediaItem.id, 'title': mediaItem.title, 'artist': mediaItem.artist, 'artUri': mediaItem.artUri?.toString(), 'duration': mediaItem.duration?.inMilliseconds ?? 0}); } }); }),
              IconButton(icon: const Icon(Icons.more_vert, color: Colors.white, size: 28), onPressed: () {}),
            ])
          ])),
          // MEJORA VIP: Hero Animation + Caché para la portada principal
          Expanded(flex: 4, child: SizedBox(width: double.infinity, child: Hero(tag: mediaItem.id, child: CachedNetworkImage(imageUrl: mediaItem.artUri.toString(), fit: BoxFit.cover, placeholder: (c,u)=>const Center(child: CircularProgressIndicator(color: Colors.white24)), errorWidget: (c,u,e)=>const Icon(Icons.music_note))))),
          Expanded(flex: 5, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const SizedBox(height: 20), Text(mediaItem.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(mediaItem.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 16)), const SizedBox(height: 30),
            
            // MEJORA VIP: Indicador de Buffer encima de la barra
            StreamBuilder<PlaybackState>(stream: audioHandler.playbackState, builder: (context, snapshotState) {
              final buffer = snapshotState.data?.bufferedPosition ?? Duration.zero;
              return Padding(padding: const EdgeInsets.only(bottom: 4.0), child: Align(alignment: Alignment.centerRight, child: Text("Buffer caché: ${_formatDuration(buffer)}", style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 11, fontWeight: FontWeight.bold))));
            }),
            
            StreamBuilder<Duration>(stream: AudioService.position, builder: (context, snapshotDuration) { final position = snapshotDuration.data ?? Duration.zero; final duration = mediaItem.duration ?? Duration.zero; return Row(children: [ Text(_formatDuration(position), style: const TextStyle(color: Colors.grey, fontSize: 12)), Expanded(child: SliderTheme(data: SliderThemeData(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)), child: ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) { return Slider(activeColor: color, inactiveColor: Colors.white24, value: position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()), max: duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0, onChanged: (val) => audioHandler.seek(Duration(milliseconds: val.toInt()))); }))), Text(_formatDuration(duration), style: const TextStyle(color: Colors.grey, fontSize: 12)), ]); }),
            const SizedBox(height: 20),
            StreamBuilder<PlaybackState>(stream: audioHandler.playbackState, builder: (context, snapshot) { final playing = snapshot.data?.playing ?? false; final isBuffering = snapshot.data?.processingState == AudioProcessingState.buffering || snapshot.data?.processingState == AudioProcessingState.loading; final currentPosition = snapshot.data?.position ?? Duration.zero; return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [ IconButton(icon: const Icon(Icons.fast_rewind, color: Colors.white, size: 28), onPressed: () => audioHandler.seek(currentPosition - const Duration(seconds: 10))), IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white, size: 36), onPressed: () => audioHandler.skipToPrevious()), isBuffering ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(color: Colors.white)) : IconButton(icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 54), onPressed: () => playing ? audioHandler.pause() : audioHandler.play()), IconButton(icon: const Icon(Icons.skip_next, color: Colors.white, size: 36), onPressed: () => audioHandler.skipToNext()), IconButton(icon: const Icon(Icons.fast_forward, color: Colors.white, size: 28), onPressed: () => audioHandler.seek(currentPosition + const Duration(seconds: 10))), ]); }),
          ]))),
          StreamBuilder<List<MediaItem>>(stream: audioHandler.queue, builder: (context, queueSnapshot) { final queue = queueSnapshot.data ?? []; final index = queue.indexWhere((item) => item.id == mediaItem.id); final displayIndex = index >= 0 ? index + 1 : 0; return GestureDetector(onTap: () { showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1A1A1A), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) => Column(children: [ const Padding(padding: EdgeInsets.all(16.0), child: Text("Cola de Reproducción", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))), Expanded(child: ListView.builder(itemCount: queue.length, itemBuilder: (context, i) { final qItem = queue[i]; final isCurrent = qItem.id == mediaItem.id; return ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(4.0), child: qItem.artUri != null ? CachedNetworkImage(imageUrl: qItem.artUri.toString(), width: 48, height: 48, fit: BoxFit.cover) : Container(width: 48, height: 48, color: Colors.grey[900], child: const Icon(Icons.music_note, color: Colors.grey))), title: Text(qItem.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isCurrent ? Colors.blueAccent : Colors.white)), subtitle: Text(qItem.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)), trailing: isCurrent ? const Icon(Icons.bar_chart, color: Colors.blueAccent) : null, onTap: () { audioHandler.skipToQueueItem(i); Navigator.pop(context); }); })) ])); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), color: Colors.transparent, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => Icon(Icons.keyboard_arrow_up, color: color, size: 20)), const Text("Reproduciendo ahora", style: TextStyle(color: Colors.white, fontSize: 14)), Text("$displayIndex / ${queue.length}", style: const TextStyle(color: Colors.grey, fontSize: 12)), ]), IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}) ]))); })
        ]);
      }))
    );
  }
}
class CerrojoScreen extends StatefulWidget { const CerrojoScreen({super.key}); @override State<CerrojoScreen> createState() => _CerrojoScreenState(); }
class _CerrojoScreenState extends State<CerrojoScreen> {
  final TextEditingController _tokenController = TextEditingController(); final _cerrojoBox = Hive.box('cerrojo_box'); bool _error = false;
  void _validarToken() { 
    final tokenIngresado = _tokenController.text.trim(); 
    
    // Verificamos si es una llave maestra de Apex
    if (tokenIngresado.startsWith('APX-')) { 
      try {
        // 1. Quitamos el 'APX-' y desencriptamos
        final base64String = tokenIngresado.substring(4);
        final rawData = utf8.decode(base64Decode(base64String)); 
        
        // 2. Partimos los datos (ej: "6573|1|0|0|30")
        final partes = rawData.split('|');

        if (partes.length == 5) {
          // El índice 2 es la Bóveda (0 = Apagada, 1 = Encendida)
          final tieneBoveda = partes[2] == '1'; 

          _cerrojoBox.put('acceso_concedido', true); 
          _cerrojoBox.put('token_activo', tokenIngresado); 
          _cerrojoBox.put('is_plus_user', tieneBoveda); 
          
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SuperAppSkeleton())); 
        } else {
          setState(() { _error = true; }); 
        }
      } catch (e) {
        setState(() { _error = true; }); 
      }
    } 
    else { 
      setState(() { _error = true; }); 
    } 
  }
  @override Widget build(BuildContext context) { return Scaffold(backgroundColor: const Color(0xFF111111), body: Padding(padding: const EdgeInsets.all(32.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [ const Icon(Icons.lock_outline, size: 80, color: Color(0xFF4ADE80)), const SizedBox(height: 32), const Text('Acceso Restringido', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 2.0)), const SizedBox(height: 16), const Text('Ingresa tu token de seguridad para continuar.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)), const SizedBox(height: 48), TextField(controller: _tokenController, style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 18, letterSpacing: 1.5), decoration: InputDecoration(hintText: 'Pega tu TKN aquí...', hintStyle: const TextStyle(color: Colors.white24), errorText: _error ? 'Token inválido o sin permisos' : null, enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4ADE80))))), const SizedBox(height: 32), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4ADE80), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: _validarToken, child: const Text('VALIDAR ACCESO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16))) ]))); }
}

Future<void> downloadAudio(BuildContext context, dynamic item) async {
  final scaffoldMessenger = ScaffoldMessenger.of(context); final navigator = Navigator.of(context, rootNavigator: true);
  showDialog(context: context, barrierDismissible: true, builder: (context) => const AlertDialog(backgroundColor: Color(0xFF1A1A1A), title: Text('Descargando pista', style: TextStyle(color: Colors.white)), content: Column(mainAxisSize: MainAxisSize.min, children: [ Text('Buscando fuente alternativa segura...', style: TextStyle(color: Colors.grey, fontSize: 14)), SizedBox(height: 20), LinearProgressIndicator(color: Color(0xFF4ADE80)), ]), ));
  try {
    final isMediaItem = item is MediaItem; final String originalVideoId = isMediaItem ? item.id : item.id.value; final String videoTitle = item.title;
    String artist = 'Desconocido'; String artUri = ''; int duration = 0;
    if (isMediaItem) { artist = item.artist ?? 'Desconocido'; artUri = item.artUri?.toString() ?? ''; duration = item.duration?.inMilliseconds ?? 0; } else { try { artist = item.author; } catch (e) {} try { artUri = item.thumbnails.highestResUrl; } catch (e) {} try { duration = item.duration.inMilliseconds; } catch (e) {} }
    final ytClient = YoutubeExplode(); final searchQuery = '$videoTitle $artist audio'; final searchResults = await ytClient.search.search(searchQuery);
    if (searchResults.isEmpty) throw Exception('No se encontró una versión alternativa de esta pista.');
    final ghostVideo = searchResults.first; final ghostVideoId = ghostVideo.id.value;
    final safeFileId = originalVideoId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\]'), ''); final dir = await getApplicationDocumentsDirectory();
    final manifest = await ytClient.videos.streamsClient.getManifest(ghostVideoId);
    final streamMp4 = manifest.audioOnly.where((s) => s.container.name == 'mp4'); final streamInfo = streamMp4.isNotEmpty ? streamMp4.withHighestBitrate() : manifest.audioOnly.withHighestBitrate();
    final ext = streamInfo.container.name; final savePath = '${dir.path}/$safeFileId.$ext'; final audioStream = ytClient.videos.streamsClient.get(streamInfo); final file = File(savePath); final fileStream = file.openWrite();
    try { await for (final chunk in audioStream.timeout(const Duration(seconds: 15))) { fileStream.add(chunk); } await fileStream.flush(); } catch (e) { throw Exception('La conexión se estranguló. Intenta de nuevo.'); } finally { await fileStream.close(); ytClient.close(); }
    final size = await file.length(); if (size == 0) throw Exception('El archivo se guardó vacío (0 bytes).');
    const boxName = 'downloads'; Box downloadsBox; if (Hive.isBoxOpen(boxName)) { downloadsBox = Hive.box(boxName); } else { downloadsBox = await Hive.openBox(boxName); }
    await downloadsBox.put(originalVideoId, {'id': originalVideoId, 'title': videoTitle, 'artist': artist, 'artUri': artUri, 'duration': duration, 'localPath': savePath});
    try { navigator.pop(); } catch (_) {} scaffoldMessenger.showSnackBar(const SnackBar(content: Text('¡Descarga completada! 🎵'), backgroundColor: Colors.green, duration: Duration(seconds: 4)));
  } catch (e) { try { navigator.pop(); } catch (_) {} scaffoldMessenger.showSnackBar(SnackBar(content: Text('🛑 ERROR: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 8))); }
}

class OfflineVaultScreen extends StatelessWidget {
  const OfflineVaultScreen({super.key});
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, appBar: AppBar(title: const Text('Bóveda Offline', style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1A1A1A), iconTheme: const IconThemeData(color: Colors.white)), body: ValueListenableBuilder(valueListenable: Hive.box('downloads').listenable(), builder: (context, Box box, _) { if (box.isEmpty) { return const Center(child: Text('Tu bóveda está vacía.\n¡Descarga música para escucharla sin conexión!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16))); } return ListView.builder(itemCount: box.length, itemBuilder: (context, index) { final key = box.keyAt(index); final item = box.get(key); return ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(4.0), child: item['artUri'] != null && item['artUri'].toString().isNotEmpty ? CachedNetworkImage(imageUrl: item['artUri'].toString(), width: 48, height: 48, fit: BoxFit.cover, errorWidget: (c, e, s) => Container(width: 48, height: 48, color: Colors.grey[900], child: const Icon(Icons.music_note, color: Colors.grey))) : Container(width: 48, height: 48, color: Colors.grey[900], child: const Icon(Icons.music_note, color: Colors.grey))), title: Text(item['title'] ?? 'Desconocido', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)), subtitle: Text(item['artist'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [ IconButton(icon: const Icon(Icons.play_arrow, color: Colors.blueAccent), onPressed: () async { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bóveda: Reproduciendo ${item['title']}...'))); try { await audioHandler.customAction('playLocal', {'localPath': item['localPath'], 'id': item['id'], 'title': item['title'], 'artist': item['artist'] ?? 'Bóveda Offline', 'artUri': item['artUri'] ?? '', 'duration': item['duration'] ?? 0}); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de conexión local: $e'))); } }), IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () { try{ final file = File(item['localPath']); if(file.existsSync()){ file.deleteSync(); } }catch(e){ print("Error borrando archivo local: $e"); } box.delete(key); }) ])); }); }));
  }
}
