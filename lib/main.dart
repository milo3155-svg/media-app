import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math' as math;
import 'dart:async';


import 'home_screen.dart'; // Vincula con tu pantalla principal


// === DISFRAZ GLOBAL PARA EVADIR ERROR 403 ===
class VIPHttpOverrides extends HttpOverrides {
  @override HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  }
}


late MyAudioHandler audioHandler;
final ValueNotifier<bool> isHDMode = ValueNotifier<bool>(true);
final ValueNotifier<Color> appColor = ValueNotifier<Color>(const Color(0xFF4ADE80)); // Verde Neón por defecto
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
  await Hive.openBox('favorites'); 
  await Hive.openBox('history'); 
  await Hive.openBox('search_history'); 
  await Hive.openBox('playlists'); 
  await Hive.openBox('cerrojo_box'); // Bóveda de Seguridad para Tokens
  
  final session = await AudioSession.instance; 
  await session.configure(const AudioSessionConfiguration.music());
  
  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(), 
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.apex.media.vip', 
      androidNotificationChannelName: 'Apex VIP Player', 
      androidNotificationOngoing: false, 
      androidShowNotificationBadge: true, 
      androidStopForegroundOnPause: false, 
      androidNotificationIcon: 'drawable/ic_notification' 
    )
  );
  runApp(const MediaApp());
}
// ============================================================================
// === MEDIA APP: LOGICA DE BLOQUEO Y CADUCIDAD ===
// ============================================================================
class MediaApp extends StatelessWidget {
  const MediaApp({super.key});


  @override Widget build(BuildContext context) {
    final box = Hive.box('cerrojo_box');
    bool accesoConcedido = box.get('acceso_concedido', defaultValue: false);
    
    // EL RELOJ DE ARENA: Verificamos caducidad
    if (accesoConcedido) {
      final fechaActivacion = box.get('fecha_activacion', defaultValue: 0);
      final diasVigencia = box.get('dias_vigencia', defaultValue: 0);
      
      if (fechaActivacion > 0 && diasVigencia > 0) {
        final caducidad = DateTime.fromMillisecondsSinceEpoch(fechaActivacion).add(Duration(days: diasVigencia));
        if (DateTime.now().isAfter(caducidad)) {
          accesoConcedido = false;
          box.put('acceso_concedido', false);
        }
      }
    }


    return ValueListenableBuilder<Color>(
      valueListenable: appColor, 
      builder: (context, color, _) {
        return MaterialApp(
          title: 'Apex VIP', 
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF0A0A0A), 
            primaryColor: color, 
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              backgroundColor: const Color(0xFF111111), 
              selectedItemColor: color, 
              unselectedItemColor: Colors.grey, 
              type: BottomNavigationBarType.fixed, 
              elevation: 10
            ), 
            appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0A0A0A), elevation: 0, centerTitle: true)
          ),
          home: accesoConcedido ? const SuperAppSkeleton() : const CerrojoScreen(),
        );
      }
    );
  }
}
// ============================================================================
// === CERROJO SCREEN: INGRESO DE TOKEN ===
// ============================================================================
class CerrojoScreen extends StatefulWidget { const CerrojoScreen({super.key}); @override State<CerrojoScreen> createState() => _CerrojoScreenState(); }


class _CerrojoScreenState extends State<CerrojoScreen> {
  final TextEditingController _tokenController = TextEditingController(); 
  final _cerrojoBox = Hive.box('cerrojo_box'); 
  String? _errorText;


  void _validarToken() { 
    final tokenIngresado = _tokenController.text.trim(); 
    if (tokenIngresado.startsWith('APX-')) { 
      try {
        final base64String = tokenIngresado.substring(4);
        final rawData = utf8.decode(base64Decode(base64String)); 
        final partes = rawData.split('|'); // ID | Música | Bóveda | TV | Días
        
        if (partes.length == 5) {
          final tieneMusica = partes[1] == '1';
          final isPlus = partes[2] == '1'; 
          final dias = int.tryParse(partes[4]) ?? 0;


          if (!tieneMusica) { setState(() { _errorText = 'Sin permiso de Música.'; }); return; }


          final now = DateTime.now().millisecondsSinceEpoch;
          _cerrojoBox.put('acceso_concedido', true); 
          _cerrojoBox.put('token_activo', tokenIngresado); 
          _cerrojoBox.put('device_id', partes[0]); // Guardamos Alias
          _cerrojoBox.put('is_plus_user', isPlus); 
          _cerrojoBox.put('fecha_activacion', now); 
          _cerrojoBox.put('dias_vigencia', dias);
          
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SuperAppSkeleton())); 
        } else { setState(() { _errorText = 'Token corrupto.'; }); }
      } catch (e) { setState(() { _errorText = 'Firma inválida.'; }); }
    } else { setState(() { _errorText = 'Formato incorrecto.'; }); } 
  }


  @override Widget build(BuildContext context) { 
    return Scaffold(
      backgroundColor: const Color(0xFF111111), 
      body: Padding(
        padding: const EdgeInsets.all(32.0), 
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, 
          crossAxisAlignment: CrossAxisAlignment.stretch, 
          children: [ 
            ValueListenableBuilder<Color>(
              valueListenable: appColor,
              builder: (context, color, _) => Icon(Icons.account_circle, size: 80, color: color),
            ),
            const SizedBox(height: 32), 
            const Text('SESIÓN VIP', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 2.0, fontWeight: FontWeight.bold)), 
            const SizedBox(height: 16), 
            const Text('Ingresa tu llave de acceso para activar el ecosistema.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)), 
            const SizedBox(height: 48), 
            TextField(
              controller: _tokenController, 
              style: TextStyle(color: appColor.value, fontSize: 18, letterSpacing: 1.5), 
              decoration: InputDecoration(
                hintText: 'APX-...', hintStyle: const TextStyle(color: Colors.white24), 
                errorText: _errorText, 
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)), 
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: appColor.value))
              )
            ), 
            const SizedBox(height: 32), 
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: appColor.value, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), 
              onPressed: _validarToken, 
              child: const Text('VALIDAR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1))
            ),
          ]
        )
      )
    ); 
  }
}
// ============================================================================
// === MOTOR DE AUDIO (REPRODUCCIÓN EXITOSA VIEJO + DISFRAZ) ===
// ============================================================================
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
    if (name == 'kill') { await _player.stop(); mediaItem.add(null); queue.add([]); return; }
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
      StreamInfo streamInfo;
      if (manifest.muxed.isNotEmpty) { streamInfo = isHDMode.value ? manifest.muxed.withHighestBitrate() : manifest.muxed.reduce((a, b) => a.bitrate.bitsPerSecond < b.bitrate.bitsPerSecond ? a : b); } 
      else if (manifest.audioOnly.isNotEmpty) { streamInfo = isHDMode.value ? manifest.audioOnly.withHighestBitrate() : manifest.audioOnly.reduce((a, b) => a.bitrate.bitsPerSecond < b.bitrate.bitsPerSecond ? a : b); } 
      else { throw Exception("No streams"); }
      
      // INYECCIÓN DE CABECERAS VIP PARA YOUTUBE
      final audioSource = AudioSource.uri(
        Uri.parse(streamInfo.url.toString()),
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'},
        tag: item,
      );
      
      await _player.setAudioSource(audioSource);
      if (savedPosition > 0) { await _player.seek(Duration(milliseconds: savedPosition)); } 
      await _player.play();
    } catch (e) { playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.error, playing: false)); }
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
            ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(video.thumbnails.lowResUrl, width: 40, height: 40, fit: BoxFit.cover)), title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(video.author, style: const TextStyle(color: Colors.grey))), 
            const Divider(color: Colors.white24), 
            ListTile(leading: const Icon(Icons.radio, color: Colors.white), title: const Text('Ir a radio de la canción'), onTap: () async { Navigator.pop(context); final newItem = MediaItem(id: video.id.value, title: video.title, artist: video.author, duration: video.duration, artUri: Uri.parse(video.thumbnails.highResUrl)); await globalPlay(newItem); }),
            ValueListenableBuilder(
              valueListenable: Hive.box('favorites').listenable(),
              builder: (context, Box box, _) {
                final isFav = box.containsKey(video.id.value);
                return ListTile(
                  leading: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : Colors.white), 
                  title: Text(isFav ? 'Eliminar de Tus me gusta' : 'Agregar a Tus me gusta'), 
                  onTap: () { 
                    if (isFav) { box.delete(video.id.value); } else { box.put(video.id.value, {'id': video.id.value, 'title': video.title, 'artist': video.author, 'artUri': video.thumbnails.highResUrl, 'duration': video.duration?.inMilliseconds ?? 0}); }
                    Navigator.pop(context); 
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