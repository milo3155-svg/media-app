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
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

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
  await Hive.openBox('cerrojo_box');
  await Hive.openBox('favorites'); await Hive.openBox('history'); await Hive.openBox('search_history'); 
  await Hive.openBox('playlists'); 
  await Hive.openBox('downloads');
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

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer(); 
  late final YoutubeExplode _yt; 
  Timer? _countdownTimer; 
  bool _isTransitioning = false; 

  MyAudioHandler() {
    _yt = YoutubeExplode();
    _player.setSkipSilenceEnabled(true);
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
          duration: video.duration ?? Duration.zero, 
          title: video.title,       
        ),
      );
      
      mediaItem.add(
        item.copyWith(
          duration: video.duration ?? Duration.zero,
          title: video.title,
        )
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
            ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(video.thumbnails.highResUrl, width: 50, height: 50, fit: BoxFit.cover)), title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), subtitle: Text(video.author, style: const TextStyle(color: Colors.grey))),
            const Divider(color: Colors.white24),
            ListTile(leading: const Icon(Icons.radio, color: Colors.white), title: const Text('Ir a la radio de la canción', style: TextStyle(color: Colors.white))),
            ListTile(leading: const Icon(Icons.playlist_add, color: Colors.white), title: const Text('Agregar a una playlist', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _showPlaylistDialog(context, video, color); }),
            ListTile(
              leading: const Icon(Icons.queue_music, color: Colors.white),
              title: const Text('Agregar a la cola', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final itemToQueue = MediaItem(id: video.id.value, title: video.title, artist: video.author, duration: video.duration, artUri: Uri.parse(video.thumbnails.highResUrl));
                await audioHandler.addQueueItem(itemToQueue);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Canción agregada a la cola')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.white),
              title: const Text('Descargar', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                downloadAudio(context, video);
              },
            ),
            ValueListenableBuilder(
              valueListenable: Hive.box('favorites').listenable(),
              builder: (context, Box box, _) {
                final isFav = box.containsKey(video.id.value);
                return ListTile(
                  leading: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : Colors.white),
                  title: Text(isFav ? 'Eliminar de Tus me gusta' : 'Agregar a Tus me gusta', style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    if (isFav) { box.delete(video.id.value); } else { box.put(video.id.value, {'id': video.id.value, 'title': video.title, 'artist': video.author, 'artUri': video.thumbnails.highResUrl, 'duration': video.duration?.inMilliseconds ?? 0}); }
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isFav ? 'Eliminado de Favoritos' : 'Agregado a Favoritos'), backgroundColor: color));
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
    builder: (context) => AlertDialog(backgroundColor: const Color(0xFF1A1A1A), title: const Text("Mis Playlists", style: TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.add, color: Colors.white), title: const Text("Crear Nueva Playlist", style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _showCreatePlaylistDialog(context, songData, color); }),
        if (box.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text("No tienes playlists aún", style: TextStyle(color: Colors.grey)))
        else ...box.keys.map((key) => ListTile(leading: const Icon(Icons.queue_music, color: Colors.grey), title: Text(key.toString(), style: const TextStyle(color: Colors.white)), onTap: () { final currentList = box.get(key) ?? []; if (!currentList.any((s) => s['id'] == songData['id'])) { currentList.add(songData); box.put(key, currentList); } Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Agregado a $key"), backgroundColor: color)); })).toList()
      ])
    )
  );
}

void _showCreatePlaylistDialog(BuildContext context, Map songData, Color color) {
  final textController = TextEditingController();
  showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF1A1A1A), title: const Text("Nueva Playlist", style: TextStyle(color: Colors.white)),
    content: TextField(controller: textController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Nombre de la playlist", hintStyle: TextStyle(color: Colors.grey))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
      TextButton(onPressed: () { if (textController.text.trim().isNotEmpty) { Hive.box('playlists').put(textController.text.trim(), [songData]); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Playlist creada"), backgroundColor: color)); } }, child: const Text("Crear", style: TextStyle(color: Colors.white)))
    ]
  ));
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});
  
  @override 
  Widget build(BuildContext context) {
    final bool accesoConcedido = Hive.box('cerrojo_box').get('acceso_concedido', defaultValue: false);

    return ValueListenableBuilder<Color>(
      valueListenable: appColor, 
      builder: (context, color, _) {
        return MaterialApp(
          title: 'Spotify Killer VIP',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF0D0D0D),
            primaryColor: color,
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              backgroundColor: Colors.transparent, 
              selectedItemColor: color, 
              unselectedItemColor: Colors.grey, 
              type: BottomNavigationBarType.fixed
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0D0D0D), 
              elevation: 0, 
              centerTitle: true
            )
          ),
          home: accesoConcedido ? SuperAppSkeleton() : CerrojoScreen(),
        );
      }
    );
  }
}

class SuperAppSkeleton extends StatefulWidget { const SuperAppSkeleton({super.key}); @override State<SuperAppSkeleton> createState() => _SuperAppSkeletonState(); }
class _SuperAppSkeletonState extends State<SuperAppSkeleton> {
  int _currentIndex = 0; final List<Widget> _screens = [const HomeScreen(), const SearchScreen(), const OfflineVaultScreen(), const VaultScreen(), const SportsScreen()];
  @override Widget build(BuildContext context) { 
    return Scaffold(
      extendBody: true, 
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _screens),
          const Positioned(left: 0, right: 0, bottom: 65, child: MiniPlayer()), 
        ],
      ), 
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: Container(
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), border: const Border(top: BorderSide(color: Colors.white10, width: 1))),
            child: BottomNavigationBar(currentIndex: _currentIndex, onTap: (index) => setState(() => _currentIndex = index), items: const [BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Inicio'), BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'), BottomNavigationBarItem(icon: Icon(Icons.fingerprint), label: 'Bóveda'), BottomNavigationBarItem(icon: Icon(Icons.stadium), label: 'VIP')]),
          ),
        ),
      )
    ); 
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  Widget _buildHorizontalList(List<Map> items) { return SizedBox(height: 180, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: items.length, itemBuilder: (context, index) { final item = items[index]; return GestureDetector(onTap: () async { final mediaItem = MediaItem(id: item['id'], title: item['title'], artist: item['artist'], artUri: Uri.parse(item['artUri']), duration: Duration(milliseconds: item['duration'])); await globalPlay(mediaItem); }, child: Container(width: 120, margin: const EdgeInsets.only(right: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(item['artUri'], width: 120, height: 120, fit: BoxFit.cover)), const SizedBox(height: 8), Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)), Text(item['artist'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 11))]))); })); }
  @override Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => ConspiracyLogo(size: 60, color: color)), IconButton(icon: const Icon(Icons.settings, color: Colors.grey, size: 28), onPressed: () { showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1A1A1A), builder: (context) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Ajustes VIP", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 20), const Text("Color del Neón", style: TextStyle(color: Colors.grey)), const SizedBox(height: 10), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Colors.cyanAccent, Colors.purpleAccent, Colors.greenAccent, Colors.amberAccent, Colors.blueAccent, Colors.white].map((c) => GestureDetector(onTap: () { appColor.value = c; Navigator.pop(context); }, child: Container(width: 40, height: 40, decoration: BoxDecoration(color: c, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c, blurRadius: 10)], border: Border.all(color: Colors.white24, width: 2))))).toList()), const SizedBox(height: 20), const Divider(color: Colors.white24), const SizedBox(height: 10), ListTile(leading: const Icon(Icons.delete_forever, color: Colors.redAccent), title: const Text("Botón Nuclear (Borrar Todo)", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)), subtitle: const Text("Resetea todo el algoritmo y bóveda", style: TextStyle(color: Colors.grey, fontSize: 12)), onTap: () { Hive.box('history').clear(); Hive.box('favorites').clear(); Hive.box('search_history').clear(); Hive.box('playlists').clear(); audioHandler.updateQueue([]); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Memoria de la app borrada. Renacimiento VIP.'), backgroundColor: Colors.redAccent)); })]))); })])), ValueListenableBuilder(valueListenable: Hive.box('history').listenable(), builder: (context, Box box, _) { if (box.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text("Comienza a escuchar música para activar el radar.", style: TextStyle(color: Colors.grey))); final allItems = box.values.toList().cast<Map>(); final recentItems = List<Map>.from(allItems)..sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0)); final topItems = List<Map>.from(allItems)..sort((a, b) => (b['playCount'] as int? ?? 0).compareTo(a['playCount'] as int? ?? 0)); return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text("Escuchado Recientemente", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))), _buildHorizontalList(recentItems), const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text("Tu Frecuencia Máxima (Top 25)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))), _buildHorizontalList(topItems.take(25).toList()), const SizedBox(height: 100)]); })]))));
  }
}

class SearchScreen extends StatefulWidget { const SearchScreen({super.key}); @override State<SearchScreen> createState() => _SearchScreenState(); }
class _SearchScreenState extends State<SearchScreen> {
  final searchController = TextEditingController(); late final YoutubeExplode yt; 
  List<Video> videos = []; List<String> searchSuggestions = []; bool isLoading = false;
  Timer? _debounce; 
  
  final Map<String, String> _categories = { 'Tendencias': 'Tendencias música en español', 'Podcasts': 'Podcasts en español', 'Música': 'Música éxitos', 'Mixes': 'Mixes de música', 'Rock': 'Rock en español', 'Live': 'Música en vivo' };

  @override void initState() { super.initState(); yt = YoutubeExplode(); Permission.notification.request(); }
  @override void dispose() { _debounce?.cancel(); searchController.dispose(); super.dispose(); }

  void _saveSearchHistory(String query) { if (query.trim().isEmpty) return; final box = Hive.box('search_history'); List<String> searches = box.values.cast<String>().toList(); searches.remove(query); searches.insert(0, query); if (searches.length > 15) searches = searches.sublist(0, 15); box.clear(); box.addAll(searches); }
  void searchVideos(String query) async {
    if (query.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    _saveSearchHistory(query);
    
    setState(() {
      isLoading = true;
      videos.clear();
    });

    try {
      final results = await yt.search.search(query);
      setState(() {
        videos = results.toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      // EL DETECTOR DE ERRORES:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión con YouTube: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Widget _buildSearchHistory() {
    return ListView(
      children: [
        ValueListenableBuilder(
          valueListenable: Hive.box('search_history').listenable(),
          builder: (context, Box box, _) {
            if (box.isEmpty) return const SizedBox.shrink();
            final history = box.values.cast<String>().toList();
            return Column(
              children: history.map((query) {
                int index = history.indexOf(query);
                return ListTile(leading: const Icon(Icons.history, color: Colors.grey), title: Text(query, style: const TextStyle(color: Colors.white)), onTap: () { searchController.text = query; searchVideos(query); }, trailing: Row(mainAxisSize: MainAxisSize.min, children: [ IconButton(icon: const Icon(Icons.north_west, color: Colors.grey, size: 20), onPressed: () { searchController.text = query; searchController.selection = TextSelection.fromPosition(TextPosition(offset: searchController.text.length)); }), IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 20), onPressed: () { final newHistory = List<String>.from(history)..removeAt(index); box.clear(); box.addAll(newHistory); }), ]));
              }).toList(),
            );
          }
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text("Escuchado Recientemente", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16))),
        ValueListenableBuilder(
          valueListenable: Hive.box('history').listenable(),
          builder: (context, Box box, _) {
            if (box.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text("Aún no hay canciones en tu registro.", style: TextStyle(color: Colors.grey)));
            final items = box.values.toList().cast<Map>()..sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0));
            return Column(
              children: items.take(15).map((item) {
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(item['artUri'], width: 50, height: 50, fit: BoxFit.cover)),
                  title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(item['artist'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  trailing: IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 20), onPressed: () => box.delete(item['id'])),
                  onTap: () async { final mediaItem = MediaItem(id: item['id'], title: item['title'], artist: item['artist'], artUri: Uri.parse(item['artUri']), duration: Duration(milliseconds: item['duration'])); await globalPlay(mediaItem); }
                );
              }).toList(),
            );
          }
        ),
        const SizedBox(height: 100),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscador VIP', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), child: Row(children: [ Expanded(child: TextField(controller: searchController, decoration: InputDecoration(hintText: 'Buscar...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), onSubmitted: (val) { if (val.trim().isNotEmpty) { _saveSearchHistory(val); searchVideos(val); } })) ])),
          if (isLoading) const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (searchSuggestions.isNotEmpty && videos.isEmpty) Expanded(child: ListView.builder(itemCount: searchSuggestions.length, itemBuilder: (context, index) => ListTile(title: Text(searchSuggestions[index]), onTap: () { searchController.text = searchSuggestions[index]; searchVideos(searchSuggestions[index]); })))
          else if (videos.isEmpty && searchController.text.isEmpty) Expanded(child: _buildSearchHistory())
          else Expanded(
            child: StreamBuilder<MediaItem?>(
              stream: audioHandler.mediaItem,
              builder: (context, snapshot) {
                final currentId = snapshot.data?.id;
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    final isPlaying = currentId == video.id.value;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Stack(
                        children: [
                          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(video.thumbnails.mediumResUrl, width: 80, height: 50, fit: BoxFit.cover)),
                          Positioned(bottom: 2, right: 2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)), child: Text(formatGlobalDuration(video.duration), style: const TextStyle(color: Colors.white, fontSize: 10))))
                        ]
                      ),
                      title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(video.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isPlaying) ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => Icon(Icons.equalizer, color: color, size: 24)),
                          ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => IconButton(icon: const Icon(Icons.more_vert, color: Colors.grey), onPressed: () => globalShowOptions(context, video, color)))
                        ]
                      ),
                      onTap: () async {
                        final queueItems = videos.map((vid) => MediaItem(id: vid.id.value, title: vid.title, artist: vid.author, duration: vid.duration, artUri: Uri.parse(vid.thumbnails.highResUrl))).toList();
                        await globalPlayQueue(queueItems, index);
                      }
                    );
                  }
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
      appBar: AppBar(title: const Text('La Bóveda', style: TextStyle(fontWeight: FontWeight.bold)), bottom: TabBar(indicatorColor: appColor.value, tabs: const [Tab(icon: Icon(Icons.history), text: "Historial"), Tab(icon: Icon(Icons.favorite), text: "Favoritos"), Tab(icon: Icon(Icons.queue_music), text: "Playlists")])), 
      body: TabBarView(children: [
        ValueListenableBuilder(valueListenable: Hive.box('history').listenable(), builder: (context, Box box, _) { 
          if (box.isEmpty) return const Center(child: Text("Sin historial aún", style: TextStyle(color: Colors.grey))); 
          final items = box.values.toList().cast<Map>()..sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int)); 
          return ListView.builder(padding: const EdgeInsets.only(bottom: 100), itemCount: items.length, itemBuilder: (context, index) { 
            final item = items[index]; 
            return ListTile(
              leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(item['artUri'], width: 50, height: 50, fit: BoxFit.cover)), 
              title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(item['artist'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)), 
              trailing: IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 20), onPressed: () => box.delete(item['id'])), 
              onTap: () async { final mediaItem = MediaItem(id: item['id'], title: item['title'], artist: item['artist'], artUri: Uri.parse(item['artUri']), duration: Duration(milliseconds: item['duration'])); await globalPlay(mediaItem); }
            ); 
          }); 
        }), 
        ValueListenableBuilder(valueListenable: Hive.box('favorites').listenable(), builder: (context, Box box, _) { 
          if (box.isEmpty) return const Center(child: Text("Sin favoritos aún", style: TextStyle(color: Colors.grey))); 
          final items = box.values.toList().cast<Map>(); 
          return ListView.builder(padding: const EdgeInsets.only(bottom: 100), itemCount: items.length, itemBuilder: (context, index) { 
            final item = items[index]; 
            return ListTile(
              leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(item['artUri'], width: 50, height: 50, fit: BoxFit.cover)), 
              title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(item['artist'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)), 
              trailing: IconButton(icon: const Icon(Icons.favorite, color: Colors.redAccent), onPressed: () => box.delete(item['id'])), 
              onTap: () async { 
                List<MediaItem> allFavs = items.map((e) => MediaItem(id: e['id'], title: e['title'], artist: e['artist'], artUri: Uri.parse(e['artUri']), duration: Duration(milliseconds: e['duration']))).toList();
                await globalPlayQueue(allFavs, index); 
              }
            ); 
          }); 
        }),
        ValueListenableBuilder(valueListenable: Hive.box('playlists').listenable(), builder: (context, Box box, _) { 
          if (box.isEmpty) return const Center(child: Text("Toca los 3 puntitos en una canción para armar listas", style: TextStyle(color: Colors.grey))); 
          final keys = box.keys.toList(); 
          return ListView.builder(padding: const EdgeInsets.only(bottom: 100), itemCount: keys.length, itemBuilder: (context, index) { 
            final playlistName = keys[index].toString();
            final List tracks = box.get(playlistName) ?? [];
            return ExpansionTile(
              leading: ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => Icon(Icons.album, color: color)),
              title: Row(
                children: [
                  Expanded(child: Text(playlistName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  ValueListenableBuilder<Color>(valueListenable: appColor, builder: (context, color, _) => IconButton(icon: Icon(Icons.play_circle_fill, color: color, size: 28), onPressed: () async {
                    if (tracks.isEmpty) return;
                    List<MediaItem> allTracks = tracks.map((e) => MediaItem(id: e['id'], title: e['title'], artist: e['artist'], artUri: Uri.parse(e['artUri']), duration: Duration(milliseconds: e['duration']))).toList();
                    await globalPlayQueue(allTracks, 0);
                  }))
                ],
              ),
              subtitle: Text("${tracks.length} pistas", style: const TextStyle(color: Colors.grey)),
              trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => box.delete(playlistName)),
              children: tracks.asMap().entries.map((entry) {
                int trackIndex = entry.key;
                final item = entry.value as Map;
                return ListTile(
                  contentPadding: const EdgeInsets.only(left: 40, right: 16),
                  leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(item['artUri'], width: 40, height: 40, fit: BoxFit.cover)),
                  title: Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)), subtitle: Text(item['artist'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.grey, size: 20), onPressed: () { tracks.removeWhere((s) => s['id'] == item['id']); box.put(playlistName, tracks); }),
                  onTap: () async { 
                    List<MediaItem> allTracks = tracks.map((e) => MediaItem(id: e['id'], title: e['title'], artist: e['artist'], artUri: Uri.parse(e['artUri']), duration: Duration(milliseconds: e['duration']))).toList();
                    await globalPlayQueue(allTracks, trackIndex); 
                  }
                );
              }).toList(),
            ); 
          }); 
        })
      ]
    ))); 
  } 
}

class SportsScreen extends StatelessWidget { const SportsScreen({super.key}); @override Widget build(BuildContext context) => Scaffold(backgroundColor: const Color(0xFF0A1910), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.sports_soccer, size: 80, color: Colors.greenAccent), const SizedBox(height: 20), const Text('Tablero VIP Deportivo', style: TextStyle(color: Colors.white, fontSize: 18))]))); }

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) return const SizedBox.shrink();
        
        return Dismissible(
          key: const Key('miniplayer_dismiss'),
          direction: DismissDirection.down,
          onDismissed: (_) => audioHandler.customAction('kill'),
          child: GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const FullScreenPlayer(),
            ),
            child: ValueListenableBuilder<Color>(
              valueListenable: appColor,
              builder: (context, color, _) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color, width: 1.5),
                    boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 12, spreadRadius: 3)]
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10), 
                              child: Image.network(mediaItem.artUri.toString(), width: 45, height: 45, fit: BoxFit.cover)
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(mediaItem.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(mediaItem.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ]
                              )
                            ),
                            StreamBuilder<PlaybackState>(
                              stream: audioHandler.playbackState,
                              builder: (context, snapshot) {
                                final playing = snapshot.data?.playing ?? false;
                                return IconButton(
                                  icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 32),
                                  onPressed: () => playing ? audioHandler.pause() : audioHandler.play()
                                );
                              }
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 32),
                              onPressed: () => audioHandler.skipToNext()
                            ),
                          ]
                        )
                      )
                    )
                  )
                );
              }
            )
          )
        );
      }
    );
  }
}

class FullScreenPlayer extends StatelessWidget {
  const FullScreenPlayer({super.key});

  void _showSleepTimerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Temporizador', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [15, 30, 45, 60].map((mins) => ListTile(
            title: Text('$mins minutos', style: const TextStyle(color: Colors.white)),
            onTap: () {
              audioHandler.customAction('setSleepTimer', {'minutes': mins});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Temporizador: $mins min')));
            }
          )).toList()
        ),
        actions: [
          TextButton(
            onPressed: () {
              audioHandler.customAction('cancelSleepTimer');
              Navigator.pop(context);
            },
            child: const Text('Cancelar Temporizador', style: TextStyle(color: Colors.redAccent))
          )
        ]
      )
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: StreamBuilder<MediaItem?>(
          stream: audioHandler.mediaItem,
          builder: (context, snapshot) {
            final mediaItem = snapshot.data;
            if (mediaItem == null) return const SizedBox.shrink();

            return Column(
              children: [
                // BARRA SUPERIOR (Empujón de 60.0 para esquivar el notch del celular)
                Padding(
                  padding: const EdgeInsets.only(top: 60.0, left: 12.0, right: 12.0, bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 36), onPressed: () => Navigator.pop(context)),
                      Row(
                        children: [
                          IconButton(icon: const Icon(Icons.download, color: Colors.white, size: 28), onPressed: () => downloadAudio(context, mediaItem)),
                          IconButton(icon: const Icon(Icons.timer_outlined, color: Colors.white, size: 28), onPressed: () => _showSleepTimerDialog(context)),
                          ValueListenableBuilder(
                            valueListenable: Hive.box('favorites').listenable(),
                            builder: (context, Box box, _) {
                              final isFav = box.containsKey(mediaItem.id);
                              return IconButton(
                                icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : Colors.white, size: 28),
                                onPressed: () {
                                  if (isFav) { box.delete(mediaItem.id); } 
                                  else { box.put(mediaItem.id, {'id': mediaItem.id, 'title': mediaItem.title, 'artist': mediaItem.artist, 'artUri': mediaItem.artUri?.toString(), 'duration': mediaItem.duration?.inMilliseconds ?? 0}); }
                                }
                              );
                            }
                          ),
                          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white, size: 28), onPressed: () {}),
                        ]
                      )
                    ]
                  )
                ),
                
                // ARTE DE PORTADA EXTENDIDO
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    width: double.infinity,
                    child: Image.network(mediaItem.artUri.toString(), fit: BoxFit.cover),
                  )
                ),
                
                // CONTROLES E INFORMACIÓN
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Text(mediaItem.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(mediaItem.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                        const SizedBox(height: 30),
                        
                        // BARRA DE PROGRESO
                        StreamBuilder<Duration>(
                          stream: AudioService.position,
                          builder: (context, snapshotDuration) {
                            final position = snapshotDuration.data ?? Duration.zero;
                            final duration = mediaItem.duration ?? Duration.zero;
                            return Row(
                              children: [
                                Text(_formatDuration(position), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderThemeData(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
                                    child: ValueListenableBuilder<Color>(
                                      valueListenable: appColor,
                                      builder: (context, color, _) {
                                        return Slider(
                                          activeColor: color,
                                          inactiveColor: Colors.white24,
                                          value: position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()),
                                          max: duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0,
                                          onChanged: (val) => audioHandler.seek(Duration(milliseconds: val.toInt()))
                                        );
                                      }
                                    )
                                  )
                                ),
                                Text(_formatDuration(duration), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            );
                          }
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // BOTONES DE REPRODUCCIÓN
                        StreamBuilder<PlaybackState>(
                          stream: audioHandler.playbackState,
                          builder: (context, snapshot) {
                            final playing = snapshot.data?.playing ?? false;
                            final isBuffering = snapshot.data?.processingState == AudioProcessingState.buffering || snapshot.data?.processingState == AudioProcessingState.loading;
                            final currentPosition = snapshot.data?.position ?? Duration.zero;
                            
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(icon: const Icon(Icons.fast_rewind, color: Colors.white, size: 28), onPressed: () => audioHandler.seek(currentPosition - const Duration(seconds: 10))),
                                IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white, size: 36), onPressed: () => audioHandler.skipToPrevious()),
                                
                                isBuffering 
                                  ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(color: Colors.white))
                                  : IconButton(
                                      icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 54),
                                      onPressed: () => playing ? audioHandler.pause() : audioHandler.play()
                                    ),
                                    
                                IconButton(icon: const Icon(Icons.skip_next, color: Colors.white, size: 36), onPressed: () => audioHandler.skipToNext()),
                                IconButton(icon: const Icon(Icons.fast_forward, color: Colors.white, size: 28), onPressed: () => audioHandler.seek(currentPosition + const Duration(seconds: 10))),
                              ]
                            );
                          }
                        ),
                      ],
                    )
                  )
                ),
                
                // PANEL INFERIOR "REPRODUCIENDO AHORA" CON IMÁGENES ACTIVAS
                StreamBuilder<List<MediaItem>>(
                  stream: audioHandler.queue,
                  builder: (context, queueSnapshot) {
                    final queue = queueSnapshot.data ?? [];
                    final index = queue.indexWhere((item) => item.id == mediaItem.id);
                    final displayIndex = index >= 0 ? index + 1 : 0;
                    
                    return GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: const Color(0xFF1A1A1A),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                          builder: (context) => Column(
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text("Cola de Reproducción", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: queue.length,
                                  itemBuilder: (context, i) {
                                    final qItem = queue[i];
                                    final isCurrent = qItem.id == mediaItem.id;
                                    return ListTile(
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(4.0),
                                        child: qItem.artUri != null
                                            ? Image.network(qItem.artUri.toString(), width: 48, height: 48, fit: BoxFit.cover)
                                            : Container(width: 48, height: 48, color: Colors.grey[900], child: const Icon(Icons.music_note, color: Colors.grey)),
                                      ),
                                      title: Text(qItem.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isCurrent ? Colors.blueAccent : Colors.white)),
                                      subtitle: Text(qItem.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
                                      trailing: isCurrent ? const Icon(Icons.bar_chart, color: Colors.blueAccent) : null,
                                      onTap: () {
                                        audioHandler.skipToQueueItem(i);
                                        Navigator.pop(context);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        color: Colors.transparent,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ValueListenableBuilder<Color>(
                                  valueListenable: appColor,
                                  builder: (context, color, _) => Icon(Icons.keyboard_arrow_up, color: color, size: 20),
                                ),
                                const Text("Reproduciendo ahora", style: TextStyle(color: Colors.white, fontSize: 14)),
                                Text("$displayIndex / ${queue.length}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ]
                            ),
                            IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
                          ]
                        )
                      )
                    );
                  }
                )
              ]
            );
          }
        )
      )
    );
  }
}

class CerrojoScreen extends StatefulWidget {
  const CerrojoScreen({super.key});
  @override
  State<CerrojoScreen> createState() => _CerrojoScreenState();
}

class _CerrojoScreenState extends State<CerrojoScreen> {
  final TextEditingController _tokenController = TextEditingController();
  final _cerrojoBox = Hive.box('cerrojo_box');
  bool _error = false;

  void _validarToken() {
    final tokenIngresado = _tokenController.text.trim();
    if (tokenIngresado.startsWith('TKN')) {
      _cerrojoBox.put('acceso_concedido', true);
      _cerrojoBox.put('token_activo', tokenIngresado);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SuperAppSkeleton()),
      );
    } else {
      setState(() { _error = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Color(0xFF4ADE80)),
            const SizedBox(height: 32),
            const Text('Acceso Restringido', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 2.0)),
            const SizedBox(height: 16),
            const Text('Ingresa tu token de seguridad para continuar.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 48),
            TextField(
              controller: _tokenController,
              style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 18, letterSpacing: 1.5),
              decoration: InputDecoration(
                hintText: 'Pega tu TKN aquí...',
                hintStyle: const TextStyle(color: Colors.white24),
                errorText: _error ? 'Token inválido o sin permisos' : null,
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4ADE80)))
              )
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ADE80),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ),
              onPressed: _validarToken,
              child: const Text('VALIDAR ACCESO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16))
            )
          ]
        )
      )
    );
  }
}

Future<void> downloadAudio(BuildContext context, dynamic item) async {
  final messenger = ScaffoldMessenger.of(context);
  YoutubeExplode? yt;

  try {
    final isMediaItem = item is MediaItem;
    final String videoId = isMediaItem ? item.id : item.id.value;
    final String videoTitle = item.title;
    
    String artist = 'Desconocido';
    String artUri = '';
    int duration = 0;

    if (isMediaItem) {
      artist = item.artist ?? 'Desconocido';
      artUri = item.artUri?.toString() ?? '';
      duration = item.duration?.inMilliseconds ?? 0;
    } else {
      try { artist = item.author; } catch(_) {}
      try { artUri = item.thumbnails.highResUrl; } catch(_) {}
      try { duration = item.duration?.inMilliseconds ?? 0; } catch(_) {}
    }

    final directory = await getApplicationDocumentsDirectory();
    final savePath = '${directory.path}/$videoId.m4a';
    final file = File(savePath);

    // BLINDAJE 1: Prevención de duplicados (Resuelve tu sospecha)
    if (file.existsSync()) {
      final box = await Hive.openBox('downloads');
      await box.put(videoId, {
        'id': videoId,
        'title': videoTitle,
        'artist': artist,
        'artUri': artUri,
        'duration': duration,
        'localPath': savePath,
      });
      messenger.showSnackBar(const SnackBar(
        content: Text('✅ Este audio ya está guardado en tu Bóveda.'),
        backgroundColor: Colors.blue,
      ));
      return; // Aborta la descarga para no trabar el teléfono
    }

    messenger.showSnackBar(SnackBar(content: Text('Conectando: $videoTitle...')));

    yt = YoutubeExplode();
    var manifest = await yt.videos.streamsClient.getManifest(videoId);
    var streamInfo = manifest.audioOnly.withHighestBitrate();

    final stream = yt.videos.streamsClient.get(streamInfo);
    final fileStream = file.openWrite();

    // BLINDAJE 2: Motor manual con reporte de progreso
    int totalBytes = streamInfo.size.totalBytes;
    int receivedBytes = 0;
    int lastPercentage = 0;

    await for (final chunk in stream) {
      receivedBytes += chunk.length;
      fileStream.add(chunk);

      int percentage = ((receivedBytes / totalBytes) * 100).round();
      if (percentage != lastPercentage && percentage % 25 == 0) {
        lastPercentage = percentage;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(
          content: Text('Descargando: $percentage%'),
          duration: const Duration(milliseconds: 1500),
        ));
      }
    }

    await fileStream.flush();
    await fileStream.close();

    // BLINDAJE 3: Apertura forzada de base de datos
    final downloadsBox = await Hive.openBox('downloads');
    await downloadsBox.put(videoId, {
      'id': videoId,
      'title': videoTitle,
      'artist': artist,
      'artUri': artUri,
      'duration': duration,
      'localPath': savePath,
    });

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('✅ ¡Descarga Offline completada!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );

  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Error crítico: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  } finally {
    yt?.close(); // Asegura que la conexión de red se libere siempre
  }
}

class OfflineVaultScreen extends StatelessWidget {
  const OfflineVaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Bóveda Offline', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A1A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box('downloads').listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return const Center(
              child: Text(
                'Tu bóveda está vacía.\n¡Descarga música para escucharla sin conexión!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: box.length,
            itemBuilder: (context, index) {
              final key = box.keyAt(index);
              final item = box.get(key);

              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4.0),
                  child: item['artUri'] != null && item['artUri'].toString().isNotEmpty
                      ? Image.network(item['artUri'].toString(), width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 48, height: 48, color: Colors.grey[900], child: const Icon(Icons.music_note, color: Colors.grey)))
                      : Container(width: 48, height: 48, color: Colors.grey[900], child: const Icon(Icons.music_note, color: Colors.grey)),
                ),
                title: Text(item['title'] ?? 'Desconocido', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                subtitle: Text(item['artist'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_arrow, color: Colors.blueAccent),
                      onPressed: () {
                         // Aquí agregaremos la lógica para reproducir el archivo local más adelante
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reproduciendo ${item['title']} desde almacenamiento local...')));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () {
                        // Eliminar el archivo físico (opcional por ahora, solo borramos el registro)
                        try{
                           final file = File(item['localPath']);
                           if(file.existsSync()){
                               file.deleteSync();
                           }
                        }catch(e){
                           print("Error borrando archivo local: $e");
                        }
                        box.delete(key);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}