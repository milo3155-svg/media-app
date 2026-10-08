// ============================================================================
// ARCHIVO: home_screen.dart
// ============================================================================
import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Importa las variables globales y funciones desde main.dart
import 'main.dart';
import 'download_service.dart';

// ============================================================================
// === BLOQUE 1: PANTALLA PRINCIPAL (HOME) ===
// ============================================================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Fondo transparente para que deje ver el Ojo Pirata de main.dart
    return Scaffold(
      backgroundColor: Colors.transparent, 
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text("Radar Global", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildSectionTitle('Tendencias'),
              _buildHorizontalList('history'),
              const SizedBox(height: 20),
              _buildSectionTitle('Escuchados Recientemente'),
              _buildHorizontalList('history'),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildHorizontalList(String boxName) {
    return SizedBox(
      height: 180,
      child: ValueListenableBuilder(
        valueListenable: Hive.box(boxName).listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) return const Center(child: Text("Sección vacía", style: TextStyle(color: Colors.grey)));
          final items = box.values.toList().reversed.take(10).toList();
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return GestureDetector(
                onTap: () async {
                  final mediaItem = MediaItem(
                    id: item['id'],
                    title: item['title'],
                    artist: item['artist'],
                    artUri: Uri.parse(item['artUri']),
                  );
                  await globalPlay(mediaItem);
                },
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: item['artUri'],
                          width: 120, height: 120, fit: BoxFit.cover,
                          errorWidget: (context, url, error) => const Icon(Icons.error),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      Text(item['artist'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// === BLOQUE 2: MOTOR DE BÚSQUEDA Y REPRODUCCIÓN (LISTA PURA) ===
// ============================================================================
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final searchController = TextEditingController();
  late final YoutubeExplode yt;
  List<Video> videos = []; // <-- LISTA BLINDADA (El audio funcionará al 100%)
  List<String> searchSuggestions = [];
  bool isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    yt = YoutubeExplode();
    Permission.notification.request();
  }
  @override
  void dispose() {
    _debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.trim().isEmpty) {
      setState(() { searchSuggestions.clear(); videos.clear(); });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final suggestions = await yt.search.getQuerySuggestions(query.trim());
        if (mounted) setState(() => searchSuggestions = suggestions.toList());
      } catch (_) {}
    });
  }

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
    if (query.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    _saveSearchHistory(query);
    setState(() { isLoading = true; searchSuggestions.clear(); videos.clear(); });
    try {
      final results = await yt.search.search(query);
      if (mounted) setState(() { videos = results.toList(); isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildSuggestionsList() {
    return ListView.builder(
      itemCount: searchSuggestions.length,
      itemBuilder: (context, index) {
        final suggestion = searchSuggestions[index];
        return ListTile(
          leading: const Icon(Icons.search, color: Colors.grey),
          title: Text(suggestion, style: const TextStyle(color: Colors.white)),
          onTap: () { searchController.text = suggestion; searchVideos(suggestion); },
        );
      },
    );
  }

  Widget _buildSearchHistory() {
    return ValueListenableBuilder(
      valueListenable: Hive.box('search_history').listenable(),
      builder: (context, Box box, _) {
        if (box.isEmpty) return const Center(child: Text("Radar inactivo.", style: TextStyle(color: Colors.grey, fontSize: 16)));
        return ListView.builder(
          itemCount: box.length,
          itemBuilder: (context, index) {
            final query = box.getAt(index) as String;
            return ListTile(
              leading: const Icon(Icons.history, color: Colors.grey),
              title: Text(query, style: const TextStyle(color: Colors.white)),
              trailing: IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 20), onPressed: () => box.deleteAt(index)),
              onTap: () { searchController.text = query; searchVideos(query); },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea( // <-- ESTO BAJA LA PANTALLA
      child: Scaffold(
        backgroundColor: Colors.transparent, // Fondo transparente para el Ojo Pirata
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                border: const Border(bottom: BorderSide(color: Colors.white10, width: 1))
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                      child: Row(
                        children: [
                          const Icon(Icons.radar, color: Color(0xFF4ADE80), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                              decoration: const InputDecoration(hintText: 'Intercepción de señal...', hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none),
                              onChanged: _onQueryChanged,
                              onSubmitted: searchVideos,
                            ),
                          ),
                          if (searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                              onPressed: () { searchController.clear(); _onQueryChanged(''); }
                            )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (searchSuggestions.isNotEmpty && videos.isEmpty)
              Expanded(child: _buildSuggestionsList())
            else if (videos.isEmpty)
              Expanded(child: _buildSearchHistory())
            else
              Expanded(
                child: StreamBuilder<MediaItem?>(
                  stream: audioHandler.mediaItem,
                  builder: (context, snapshot) {
                    final currentId = snapshot.data?.id;
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: videos.length,
                      itemBuilder: (context, index) {
                        final video = videos[index]; // LISTA PURA
                        final isPlaying = currentId == video.id.value;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Stack(children: [
                            Hero(
                              tag: video.id.value,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: video.thumbnails.mediumResUrl,
                                  width: 80, height: 50, fit: BoxFit.cover,
                                )
                              )
                            ),
                            Positioned(
                              bottom: 2, right: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                                child: Text(formatGlobalDuration(video.duration), style: const TextStyle(color: Colors.white, fontSize: 10))
                              )
                            )
                          ]),
                          title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(video.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isPlaying)
                                 ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => Icon(Icons.equalizer, color: color, size: 24)),
                              ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => IconButton(icon: const Icon(Icons.more_vert, color: Colors.grey), onPressed: () => globalShowOptions(context, video, color))),
                            ]
                          ),
                          onTap: () async {
                            final queueItems = videos.map((vid) => MediaItem(
                              id: vid.id.value,
                              title: vid.title,
                              artist: vid.author,
                              duration: vid.duration,
                              artUri: Uri.parse(vid.thumbnails.highResUrl),
                            )).toList();
                            await globalPlayQueue(queueItems, index);
                          },
                        );
                      },
                    );
                  },
                ),
              )
          ],
        ),
      ),
    );
  }
}
// ============================================================================
// === BLOQUE 3: LA BÓVEDA (LISTAS GUARDADAS) ===
// ============================================================================
class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent, // Fondo transparente
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('La Bóveda', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            indicatorColor: Color(0xFF4ADE80),
            tabs: [
              Tab(icon: Icon(Icons.history), text: "Historial"),
              Tab(icon: Icon(Icons.favorite), text: "Favoritos"),
              Tab(icon: Icon(Icons.queue_music), text: "Playlists"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ValueListenableBuilder(
              valueListenable: Hive.box('history').listenable(),
              builder: (context, Box box, _) => _buildList(box.values.toList().reversed.toList(), 'history'),
            ),
            ValueListenableBuilder(
              valueListenable: Hive.box('favorites').listenable(),
              builder: (context, Box box, _) => _buildList(box.values.toList().reversed.toList(), 'favorites'),
            ),
            ValueListenableBuilder(
              valueListenable: Hive.box('playlists').listenable(),
              builder: (context, Box box, _) {
                if (box.isEmpty) return const Center(child: Text("Sin playlists.", style: TextStyle(color: Colors.white)));
                return ListView(
                  children: box.keys.map((key) {
                    final playlist = box.get(key) as List;
                    return ExpansionTile(
                      leading: const Icon(Icons.playlist_play, color: Colors.white),
                      title: Text(key.toString(), style: const TextStyle(color: Colors.white)),
                      subtitle: Text('${playlist.length} pistas', style: const TextStyle(color: Colors.grey)),
                      children: playlist.map((item) => _buildListItem(item, box, key.toString())).toList(),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List items, String boxName) {
    if (items.isEmpty) return const Center(child: Text("Vacío", style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => _buildListItem(items[index], Hive.box(boxName), null),
    );
  }

  Widget _buildListItem(dynamic item, Box box, String? playlistKey) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl: item['artUri'],
          width: 50, height: 50, fit: BoxFit.cover,
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
      ),
      title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
      subtitle: Text(item['artist'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
      trailing: IconButton(
        icon: const Icon(Icons.close, color: Colors.grey),
        onPressed: () {
          if (playlistKey != null) {
            final playlist = box.get(playlistKey) as List;
            playlist.removeWhere((i) => i['id'] == item['id']);
            if (playlist.isEmpty) box.delete(playlistKey); else box.put(playlistKey, playlist);
          } else {
            box.delete(item['id']);
          }
        },
      ),
      onTap: () async {
        final mediaItem = MediaItem(
          id: item['id'],
          title: item['title'],
          artist: item['artist'],
          artUri: Uri.parse(item['artUri']),
        );
        await globalPlay(mediaItem);
      },
    );
  }
}

// ============================================================================
// === BLOQUE 4: PANTALLA DE ACCESO RESTRINGIDO (CERROJO VIP) ===
// ============================================================================
class CerrojoScreen extends StatefulWidget { 
  const CerrojoScreen({super.key}); 
  @override 
  State<CerrojoScreen> createState() => _CerrojoScreenState(); 
}

class _CerrojoScreenState extends State<CerrojoScreen> {
  final TextEditingController _tokenController = TextEditingController();
  bool _error = false;

  void _validarToken() {
    final token = _tokenController.text.trim();
    final cerrojoBox = Hive.box('cerrojo_box');

    if (token.isEmpty) return;

    if (token == 'APX-MASTER-VIP-2026') {
      cerrojoBox.put('acceso_concedido', true);
      cerrojoBox.put('is_plus_user', true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔓 Protocolo Máster Aceptado. Bienvenido, Creador.'), 
          backgroundColor: Colors.purpleAccent,
          duration: Duration(seconds: 2),
        ),
      );
      // ============================================================================
// === BLOQUE 5: BÓVEDA OFFLINE (DESCARGAS LOCALES) ===
// ============================================================================
class OfflineVaultScreen extends StatelessWidget {
  const OfflineVaultScreen({super.key});
  
  @override 
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, 
      appBar: AppBar(title: const Text('Bóveda Offline', style: TextStyle(color: Colors.white)), backgroundColor: Colors.transparent, centerTitle: true),
      body: ValueListenableBuilder(
        valueListenable: Hive.box('downloads').listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) return const Center(child: Text("Bóveda vacía", style: TextStyle(color: Colors.grey)));
          return ListView.builder(
            itemCount: box.length,
            itemBuilder: (context, index) {
              final key = box.keyAt(index);
              final item = box.get(key);
              return ListTile(
                leading: const Icon(Icons.offline_pin, color: Colors.greenAccent),
                title: Text(item['title'] ?? 'Desconocido', maxLines: 1, style: const TextStyle(color: Colors.white)),
                subtitle: Text(item['artist'] ?? '', maxLines: 1, style: const TextStyle(color: Colors.grey)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.grey),
                  onPressed: () async {
                    if (item['path'] != null) {
                      try {
                        final file = File(item['path']);
                        if (await file.exists()) await file.delete();
                      } catch (e) { print("Error borrando archivo local: $e"); }
                    }
                    box.delete(key);
                  }
                ),
                onTap: () {
                  if (item['path'] != null) {
                    audioHandler.customAction('playLocal', {'localPath': item['path'], 'id': key, 'title': item['title']});
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ruta local no encontrada")));
                  }
                }
              );
            }
          );
        }
      )
    );
  }
}

// ============================================================================
// === BLOQUE 6: PANTALLA DE DEPORTES (ESTRUCTURA BÁSICA) ===
// ============================================================================
class SportsScreen extends StatelessWidget {
  const SportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_soccer, size: 80, color: Colors.white.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              "Zona VIP",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Próximamente disponible...",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
// ============================================================================
// === BLOQUE 7: MINI REPRODUCTOR FLOTANTE ===
// ============================================================================
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override 
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final item = snapshot.data;
        if (item == null) return const SizedBox.shrink();
        
        return GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context, 
              isScrollControlled: true, 
              backgroundColor: Colors.transparent,
              builder: (context) => const FullScreenPlayer()
            );
          },
          child: Container(
            height: 65, 
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                  child: CachedNetworkImage(imageUrl: item.artUri.toString(), width: 65, height: 65, fit: BoxFit.cover, errorWidget: (c, u, e) => Container(width: 65, height: 65, color: Colors.grey)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(item.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                StreamBuilder<PlaybackState>(
                  stream: audioHandler.playbackState,
                  builder: (context, stateSnapshot) {
                    final state = stateSnapshot.data;
                    final playing = state?.playing ?? false;
                    final isLoading = state?.processingState == AudioProcessingState.loading || state?.processingState == AudioProcessingState.buffering;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValueListenableBuilder<Color>(
                          valueListenable: appColor,
                          builder: (context, color, _) {
                            if (isLoading) return Container(margin: const EdgeInsets.all(12), width: 24, height: 24, child: CircularProgressIndicator(color: color, strokeWidth: 2));
                            return IconButton(icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: color, size: 28), onPressed: () => playing ? audioHandler.pause() : audioHandler.play());
                          }
                        ),
                        IconButton(icon: const Icon(Icons.skip_next, color: Colors.white, size: 28), onPressed: () => audioHandler.skipToNext()),
                      ],
                    );
                  }
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// === BLOQUE 8: REPRODUCTOR PANTALLA COMPLETA ===
// ============================================================================
class FullScreenPlayer extends StatelessWidget {
  const FullScreenPlayer({super.key});
  
  String _formatDuration(Duration? d) {
    if (d == null) return "00:00";
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds";
  }

  @override 
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF0A0A0A)),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32), onPressed: () => Navigator.pop(context)),
                  const Text("Reproduciendo ahora", style: TextStyle(color: Colors.grey, fontSize: 14)),
                  IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<MediaItem?>(
                stream: audioHandler.mediaItem,
                builder: (context, snapshot) {
                  final item = snapshot.data;
                  if (item == null) return const Center(child: CircularProgressIndicator());
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Hero(
                          tag: item.id,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: CachedNetworkImage(imageUrl: item.artUri.toString(), fit: BoxFit.cover, errorWidget: (c, u, e) => Container(color: Colors.grey)),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(item.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                                ],
                              ),
                            ),
                            ValueListenableBuilder(
                              valueListenable: Hive.box('favorites').listenable(),
                              builder: (context, Box box, _) {
                                final isFav = box.containsKey(item.id);
                                return IconButton(
                                  icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : Colors.white, size: 30),
                                  onPressed: () {
                                    if (isFav) box.delete(item.id);
                                    else box.put(item.id, {'id': item.id, 'title': item.title, 'artist': item.artist, 'artUri': item.artUri.toString(), 'duration': item.duration?.inMilliseconds ?? 0});
                                  }
                                );
                              }
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: StreamBuilder<PlaybackState>(
                          stream: audioHandler.playbackState,
                          builder: (context, stateSnapshot) {
                            final state = stateSnapshot.data;
                            final position = state?.updatePosition ?? Duration.zero;
                            final duration = item.duration ?? Duration.zero;
                            
                            return Column(
                              children: [
                                ValueListenableBuilder<Color>(
                                  valueListenable: appColor,
                                  builder: (context, color, _) {
                                    return SliderTheme(
                                      data: SliderThemeData(trackHeight: 4, activeTrackColor: color, inactiveTrackColor: Colors.white24, thumbColor: color, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), overlayShape: const RoundSliderOverlayShape(overlayRadius: 14)),
                                      child: Slider(
                                        min: 0.0,
                                        max: duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0,
                                        value: (position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0)),
                                        onChanged: (val) => audioHandler.seek(Duration(milliseconds: val.round())),
                                      ),
                                    );
                                  }
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_formatDuration(position), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    Text(_formatDuration(duration), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ],
                            );
                          }
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(icon: const Icon(Icons.shuffle, color: Colors.grey), onPressed: () {}),
                            IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white, size: 40), onPressed: () => audioHandler.skipToPrevious()),
                            StreamBuilder<PlaybackState>(
                              stream: audioHandler.playbackState,
                              builder: (context, stateSnapshot) {
                                final playing = stateSnapshot.data?.playing ?? false;
                                return ValueListenableBuilder<Color>(
                                  valueListenable: appColor,
                                  builder: (context, color, _) {
                                    return Container(
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                                      child: IconButton(icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 50), onPressed: () => playing ? audioHandler.pause() : audioHandler.play()),
                                    );
                                  }
                                );
                              }
                            ),
                            IconButton(icon: const Icon(Icons.skip_next, color: Colors.white, size: 40), onPressed: () => audioHandler.skipToNext()),
                            IconButton(icon: const Icon(Icons.repeat, color: Colors.grey), onPressed: () {}),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }