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
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'offline_vault_screen.dart';

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
    final manifest = await yt.videos.streamsClient.getManifest(videoId);
    final streamsMp4 = manifest.audioOnly.where((stream) => stream.container.name == 'mp4');
    final streamInfo = streamsMp4.withHighestBitrate();
    yt.close();
    return streamInfo.url.toString();
  } catch (e) {
    print('Error con YoutubeExplode: $e');
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
  final session = await AudioSession.instance; 
  await session.configure(const AudioSessionConfiguration.music());
  await FlutterDownloader.initialize(debug: true, ignoreSsl: true);
  
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
  final double size; 
  final Color color; 
  const ConspiracyLogo({super.key, this.size = 150.0, required this.color});
  
  @override 
  Widget build(BuildContext context) { 
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _OsirisEyePainter(color: color))); 
  }
}

class _OsirisEyePainter extends CustomPainter {
  final Color color; 
  _OsirisEyePainter({required this.color});
  
  void _drawTextOnLine(Canvas canvas, String text, Offset start, Offset end, double fontSize) {
    final midPoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2); 
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    canvas.save(); 
    canvas.translate(midPoint.dx, midPoint.dy); 
    canvas.rotate(angle);
    final textSpan = TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'Courier'));
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr); 
    textPainter.layout(); 
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height - 2)); 
    canvas.restore();
  }
  
  @override 
  void paint(Canvas canvas, Size size) {
    final w = size.width; 
    final h = size.height;
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = w * 0.05..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round;
    final p1 = Offset(w * 0.15, h * 0.15); 
    final p2 = Offset(w * 0.15, h * 0.85); 
    final p3 = Offset(w * 0.90, h * 0.50); 
    final playPath = Path()..moveTo(p1.dx, p1.dy)..lineTo(p2.dx, p2.dy)..lineTo(p3.dx, p3.dy)..close(); 
    canvas.drawPath(playPath, paint);
    
    final fontSize = w * 0.08; 
    _drawTextOnLine(canvas, "Θ ⅃ Θ", p1, p2, fontSize); 
    _drawTextOnLine(canvas, "Δ Ξ", p2, p3, fontSize); 
    _drawTextOnLine(canvas, "Θ Ϟ Ι ℟ Ι Ϟ", p3, p1, fontSize);
    
    final eyeLeft = w * 0.28; 
    final eyeRight = w * 0.62; 
    final eyeY = h * 0.50; 
    final eyeCenterX = w * 0.45;
    final eyePath = Path()..moveTo(eyeLeft, eyeY)..quadraticBezierTo(eyeCenterX, h * 0.32, eyeRight, eyeY)..quadraticBezierTo(eyeCenterX, h * 0.68, eyeLeft, eyeY); 
    canvas.drawPath(eyePath, paint);
    
    final wavePaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = w * 0.03; 
    canvas.drawCircle(Offset(eyeCenterX, h * 0.50), w * 0.08, wavePaint); 
    canvas.drawCircle(Offset(eyeCenterX, h * 0.50), w * 0.03, wavePaint); 
    canvas.drawLine(Offset(eyeCenterX - w * 0.12, h * 0.50), Offset(eyeCenterX + w * 0.12, h * 0.50), wavePaint);
  }
  
  @override 
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
      _isTransitioning = false; 
      return;
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
            nextVideo = v; 
            break; 
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

  void _saveResumePosition(String id, int milliseconds) { 
    final historyBox = Hive.box('history'); 
    if (historyBox.containsKey(id)) { 
      final item = Map<String, dynamic>.from(historyBox.get(id)); 
      item['savedPosition'] = milliseconds; 
      historyBox.put(id, item); 
    } 
  }
  
  @override 
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async { 
    if (name == 'kill') {
      await _player.stop();
      mediaItem.add(null);
      queue.add([]);
      return;
    }
    if (name == 'playLocal' && extras != null) {
      await _player.stop();
      final fileDuration = await _player.setFilePath(extras['localPath']);
      _player.play();
      
      mediaItem.add(MediaItem(
        id: extras['id']?.toString() ?? 'offline',
        title: extras['title']?.toString() ?? 'Audio Local',
        artist: 'Bóveda Offline',
        duration: fileDuration, 
      ));
      return;
    }

    if (name == 'setSleepTimer' && extras != null) { 
      int minutes = extras['minutes']; 
      _countdownTimer?.cancel(); 
      if (minutes > 0) { 
        sleepTimerRemaining.value = minutes * 60; 
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) { 
          if (sleepTimerRemaining.value > 0) { 
            sleepTimerRemaining.value--; 
          } else { 
            pause(); 
            timer.cancel(); 
          } 
        }); 
      } else { 
        sleepTimerRemaining.value = 0; 
      } 
    } 
  }

  @override
  Future<void> playMediaItem(MediaItem item) async {
    mediaItem.add(item); 
    final historyBox = Hive.box('history'); 
    int playCount = 1; 
    int savedPosition = 0; 
    
    if (historyBox.containsKey(item.id)) { 
      final existingItem = historyBox.get(item.id); 
      playCount = (existingItem['playCount'] ?? 0) + 1; 
      savedPosition = existingItem['savedPosition'] ?? 0; 
    }
    historyBox.put(item.id, {
      'id': item.id, 
      'title': item.title, 
      'artist': item.artist, 
      'artUri': item.artUri.toString(), 
      'duration': item.duration?.inMilliseconds ?? 0, 
      'timestamp': DateTime.now().millisecondsSinceEpoch, 
      'playCount': playCount, 
      'savedPosition': 0
    });
    
    try {
      playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.loading, playing: true));
      await _player.stop(); 
      await _player.seek(Duration.zero); 
      
      var manifest = await _yt.videos.streamsClient.getManifest(item.id); 
      
      // --- SEGURO ANTI-REBOTES ---
      if (mediaItem.value?.id != item.id) {
        return;
      }
      
      var video = await _yt.videos.get(item.id); 
      StreamInfo streamInfo;
      if (manifest.muxed.isNotEmpty) { 
        streamInfo = isHDMode.value ? manifest.muxed.withHighestBitrate() : manifest.muxed.reduce((a, b) => a.bitrate.bitsPerSecond < b.bitrate.bitsPerSecond ? a : b); 
      } else if (manifest.audioOnly.isNotEmpty) { 
        streamInfo = isHDMode.value ? manifest.audioOnly.withHighestBitrate() : manifest.audioOnly.reduce((a, b) => a.bitrate.bitsPerSecond < b.bitrate.bitsPerSecond ? a : b); 
      } else { 
        throw Exception("No streams"); 
      }
      
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
      
      if (savedPosition > 0) { 
        await _player.seek(Duration(milliseconds: savedPosition)); 
      } 
      await _player.play();
    } catch (e) { 
      playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.error, playing: false)); 
    }
  }

  @override 
  Future<void> updateQueue(List<MediaItem> newQueue) async { 
    queue.add(newQueue); 
  }

  void shuffleQueue() { 
    final currentQueue = queue.value.toList()..shuffle(); 
    queue.add(currentQueue); 
  }

  @override 
  Future<void> play() => _player.play(); 

  @override 
  Future<void> pause() => _player.pause(); 

  @override 
  Future<void> seek(Duration position) => _player.seek(position);
  
  @override 
  Future<void> skipToNext() async { 
    final queueList = queue.value; 
    final currentItem = mediaItem.value; 
    final currentIndex = queueList.indexWhere((item) => item.id == currentItem?.id); 
    if (currentIndex != -1 && currentIndex < queueList.length - 1) { 
      await playMediaItem(queueList[currentIndex + 1]); 
    } else { 
      _onTrackFinished(); 
    }
  }

  Future<void> skipToNextBase() async {
    final queueList = queue.value; 
    final currentItem = mediaItem.value; 
    final currentIndex = queueList.indexWhere((item) => item.id == currentItem?.id); 
    if (currentIndex != -1 && currentIndex < queueList.length - 1) {
      await playMediaItem(queueList[currentIndex + 1]);
    }
  }

  @override 
  Future<void> skipToPrevious() async { 
    final queueList = queue.value; 
    if (queueList.isEmpty) return; 
    final currentItem = mediaItem.value; 
    final currentIndex = queueList.indexWhere((item) => item.id == currentItem?.id); 
    if (currentIndex > 0) {
      await playMediaItem(queueList[currentIndex - 1]); 
    }
  }
}

Future<void> globalPlay(MediaItem item) async {
  await audioHandler.updateQueue([item]); 
  await audioHandler.playMediaItem(item);
}

Future<void> globalPlayQueue(List<MediaItem> items, int startIndex) async {
  await audioHandler.updateQueue(items);
  await audioHandler.playMediaItem(items[startIndex]);
}