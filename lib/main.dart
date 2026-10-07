// ARCHIVO: main.dart
import 'download_service.dart';
import 'home_screen.dart';
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
import 'package:path_provider/path_provider.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';


class VIPHttpOverrides extends HttpOverrides {
  @override HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36';
  }
}


late MyAudioHandler audioHandler;
final ValueNotifier<bool> isHDMode = ValueNotifier<bool>(true);
final ValueNotifier<Color> appColor = ValueNotifier<Color>(Colors.cyanAccent); 
final ValueNotifier<int> sleepTimerRemaining = ValueNotifier<int>(0); 


Future<String?> obtenerAudioDirecto(String videoId) async {
    try {
      final yt = YoutubeExplode();
      
      // TIMEOUT INTELIGENTE: Si Youtube tarda más de 10 segundos, corta y salta
      final manifest = await yt.videos.streamsClient.getManifest(videoId).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout al cargar manifest'),
      );
      
      final streamMp4 = manifest.audioOnly.where((stream) => stream.container.name == 'mp4');
      final streamInfo = streamMp4.withHighestBitrate();
      yt.close();
      return streamInfo.url.toString();
    } catch (e) { 
      return null; 
    }
  }


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
  await Hive.openBox('favorites'); 
  await Hive.openBox('history'); 
  await Hive.openBox('search_history'); 
  await Hive.openBox('playlists'); 
  await Hive.openBox('downloads');
  final session = await AudioSession.instance; await session.configure(const AudioSessionConfiguration.music());
  await FlutterDownloader.initialize(debug: true, ignoreSsl: true);


  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(), 
    config: const AudioServiceConfig(androidNotificationChannelId: 'com.example.media_app.audio_master_v62', androidNotificationChannelName: 'Spotify Killer VIP', androidNotificationOngoing: false, androidShowNotificationBadge: true, androidStopForegroundOnPause: false, androidNotificationIcon: 'drawable/ic_notification')
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
      if (!playing && mediaItem.value != null) { _saveResumePosition(mediaItem.value!.id, _player.position.inMilliseconds); }
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


  void _onTrackFinished() { if (_isTransitioning) return; _isTransitioning = true; _handleAutoPlayRadio(); }


  Future<void> _handleAutoPlayRadio() async {
    final currentQueue = queue.value; final currentItem = mediaItem.value; 
    if (currentItem == null) { _isTransitioning = false; return; }
    final currentIndex = currentQueue.indexWhere((item) => item.id == currentItem.id);
    if (currentIndex != -1 && currentIndex < currentQueue.length - 1) { await skipToNextBase(); _isTransitioning = false; return; }


    try {
      Video? nextVideo;
      try {
        String artistQuery = currentItem.artist ?? "";
        artistQuery = artistQuery.replaceAll(RegExp(r'(?i)vevo|topic|official|music'), '').trim();
        
        if (artistQuery.isEmpty || artistQuery.length < 3) {
          artistQuery = currentItem.title.split('-').first.trim();
        }
        
        final searchResults = await _yt.search.search("$artistQuery audio");
        
        String currentTitleClean = currentItem.title.toLowerCase();
        List<String> currentTitleWords = currentTitleClean.split(' ').where((w) => w.length > 3).toList();
        
        final list = searchResults.where((v) {
          if (v.id.value == currentItem.id) return false;
          String vTitle = v.title.toLowerCase();
          if (currentTitleWords.isNotEmpty && currentTitleWords.any((word) => vTitle.contains(word))) return false;
          return true;
        }).toList();


        if (list.isNotEmpty) {
          final randomLimit = math.min(8, list.length);
          nextVideo = list[math.Random().nextInt(randomLimit)];
        } else {
          var relatedVideos = await _yt.videos.getRelatedVideos(await _yt.videos.get(currentItem.id));
          if (relatedVideos != null && relatedVideos.isNotEmpty) {
            nextVideo = relatedVideos.firstWhere((v) => v.id.value != currentItem.id, orElse: () => relatedVideos.first);
          }
        }
      } catch (_) {}


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
    if (name == 'kill') { await _player.stop(); mediaItem.add(null); queue.add([]); return; }
    if (name == 'playLocal' && extras != null) { await _player.stop(); await _player.setFilePath(extras['localPath']); _player.play(); mediaItem.add(MediaItem(id: extras['id'] ?? 'offline', title: extras['title'] ?? 'Audio Local', artist: 'Bóveda Offline')); return; }
    if (name == 'setSleepTimer' && extras != null) { 
      int minutes = extras['minutes']; _countdownTimer?.cancel(); 
      if (minutes > 0) { sleepTimerRemaining.value = minutes * 60; _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) { if (sleepTimerRemaining.value > 0) { sleepTimerRemaining.value--; } else { pause(); timer.cancel(); } }); } else { sleepTimerRemaining.value = 0; } 
    } 
  }
  @override Future<void> play() => _player.play(); 
  @override Future<void> pause() => _player.pause(); 
  @override Future<void> seek(Duration position) => _player.seek(position);
  
  @override Future<void> skipToNext() async { 
    final queueList = queue.value; final currentItem = mediaItem.value; 
    final currentIndex = queueList.indexWhere((item) => item.id == currentItem?.id); 
    if (currentIndex != -1 && currentIndex < queueList.length - 1) { await playMediaItem(queueList[currentIndex + 1]); } else { _onTrackFinished(); }
  }
Future<void> skipToNextBase() async { final queueList = queue.value; final currentItem = mediaItem.value; final currentIndex = queueList.indexWhere((item) => item.id == currentItem?.id); if (currentIndex != -1 && currentIndex < queueList.length - 1) await playMediaItem(queueList[currentIndex + 1]); }
  @override Future<void> skipToPrevious() async { final queueList = queue.value; if (queueList.isEmpty) return; final currentItem = mediaItem.value; final currentIndex = queueList.indexWhere((item) => item.id == currentItem?.id); if (currentIndex > 0) await playMediaItem(queueList[currentIndex - 1]); }
  
  @override
  Future<void> playMediaItem(MediaItem item) async {
    mediaItem.add(item); 
    final historyBox = Hive.box('history');
    int playCount = 1; 
    int savedPosition = 0;
    
    if (historyBox.containsKey(item.id)) {
      final existingItem = historyBox.get(item.id);
      playCount = (existingItem['playCount'] ?? 0) + 1;
      savedPosition = existingItem['position'] ?? 0;
    }
    
    historyBox.put(item.id, {
      'id': item.id, 'title': item.title, 'artist': item.artist, 
      'artUri': item.artUri.toString(), 'duration': item.duration?.inMilliseconds, 
      'playCount': playCount, 'position': 0, 'timestamp': DateTime.now().millisecondsSinceEpoch
    });

    try {
      playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.loading, playing: true));
      await _player.stop(); 
      await _player.seek(Duration.zero);

      // --- FILTRO ANTI-MIX: OBTENEMOS METADATOS RÁPIDO ---
      var video = await _yt.videos.get(item.id);
      
      // Si la duración es mayor a 12 minutos (720 segundos), abortamos y saltamos
      if (video.duration != null && video.duration!.inSeconds > 720) {
        print("❌ Mix masivo detectado (${video.duration!.inMinutes} mins). Saltando pista...");
        await skipToNext(); // Forzamos salto automático
        return; 
      }

      // --- TIMEOUT DE EMERGENCIA: SI YOUTUBE TARDA MÁS DE 10 SEGUNDOS, CORTAMOS ---
      var manifest = await _yt.videos.streamsClient.getManifest(item.id).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception("Timeout: YouTube no respondió a tiempo"),
      );
      
      StreamInfo streamInfo;
      if (manifest.muxed.isNotEmpty) {
        streamInfo = isHDMode.value ? manifest.muxed.withHighestBitrate() : manifest.muxed.reduce((a, b) => a.size.totalBytes < b.size.totalBytes ? a : b);
      } else if (manifest.audioOnly.isNotEmpty) {
        streamInfo = isHDMode.value ? manifest.audioOnly.withHighestBitrate() : manifest.audioOnly.reduce((a, b) => a.size.totalBytes < b.size.totalBytes ? a : b);
      } else {
        throw Exception("No streams available");
      }

      final cachingSource = LockCachingAudioSource(
        Uri.parse(streamInfo.url.toString()), 
        tag: item.copyWith(duration: video.duration ?? Duration.zero, title: video.title)
      );
      
      mediaItem.add(item.copyWith(duration: video.duration ?? Duration.zero, title: video.title));
      await _player.setAudioSource(cachingSource);
      
      if (savedPosition > 0) { 
        await _player.seek(Duration(milliseconds: savedPosition)); 
      }
      
      await _player.play();
    } catch (e) {
      // --- MANEJO DE ERROR: SI ALGO FALLA (COMO EL TIMEOUT), SALTAMOS A LA SIGUIENTE ---
      print("❌ Error cargando pista: $e");
      playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.error, playing: false));
      
      // Esperamos 2 segundos para no saturar el sistema y mandamos siguiente pista
      Timer(const Duration(seconds: 2), () {
        _isTransitioning = false;
        skipToNext(); // Salto forzado si hubo error (como en la pantalla de bloqueo)
      });
    }
  }
 
  @override Future<void> updateQueue(List<MediaItem> newQueue) async { queue.add(newQueue); }
}


Future<void> globalPlay(MediaItem item) async { await audioHandler.updateQueue([item]); await audioHandler.playMediaItem(item); }
Future<void> globalPlayQueue(List<MediaItem> items, int startIndex) async { await audioHandler.updateQueue(items); await audioHandler.playMediaItem(items[startIndex]); }


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
            ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: CachedNetworkImage(imageUrl: video.thumbnails.highResUrl, width: 50, height: 50, fit: BoxFit.cover)), title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), subtitle: Text(video.author, style: const TextStyle(color: Colors.grey))),
            const Divider(color: Colors.white24),
            ListTile(leading: const Icon(Icons.radio, color: Colors.white), title: const Text('Ir a la radio de la canción', style: TextStyle(color: Colors.white))),
            ListTile(leading: const Icon(Icons.playlist_add, color: Colors.white), title: const Text('Agregar a una playlist', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _showPlaylistDialog(context, video, color); }),
            ListTile(leading: const Icon(Icons.queue_music, color: Colors.white), title: const Text('Agregar a la cola', style: TextStyle(color: Colors.white)), onTap: () async { Navigator.pop(context); final itemToQueue = MediaItem(id: video.id.value, title: video.title, artist: video.author, duration: video.duration, artUri: Uri.parse(video.thumbnails.highResUrl)); await audioHandler.addQueueItem(itemToQueue); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Canción agregada a la cola'))); }),
            Visibility(
              visible: false,
              child: ListTile(leading: const Icon(Icons.download, color: Colors.white), title: const Text('Descargar', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); downloadAudio(context, video); }),
            ),
            ValueListenableBuilder(
              valueListenable: Hive.box('favorites').listenable(),
              builder: (context, Box box, _) {
                final isFav = box.containsKey(video.id.value);
                return ListTile(leading: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : Colors.white), title: Text(isFav ? 'Eliminar de Tus me gusta' : 'Agregar a Tus me gusta', style: const TextStyle(color: Colors.white)), onTap: () { if (isFav) { box.delete(video.id.value); } else { box.put(video.id.value, {'id': video.id.value, 'title': video.title, 'artist': video.author, 'artUri': video.thumbnails.highResUrl, 'duration': video.duration?.inMilliseconds ?? 0}); } Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isFav ? 'Eliminado de Favoritos' : 'Agregado a Favoritos'), backgroundColor: color)); });
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
  showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF1A1A1A), title: const Text("Mis Playlists", style: TextStyle(color: Colors.white)), content: Column(mainAxisSize: MainAxisSize.min, children: [ ListTile(leading: const Icon(Icons.add, color: Colors.white), title: const Text("Crear Nueva Playlist", style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _showCreatePlaylistDialog(context, songData, color); }), if (box.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text("No tienes playlists aún", style: TextStyle(color: Colors.grey))) else ...box.keys.map((key) => ListTile(leading: const Icon(Icons.queue_music, color: Colors.grey), title: Text(key.toString(), style: const TextStyle(color: Colors.white)), onTap: () { final currentList = box.get(key) ?? []; if (!currentList.any((s) => s['id'] == songData['id'])) { currentList.add(songData); box.put(key, currentList); } Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Agregado a $key"), backgroundColor: color)); })).toList() ])));
}


void _showCreatePlaylistDialog(BuildContext context, Map songData, Color color) {
  final textController = TextEditingController();
  showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: const Color(0xFF1A1A1A), title: const Text("Nueva Playlist", style: TextStyle(color: Colors.white)), content: TextField(controller: textController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Nombre de la playlist", hintStyle: TextStyle(color: Colors.grey))), actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))), TextButton(onPressed: () { if (textController.text.trim().isNotEmpty) { Hive.box('playlists').put(textController.text.trim(), [songData]); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Playlist creada"), backgroundColor: color)); } }, child: const Text("Crear", style: TextStyle(color: Colors.white))) ]));
}


class MediaApp extends StatelessWidget {
  const MediaApp({super.key});
  @override Widget build(BuildContext context) {
    final bool accesoConcedido = Hive.box('cerrojo_box').get('acceso_concedido', defaultValue: false);
    return ValueListenableBuilder<Color>(
      valueListenable: appColor, 
      builder: (context, color, _) {
        return MaterialApp(
          title: 'Spotify Killer VIP', debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0D0D0D), primaryColor: color, bottomNavigationBarTheme: BottomNavigationBarThemeData(backgroundColor: Colors.transparent, selectedItemColor: color, unselectedItemColor: Colors.grey, type: BottomNavigationBarType.fixed), appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0D0D0D), elevation: 0, centerTitle: true)),
          home: accesoConcedido ? SuperAppSkeleton() : CerrojoScreen(),
        );
      }
    );
  }
}
class SuperAppSkeleton extends StatefulWidget { const SuperAppSkeleton({super.key}); @override State<SuperAppSkeleton> createState() => _SuperAppSkeletonState(); }


class _SuperAppSkeletonState extends State<SuperAppSkeleton> {
  int _currentIndex = 0; final List<Widget> _screens = [
    const HomeScreen(), 
    const SearchScreen(), 
    const VaultScreen(), 
    const SportsScreen()
  ];
 @override Widget build(BuildContext context) { 
    return Scaffold(
      extendBody: true, 
      body: Stack(children: [ 
        IndexedStack(index: _currentIndex, children: _screens), 
        const Positioned(left: 0, right: 0, bottom: 65, child: MiniPlayer()), 
      ]), 
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0), 
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4), 
              border: const Border(top: BorderSide(color: Colors.white10, width: 1))
            ), 
            child: BottomNavigationBar(
              currentIndex: _currentIndex, 
              onTap: (index) => setState(() => _currentIndex = index), 
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Radar'), 
                BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Intercepción'), 
                BottomNavigationBarItem(icon: Icon(Icons.fingerprint), label: 'Cripta'), 
                BottomNavigationBarItem(icon: Icon(Icons.stadium), label: 'Mesa de Control')
              ]
            )
          )
        )
      )
    ); 
  }
}
