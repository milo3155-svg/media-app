import 'dart:io';
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math' as math;
import 'dart:async'; 

class VIPHttpOverrides extends HttpOverrides {
  @override HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36';
  }
}

late MyAudioHandler audioHandler;
final ValueNotifier<bool> isHDMode = ValueNotifier<bool>(true);
final ValueNotifier<Color> appColor = ValueNotifier<Color>(Colors.cyanAccent); 
final ValueNotifier<int> sleepTimerRemaining = ValueNotifier<int>(0); 

String formatGlobalDuration(Duration? d) {
  if (d == null) return "Live";
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return "${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds";
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = VIPHttpOverrides();
  await Hive.initFlutter();
  await Hive.openBox('favorites'); await Hive.openBox('history'); await Hive.openBox('search_history'); 
  await Hive.openBox('playlists'); 
  final session = await AudioSession.instance; await session.configure(const AudioSessionConfiguration.music());
  
  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(), 
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.media_app.audio_master_v62', 
      androidNotificationChannelName: 'Spotify Killer VIP', 
      androidNotificationOngoing: false, 
      androidShowNotificationBadge: true, 
      androidStopForegroundOnPause: false, 
      androidNotificationIcon: 'drawable/ic_notification' 
    )
  );
  runApp(const MediaApp());
}

class ConspiracyLogo extends StatelessWidget {
  final double size; final Color color; const ConspiracyLogo({super.key, this.size = 150.0, required this.color});
  @override Widget build(BuildContext context) { return SizedBox(width: size, height: size, child: CustomPaint(painter: _OsirisEyePainter(color: color))); }
}
class _OsirisEyePainter extends CustomPainter {
  final Color color; _OsirisEyePainter({required this.color});
  void _drawTextOnLine(Canvas canvas, String text, Offset start, Offset end, double fontSize) {
    final midPoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2); final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    canvas.save(); canvas.translate(midPoint.dx, midPoint.dy); canvas.rotate(angle);
    final textSpan = TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'Courier'));
    // EL PARCHE ESTÁ AQUÍ: Regresamos el parámetro 'text:' que rompí por error
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr); textPainter.layout(); textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height - 2)); canvas.restore();
  }
  @override void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = w * 0.05..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round;
    final p1 = Offset(w * 0.15, h * 0.15); final p2 = Offset(w * 0.15, h * 0.85); final p3 = Offset(w * 0.90, h * 0.50); 
    final playPath = Path()..moveTo(p1.dx, p1.dy)..lineTo(p2.dx, p2.dy)..lineTo(p3.dx, p3.dy)..close(); canvas.drawPath(playPath, paint);
    final fontSize = w * 0.08; _drawTextOnLine(canvas, "Θ ⅃ Θ", p1, p2, fontSize); _drawTextOnLine(canvas, "Δ Ξ", p2, p3, fontSize); _drawTextOnLine(canvas, "Θ Ϟ Ι ℟ Ι Ϟ", p3, p1, fontSize);
    final eyeLeft = w * 0.28; final eyeRight = w * 0.62; final eyeY = h * 0.50; final eyeCenterX = w * 0.45;
    final eyePath = Path()..moveTo(eyeLeft, eyeY)..quadraticBezierTo(eyeCenterX, h * 0.32, eyeRight, eyeY)..quadraticBezierTo(eyeCenterX, h * 0.68, eyeLeft, eyeY); canvas.drawPath(eyePath, paint);
    final wavePaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = w * 0.03; canvas.drawCircle(Offset(eyeCenterX, h * 0.50), w * 0.08, wavePaint); canvas.drawCircle(Offset(eyeCenterX, h * 0.50), w * 0.03, wavePaint); canvas.drawLine(Offset(eyeCenterX - w * 0.12, h * 0.50), Offset(eyeCenterX + w * 0.12, h * 0.50), wavePaint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
class 
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer(); 
  late final YoutubeExplode _yt; 
  Timer? _countdownTimer; 
  bool _isTransitioning = false; 

  MyAudioHandler() {
    _yt = YoutubeExplode();
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing; 
      if (!playing && mediaItem.value != null) { 
        _saveResumePosition(mediaItem.value!.id, _player.position.inMilliseconds); 
      }
      playbackState.add(playbackState.value.copyWith(
        controls: [MediaControl.skipToPrevious, if (playing) MediaControl.pause else MediaControl.play, MediaControl.skipToNext], 
        systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward}, 
        androidCompactActionIndices: const [0, 1, 2], 
        processingState: const { ProcessingState.idle: AudioProcessingState.idle, ProcessingState.loading: AudioProcessingState.loading, ProcessingState.buffering: AudioProcessingState.buffering, ProcessingState.ready: AudioProcessingState.ready, ProcessingState.completed: AudioProcessingState.completed }[_player.processingState]!, 
        playing: playing, updatePosition: _player.position, bufferedPosition: _player.bufferedPosition, speed: _player.speed
      ));
    });
    _player.processingStateStream.listen((state) { if (state == ProcessingState.completed) { _onTrackFinished(); } });
    _player.positionStream.listen((pos) {
      final dur = _player.duration;
      if (dur != null && dur.inSeconds > 10) {
        if (dur.inMilliseconds - pos.inMilliseconds <= 800 && !_isTransitioning) { _onTrackFinished(); }
      }
    });
  }

  void _onTrackFinished() {
    if (_isTransitioning) return;
    _isTransitioning = true;
    _handleAutoPlayRadio();
  }

  Future<void> _handleAutoPlayRadio() async {
    final currentQueue = queue.value; 
    final currentItem = mediaItem.value; 
    if (currentItem == null) { _isTransitioning = false; return; }

    final currentIndex = currentQueue.indexWhere((item) => item.id == currentItem.id);
    if (currentIndex != -1 && currentIndex < currentQueue.length - 1) { 
      await skipToNextBase(); 
      _isTransitioning = false; return;
    }

    try {
      Video? nextVideo;
      try {
        var currentVideo = await _yt.videos.get(currentItem.id);
        var relatedVideos = await _yt.videos.getRelatedVideos(currentVideo);
        if (relatedVideos != null && relatedVideos.isNotEmpty) {
          String clean1 = currentItem.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9áéíóúñ\s]'), ''); 
          Set<String> words1 = clean1.split(' ').where((w) => w.length > 2).toSet();
          for (var v in relatedVideos) {
            bool isClone = false; 
            String clean2 = v.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9áéíóúñ\s]'), ''); 
            Set<String> words2 = clean2.split(' ').where((w) => w.length > 2).toSet();
            if (words1.isNotEmpty && words2.isNotEmpty) { 
              int matches = words1.intersection(words2).length; 
              double similarity = matches / math.min(words1.length, words2.length); 
              if (similarity >= 0.5) isClone = true; 
            }
            if (isClone) continue; 
            nextVideo = v; break; 
          }
          nextVideo ??= relatedVideos.first;
        }
      } catch (_) {}

      if (nextVideo == null) {
        final query = "${currentItem.artist} mix";
        final searchResults = await _yt.search.search(query);
        final list = searchResults.where((v) => v.id.value != currentItem.id).toList();
        if (list.isNotEmpty) nextVideo = list.first;
      }

      if (nextVideo != null) {
        final newItem = MediaItem(id: nextVideo.id.value, title: nextVideo.title, artist: nextVideo.author, duration: nextVideo.duration, artUri: Uri.parse(nextVideo.thumbnails.highResUrl));
        final newQueue = List<MediaItem>.from(currentQueue)..add(newItem); 
        await updateQueue(newQueue); 
        await playMediaItem(newItem);
      }
    } catch (e) { } finally { _isTransitioning = false; }
  }

  void _saveResumePosition(String id, int milliseconds) { final historyBox = Hive.box('history'); if (historyBox.containsKey(id)) { final item = Map<String, dynamic>.from(historyBox.get(id)); item['savedPosition'] = milliseconds; historyBox.put(id, item); } }
  
  @override Future<void> customAction(String name, [Map<String, dynamic>? extras]) async { 
    if (name == 'kill') {
      await _player.stop();
      mediaItem.add(null);
      queue.add([]);
      return;
    }
    if (name == 'setSleepTimer' && extras != null) { 
      int minutes = extras['minutes']; _countdownTimer?.cancel(); 
      if (minutes > 0) { 
        sleepTimerRemaining.value = minutes * 60; 
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) { if (sleepTimerRemaining.value > 0) { sleepTimerRemaining.value--; } else { pause(); timer.cancel(); } }); 
      } else { sleepTimerRemaining.value = 0; } 
    } 
  }
  @override Future<void> play() => _player.play(); 
  @override Future<void> pause() => _player.pause(); 
  @override Future<void> seek(Duration position) => _player.seek(position);
  
  @override Future<void> skipToNext() async { 
    final queueList = queue.value; final currentItem = mediaItem.value; 
    final currentIndex = queueList.indexWhere((item) => item.id == currentItem?.id); 
    if (currentIndex != -1 && currentIndex < queueList.length - 1) { await playMediaItem(queueList[currentIndex + 1]); } 
    else { _onTrackFinished(); }
  }

  Future<void> skipToNextBase() async {
    final queueList = queue.value; final currentItem = mediaItem.value; final currentIndex = queueList.indexWhere((item) => item.id == currentItem?.id); if (currentIndex != -1 && currentIndex < queueList.length - 1) await playMediaItem(queueList[currentIndex + 1]);
  }

  @override Future<void> skipToPrevious() async { final queueList = queue.value; if (queueList.isEmpty) return; final currentItem = mediaItem.value; final currentIndex = queueList.indexWhere((item) => item.id == currentItem?.id); if (currentIndex > 0) await playMediaItem(queueList[currentIndex - 1]); }

  @override
  Future<void> playMediaItem(MediaItem item) async {
    mediaItem.add(item); 
    final historyBox = Hive.box('history'); 
    int playCount = 1; int savedPosition = 0; 
    if (historyBox.containsKey(item.id)) { final existingItem = historyBox.get(item.id); playCount = (existingItem['playCount'] ?? 0) + 1; savedPosition = existingItem['savedPosition'] ?? 0; }
    historyBox.put(item.id, {'id': item.id, 'title': item.title, 'artist': item.artist, 'artUri': item.artUri.toString(), 'duration': item.duration?.inMilliseconds ?? 0, 'timestamp': DateTime.now().millisecondsSinceEpoch, 'playCount': playCount, 'savedPosition': 0});
    try {
      playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.loading, playing: true));
      await _player.stop(); 
      await _player.seek(Duration.zero); 
      var manifest = await _yt.videos.streamsClient.getManifest(item.id); 
      var video = await _yt.videos.get(item.id); 
      
      StreamInfo streamInfo;
      if (manifest.muxed.isNotEmpty) { streamInfo = isHDMode.value ? manifest.muxed.withHighestBitrate() : manifest.muxed.reduce((a, b) => a.bitrate.bitsPerSecond < b.bitrate.bitsPerSecond ? a : b); } 
      else if (manifest.audioOnly.isNotEmpty) { streamInfo = isHDMode.value ? manifest.audioOnly.withHighestBitrate() : manifest.audioOnly.reduce((a, b) => a.bitrate.bitsPerSecond < b.bitrate.bitsPerSecond ? a : b); } 
      else { throw Exception("No streams"); }
      
      final cachingSource = LockCachingAudioSource(
        Uri.parse(streamInfo.url.toString()),
        tag: item.copyWith(
          duration: video.duration, 
          title: video.title,       
        ),
      );
      await _player.setAudioSource(cachingSource);
      
      if (savedPosition > 0) { await _player.seek(Duration(milliseconds: savedPosition)); } 
      await _player.play();
    } catch (e) { playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.error, playing: false)); }
  }
  @override Future<void> updateQueue(List<MediaItem> newQueue) async { queue.add(newQueue); }
  void shuffleQueue() { final currentQueue = queue.value.toList()..shuffle(); queue.add(currentQueue); }
}

Future<void> globalPlay(MediaItem item) async {
  await audioHandler.updateQueue([item]); 
  await audioHandler.playMediaItem(item);
}

Future<void> globalPlayQueue(List<MediaItem> items, int startIndex) async {
  await audioHandler.updateQueue(items);
  await audioHandler.playMediaItem(items[startIndex]);
}

void globalShowOptions(BuildContext context, Video video, Color color) {
  showModalBottomSheet(
    context: context, backgroundColor: const Color(0xFF1A1A1A), isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), 
    builder: (context) { 
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10), 
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(video.thumbnails.lowResUrl, width: 40, height: 40, fit: BoxFit.cover)), title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(video.author, style: const TextStyle(color: Colors.grey))), 
            const Divider(color: Colors.white24), 
            ListTile(leading: const Icon(Icons.radio, color: Colors.white), title: const Text('Ir a radio de la canción'), onTap: () async { Navigator.pop(context); final newItem = MediaItem(id: video.id.value, title: video.title, artist: video.author, duration: video.duration, artUri: Uri.parse(video.thumbnails.highResUrl)); await globalPlay(newItem); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Iniciando Radio de ${video.title}'), backgroundColor: color)); }),
            ListTile(leading: const Icon(Icons.playlist_add, color: Colors.white), title: const Text('Agregar a una playlist'), onTap: () { Navigator.pop(context); _showPlaylistDialog(context, video, color); }),
            ValueListenableBuilder(
              valueListenable: Hive.box('favorites').listenable(),
              builder: (context, Box box, _) {
                final isFav = box.containsKey(video.id.value);
                return ListTile(
                  leading: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : Colors.white), 
                  title: Text(isFav ? 'Eliminar de Tus me gusta' : 'Agregar a Tus me gusta'), 
                  onTap: () { 
                    if (isFav) { box.delete(video.id.value); } else { box.put(video.id.value, {'id': video.id.value, 'title': video.title, 'artist': video.author, 'artUri': video.thumbnails.highResUrl, 'duration': video.duration?.inMilliseconds ?? 0}); }
                    Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isFav ? 'Eliminado de Favoritos' : 'Agregado a Favoritos'), backgroundColor: color)); 
                  }
                );
              }
            ),
          ]
        )
      ); 
    }
  ); 
}

void _showPlaylistDialog(BuildContext context, Video video, Color color) {
  final box = Hive.box('playlists');
  final songData = {'id': video.id.value, 'title': video.title, 'artist': video.author, 'artUri': video.thumbnails.highResUrl, 'duration': video.duration?.inMilliseconds ?? 0};
  showDialog(
    context: context, 
    builder: (context) => AlertDialog(backgroundColor: const Color(0xFF1A1A1A), title: const Text("Mis Playlists", style: TextStyle(color: Colors.white)), content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Icon(Icons.add, color: Colors.white), title: const Text("Crear Nueva Playlist", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), onTap: () { Navigator.pop(context); _showCreatePlaylistDialog(context, songData, color); }), const Divider(color: Colors.white24),
            if (box.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text("No tienes playlists aún", style: TextStyle(color: Colors.grey)))
            else ...box.keys.map((key) => ListTile(leading: const Icon(Icons.queue_music, color: Colors.grey), title: Text(key.toString(), style: const TextStyle(color: Colors.white)), onTap: () {
                List currentList = box.get(key) ?? []; if (!currentList.any((s) => s['id'] == songData['id'])) { currentList.add(songData); box.put(key, currentList); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Agregada a $key'), backgroundColor: color)); } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ya está en esta playlist'), backgroundColor: Colors.redAccent)); } Navigator.pop(context);
              })).toList()
          ])))
  );
}

void _showCreatePlaylistDialog(BuildContext context, Map songData, Color color) {
  final textController = TextEditingController();
  showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF1A1A1A), title: const Text("Nueva Playlist", style: TextStyle(color: Colors.white)), content: TextField(controller: textController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Nombre de la playlist", hintStyle: const TextStyle(color: Colors.grey), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: color)), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: color)))), actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
        TextButton(onPressed: () { if (textController.text.trim().isNotEmpty) { Hive.box('playlists').put(textController.text.trim(), [songData]); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Playlist creada'), backgroundColor: color)); } }, child: Text("Crear", style: TextStyle(color: color, fontWeight: FontWeight.bold)))
      ]));
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});
  @override Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: appColor, builder: (context, color, _) {
        return MaterialApp(
          title: 'Spotify Killer VIP', debugShowCheckedModeBanner: false, 
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF0D0D0D), 
            primaryColor: color, 
            bottomNavigationBarTheme: BottomNavigationBarThemeData(backgroundColor: Colors.transparent, selectedItemColor: color, unselectedItemColor: Colors.grey, type: BottomNavigationBarType.fixed, elevation: 0), 
            appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0D0D0D), elevation: 0, centerTitle: true)
          ), 
          home: const SuperAppSkeleton()
        );
      }
    );
  }
}

class SuperAppSkeleton extends StatefulWidget { const SuperAppSkeleton({super.key}); @override State<SuperAppSkeleton> createState() => _SuperAppSkeletonState(); }
class _SuperAppSkeletonState extends State<SuperAppSkeleton> {
  int _currentIndex = 0; final List<Widget> _screens = const [HomeScreen(), SearchScreen(), VaultScreen()];
  @override Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _screens),
          const Positioned(left: 0, right: 0, bottom: 65, child: MiniPlayer()),
        ]
      ),
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: Container(
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), border: const Border(top: BorderSide(color: Colors.white10))),
            child: BottomNavigationBar(currentIndex: _currentIndex, onTap: (index) => setState(() => _currentIndex = index), items: const [BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'), BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'), BottomNavigationBarItem(icon: Icon(Icons.folder_special), label: 'Bóveda')])
          )
        )
      )
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  Widget _buildHorizontalList(List<Map> items) { return SizedBox(height: 180, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: items.length, padding: const EdgeInsets.symmetric(horizontal: 16), itemBuilder: (context, index) { final item = items[index]; return GestureDetector(onTap: () async { final newItem = MediaItem(id: item['id'], title: item['title'], artist: item['artist'], artUri: Uri.parse(item['artUri']), duration: Duration(milliseconds: item['duration'])); await globalPlay(newItem); }, child: Container(width: 140, margin: const EdgeInsets.only(right: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(item['artUri'], width: 140, height: 140, fit: BoxFit.cover)), const SizedBox(height: 8), Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text(item['artist'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12))]))); })); }
  @override Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(16.0), child: Text("Para ti", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))), ValueListenableBuilder(valueListenable: Hive.box('history').listenable(), builder: (context, Box box, _) { if (box.isEmpty) return const SizedBox.shrink(); final items = box.values.toList().cast<Map>()..sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0)); return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), child: Text("Escuchado recientemente", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), _buildHorizontalList(items.take(10).toList())]); }), const SizedBox(height: 100)]))));
  }
}

class SearchScreen extends StatefulWidget { const SearchScreen({super.key}); @override State<SearchScreen> createState() => _SearchScreenState(); }
class _SearchScreenState extends State<SearchScreen> {
  final searchController = TextEditingController(); late final YoutubeExplode _yt;
  List<Video> videos = []; List<String> searchSuggestions = []; bool isLoading = false;
  Timer? _debounce;
  
  final Map<String, String> _categories = {"Tendencias": "Tendencias musica en español", "Podcasts": "Podcasts en español", "Electrónica": "Electronic music mix", "Rock": "Rock clasico en español", "Relajación": "Musica relajante lofi"};

  @override void initState() { super.initState(); _yt = YoutubeExplode(); Permission.notification.request(); }
  @override void dispose() { _debounce?.cancel(); searchController.dispose(); super.dispose(); }

  void _saveSearchHistory(String query) { if (query.trim().isEmpty) return; final box = Hive.box('search_history'); List history = box.get('history') ?? []; history.remove(query); history.insert(0, query); if (history.length > 10) history = history.sublist(0, 10); box.put('history', history); }
  void searchVideos(String query) async { if (query.isEmpty) return; FocusScope.of(context).unfocus(); _saveSearchHistory(query); setState(() => isLoading = true); try { final results = await _yt.search.search(query); setState(() { videos = results.toList(); }); } catch (e) { } finally { setState(() => isLoading = false); } }

  Widget _buildSearchHistory() {
    return Column(
      children: [
        ValueListenableBuilder(
          valueListenable: Hive.box('search_history').listenable(),
          builder: (context, Box box, _) {
            if (box.isEmpty) return const SizedBox.shrink();
            final history = box.get('history') ?? [];
            return Column(
              children: history.map<Widget>((query) {
                return ListTile(leading: const Icon(Icons.history, color: Colors.grey), title: Text(query, style: const TextStyle(color: Colors.white)), onTap: () { searchController.text = query; searchVideos(query); });
              }).toList()
            );
          }
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text("Explorar Categorías", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white))),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: _categories.entries.map((e) => ActionChip(label: Text(e.key), backgroundColor: const Color(0xFF1A1A1A), onPressed: () { searchController.text = e.key; searchVideos(e.value); })).toList(),
        )
      ]
    );
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscador VIP', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), child: TextField(controller: searchController, decoration: InputDecoration(hintText: 'Buscar canciones, artistas, podcasts...', prefixIcon: const Icon(Icons.search, color: Colors.grey), suffixIcon: IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { searchController.clear(); setState(() { videos.clear(); }); }), filled: true, fillColor: const Color(0xFF1A1A1A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0), borderSide: BorderSide.none)), onSubmitted: searchVideos)),
          if (isLoading) Expanded(child: Center(child: ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => CircularProgressIndicator(color: color))))
          else if (videos.isEmpty) Expanded(child: SingleChildScrollView(child: _buildSearchHistory()))
          else Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: videos.length, itemBuilder: (context, index) {
                final video = videos[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(video.thumbnails.lowResUrl, width: 60, height: 60, fit: BoxFit.cover)),
                  title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(video.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
                  trailing: IconButton(icon: const Icon(Icons.more_vert, color: Colors.grey), onPressed: () { ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) { globalShowOptions(context, video, color); return const SizedBox.shrink(); }); }),
                  onTap: () async { final newItem = MediaItem(id: video.id.value, title: video.title, artist: video.author, duration: video.duration, artUri: Uri.parse(video.thumbnails.highResUrl)); await globalPlay(newItem); }
                );
              }
            )
          )
        ]
      )
    );
  }
}

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});
  @override Widget build(BuildContext context) {
    return DefaultTabController(length: 3, child: Scaffold(
      appBar: AppBar(title: const Text('La Bóveda', style: TextStyle(fontWeight: FontWeight.bold)), bottom: const TabBar(indicatorColor: Colors.white, tabs: [Tab(text: 'Historial'), Tab(text: 'Favoritos'), Tab(text: 'Playlists')])),
      body: TabBarView(children: [
        ValueListenableBuilder(valueListenable: Hive.box('history').listenable(), builder: (context, Box box, _) {
          if (box.isEmpty) return const Center(child: Text("Sin historial aún", style: TextStyle(color: Colors.grey)));
          final items = box.values.toList().cast<Map>()..sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0));
          return ListView.builder(padding: const EdgeInsets.only(bottom: 100), itemCount: items.length, itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(item['artUri'], width: 50, height: 50, fit: BoxFit.cover)),
              title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 20), onPressed: () => box.delete(item['id'])),
              onTap: () async { final newItem = MediaItem(id: item['id'], title: item['title'], artist: item['artist'], artUri: Uri.parse(item['artUri']), duration: Duration(milliseconds: item['duration'])); await globalPlay(newItem); }
            );
          });
        }),
        ValueListenableBuilder(valueListenable: Hive.box('favorites').listenable(), builder: (context, Box box, _) {
          if (box.isEmpty) return const Center(child: Text("Sin favoritos aún", style: TextStyle(color: Colors.grey)));
          final items = box.values.toList().cast<Map>();
          return ListView.builder(padding: const EdgeInsets.only(bottom: 100), itemCount: items.length, itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(item['artUri'], width: 50, height: 50, fit: BoxFit.cover)),
              title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: IconButton(icon: const Icon(Icons.favorite, color: Colors.redAccent), onPressed: () => box.delete(item['id'])),
              onTap: () async { 
                List<MediaItem> allFavs = items.map((e) => MediaItem(id: e['id'], title: e['title'], artist: e['artist'], artUri: Uri.parse(e['artUri']), duration: Duration(milliseconds: e['duration']))).toList();
                await globalPlayQueue(allFavs, index); 
              }
            );
          });
        }),
        ValueListenableBuilder(valueListenable: Hive.box('playlists').listenable(), builder: (context, Box box, _) {
          if (box.isEmpty) return const Center(child: Text("Toca los 3 puntitos en una canción para crear listas", style: TextStyle(color: Colors.grey)));
          final keys = box.keys.toList();
          return ListView.builder(padding: const EdgeInsets.only(bottom: 100), itemCount: keys.length, itemBuilder: (context, index) {
            final playlistName = keys[index].toString();
            final tracks = box.get(playlistName) ?? [];
            return ExpansionTile(
              leading: ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => Icon(Icons.queue_music, color: color)),
              title: Text(playlistName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              subtitle: Text("${tracks.length} pistas", style: const TextStyle(color: Colors.grey)),
              trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => box.delete(playlistName)),
              children: tracks.asMap().entries.map<Widget>((entry) {
                int trackIndex = entry.key; final item = entry.value as Map;
                return ListTile(
                  contentPadding: const EdgeInsets.only(left: 40, right: 16),
                  leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(item['artUri'], width: 40, height: 40, fit: BoxFit.cover)),
                  title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                  trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.grey, size: 20), onPressed: () { tracks.removeAt(trackIndex); box.put(playlistName, tracks); }),
                  onTap: () async { List<MediaItem> allTracks = tracks.map<MediaItem>((e) => MediaItem(id: e['id'], title: e['title'], artist: e['artist'], artUri: Uri.parse(e['artUri']), duration: Duration(milliseconds: e['duration']))).toList(); await globalPlayQueue(allTracks, trackIndex); }
                );
              }).toList(),
            );
          });
        })
      ])
    ));
  }
}

class MiniPlayer extends StatefulWidget { const MiniPlayer({super.key}); @override State<MiniPlayer> createState() => _MiniPlayerState(); }
class _MiniPlayerState extends State<MiniPlayer> {
  @override Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(stream: audioHandler.mediaItem, builder: (context, snapshot) {
      final mediaItem = snapshot.data; if (mediaItem == null) return const SizedBox.shrink();
      return GestureDetector(
        onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => const FullScreenPlayer()),
        child: ValueListenableBuilder<Color>(
          valueListenable: appColor, builder: (context, color, _) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: color, width: 0.5), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, spreadRadius: 2)], color: Colors.black.withOpacity(0.9)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(children: [ ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(mediaItem.artUri.toString(), width: 45, height: 45, fit: BoxFit.cover)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(mediaItem.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text(mediaItem.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12))])), StreamBuilder<PlaybackState>(stream: audioHandler.playbackState, builder: (context, snapshot) { final state = snapshot.data; final playing = state?.playing ?? false; final isLoading = state?.processingState == AudioProcessingState.loading || state?.processingState == AudioProcessingState.buffering; return IconButton(icon: isLoading ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: color, strokeWidth: 2)) : Icon(playing ? Icons.pause : Icons.play_arrow, color: color), onPressed: () { if (playing) { audioHandler.pause(); } else { audioHandler.play(); } }); }) ])
                  )
                )
              )
            );
          }
        )
      );
    });
  }
}

class FullScreenPlayer extends StatelessWidget {
  const FullScreenPlayer({super.key});
  @override Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.95, decoration: const BoxDecoration(color: Color(0xFF0D0D0D), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: StreamBuilder<MediaItem?>(stream: audioHandler.mediaItem, builder: (context, snapshot) {
        final mediaItem = snapshot.data; if (mediaItem == null) return const SizedBox.shrink();
        return Column(children: [
          const SizedBox(height: 10), Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))), const SizedBox(height: 30),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) { return Container(decoration: BoxDecoration(boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 40, spreadRadius: 10)]), child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(mediaItem.artUri.toString(), width: double.infinity, height: 320, fit: BoxFit.cover))); })),
          const SizedBox(height: 40),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(mediaItem.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(mediaItem.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, color: Colors.grey))])), ValueListenableBuilder(valueListenable: Hive.box('favorites').listenable(), builder: (context, Box box, _) { final isFav = box.containsKey(mediaItem.id); return IconButton(icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : Colors.white), onPressed: () { if (isFav) { box.delete(mediaItem.id); } else { box.put(mediaItem.id, {'id': mediaItem.id, 'title': mediaItem.title, 'artist': mediaItem.artist, 'artUri': mediaItem.artUri.toString(), 'duration': mediaItem.duration?.inMilliseconds ?? 0}); } }); })])),
          const SizedBox(height: 20),
          StreamBuilder<Duration>(stream: AudioService.position, builder: (context, snapshotPosition) { final pos = snapshotPosition.data ?? Duration.zero; return StreamBuilder<PlaybackState>(stream: audioHandler.playbackState, builder: (context, snapshot) { final state = snapshot.data; final isLoading = state?.processingState == AudioProcessingState.loading || state?.processingState == AudioProcessingState.buffering; final dur = mediaItem.duration ?? Duration.zero; return Column(children: [Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) { return SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight: 4, activeTrackColor: color, inactiveTrackColor: Colors.white24, thumbColor: color, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), overlayShape: const RoundSliderOverlayShape(overlayRadius: 14)), child: Slider(value: isLoading ? 0.0 : pos.inMilliseconds.toDouble().clamp(0.0, dur.inMilliseconds.toDouble() > 0 ? dur.inMilliseconds.toDouble() : 1.0), max: dur.inMilliseconds.toDouble() > 0 ? dur.inMilliseconds.toDouble() : 1.0, onChanged: (v) { if (!isLoading) audioHandler.seek(Duration(milliseconds: v.round())); })); })), Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(formatGlobalDuration(pos), style: const TextStyle(color: Colors.grey, fontSize: 12)), Text(formatGlobalDuration(mediaItem.duration), style: const TextStyle(color: Colors.grey, fontSize: 12))]))]); }); }),
          const Spacer(),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: StreamBuilder<PlaybackState>(stream: audioHandler.playbackState, builder: (context, snapshot) { final state = snapshot.data; final playing = state?.playing ?? false; final isLoading = state?.processingState == AudioProcessingState.loading || state?.processingState == AudioProcessingState.buffering; return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [ValueListenableBuilder<int>(valueListenable: sleepTimerRemaining, builder: (context, remaining, _) { return IconButton(icon: Icon(Icons.timer, color: remaining > 0 ? appColor.value : Colors.grey), onPressed: () => _showSleepTimerDialog(context)); }), IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white, size: 36), onPressed: () => audioHandler.skipToPrevious()), ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) { return Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 20, spreadRadius: 5)]), child: IconButton(icon: isLoading ? const CircularProgressIndicator(color: Colors.black) : Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 36), onPressed: () { if (playing) { audioHandler.pause(); } else { audioHandler.play(); } })); }), IconButton(icon: const Icon(Icons.skip_next, color: Colors.white, size: 36), onPressed: () => audioHandler.skipToNext()), IconButton(icon: const Icon(Icons.shuffle, color: Colors.white), onPressed: () { if (audioHandler is MyAudioHandler) { (audioHandler as MyAudioHandler).shuffleQueue(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cola mezclada'), duration: Duration(seconds: 1))); } })]); })),
          const Spacer()
        ]);
      })
    );
  }
  void _showSleepTimerDialog(BuildContext context) { showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1A1A1A), builder: (context) { return Wrap(children: [const ListTile(title: Text("Temporizador", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))), _timerOption(context, "Desactivar", 0), _timerOption(context, "15 minutos", 15), _timerOption(context, "30 minutos", 30), _timerOption(context, "60 minutos", 60)]); }); }
  Widget _timerOption(BuildContext context, String label, int minutes) { return ListTile(title: Text(label, style: const TextStyle(color: Colors.white70)), onTap: () { audioHandler.customAction('setSleepTimer', {'minutes': minutes}); Navigator.pop(context); }); }
}
