import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Funciones globales de reproducción
Future<void> globalPlay(MediaItem item, MyAudioHandler handler) async {
await handler.updateQueue([item]); 
await handler.playMediaItem(item);
}

Future<void> globalPlayQueue(List<MediaItem> items, int startIndex, MyAudioHandler handler) async {
await handler.updateQueue(items);
await handler.playMediaItem(items[startIndex]);
}

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
final _player = AudioPlayer(); 
late final YoutubeExplode _yt; 
Timer? _countdownTimer; 
bool _isTransitioning = false; 
final ValueNotifier<int> sleepTimerRemaining = ValueNotifier<int>(0);

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
          if (v.duration != null && (v.duration!.inMinutes >= 15 || v.duration!.inSeconds < 60)) continue;
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
      }
    } catch (_) {}

    if (nextVideo == null) {
      final query = "${currentItem.artist} éxitos";
      final searchResults = await _yt.search.search(query);
      final list = searchResults.where((v) => 
        v.id.value != currentItem.id && 
        v.duration != null && 
        v.duration!.inMinutes < 15 && 
        v.duration!.inSeconds >= 60
      ).toList();
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

@override Future<void> skipToQueueItem(int index) async {
  final queueList = queue.value;
  if (index >= 0 && index < queueList.length) {
    await playMediaItem(queueList[index]);
  }
}
// --- MOTOR V5: TÚNEL PROXY FORZADO (ANTI IP-MISMATCH) ---
Future<String> _getStreamUrl(String videoId) async {
  // El parámetro clave aquí es "&local=true". Esto obliga al servidor a descargar
  // el audio y retransmitirlo, evitando que Google vea tu IP real y bloquee el flujo.
  final proxies = [
    'https://inv.tux.pizza/latest_version?id=$videoId&itag=140&local=true',
    'https://invidious.jing.rocks/latest_version?id=$videoId&itag=140&local=true',
    'https://invidious.nerdvpn.de/latest_version?id=$videoId&itag=140&local=true',
    'https://inv.nadeko.net/latest_version?id=$videoId&itag=140&local=true'
  ];

  for (String url in proxies) {
    try {
      // Ping rápido de 3 segundos para no dejar la app colgada si un servidor cae
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client.headUrl(Uri.parse(url));
      final response = await request.close();
      
      // 200 (OK), 206 (Contenido parcial) o 302 (Redirección exitosa)
      if (response.statusCode == 200 || response.statusCode == 206 || response.statusCode == 302) {
        return url; 
      }
    } catch (_) {
      continue; // Si este servidor está saturado, salta al siguiente
    }
  }
  return proxies.first; // Si todo falla, forzamos el primero
}

@override
Future<void> playMediaItem(MediaItem item) async {
  mediaItem.add(item); 
  final historyBox = Hive.box('history'); 
  int playCount = 1; int savedPosition = 0; 
  
  if (historyBox.containsKey(item.id)) { 
    final existingItem = historyBox.get(item.id); 
    playCount = (existingItem['playCount'] ?? 0) + 1; 
    savedPosition = existingItem['savedPosition'] ?? 0; 
  }
  historyBox.put(item.id, {
    'id': item.id, 'title': item.title, 'artist': item.artist, 'artUri': item.artUri?.toString() ?? '', 'duration': item.duration?.inMilliseconds ?? 0, 'timestamp': DateTime.now().millisecondsSinceEpoch, 'playCount': playCount, 'savedPosition': 0
  });

  try {
    playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.loading, playing: true));
    await _player.stop(); 
    await _player.seek(Duration.zero); 
    
    // Llamamos al túnel proxy
    final streamUrl = await _getStreamUrl(item.id);
    
    // Conectamos el reproductor directamente al túnel
    final source = AudioSource.uri(Uri.parse(streamUrl), tag: item);
    
    await _player.setAudioSource(source);
    
    if (savedPosition > 0) { await _player.seek(Duration(milliseconds: savedPosition)); } 
    await _player.play();
  } catch (e) { 
    print("Playback Error: $e");
    playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.error, playing: false)); 
  }
}

  @override Future<void> updateQueue(List<MediaItem> newQueue) async { queue.add(newQueue); }
void shuffleQueue() { final currentQueue = queue.value.toList()..shuffle(); queue.add(currentQueue); }

void insertNextInQueue(MediaItem item) {
  final currentQueue = List<MediaItem>.from(queue.value);
  final currentItem = mediaItem.value;
  final currentIndex = currentQueue.indexWhere((i) => i.id == currentItem?.id);
  if (currentIndex != -1) {
    currentQueue.insert(currentIndex + 1, item);
  } else {
    currentQueue.add(item);
  }
  updateQueue(currentQueue);
}

void addToQueueEnd(MediaItem item) {
  final currentQueue = List<MediaItem>.from(queue.value);
  currentQueue.add(item);
  updateQueue(currentQueue);
}

void removeFromQueue(MediaItem item) {
  final currentQueue = List<MediaItem>.from(queue.value);
  currentQueue.removeWhere((i) => i.id == item.id);
  updateQueue(currentQueue);
}
}
