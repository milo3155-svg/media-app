import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ));
    });
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _onTrackFinished();
      }
    });
    _player.positionStream.listen((pos) {
      final dur = _player.duration;
      if (dur != null && dur.inSeconds > 10) {
        if (dur.inMilliseconds - pos.inMilliseconds <= 800 && !_isTransitioning) {
          _onTrackFinished();
        }
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
    if (currentItem == null) {
      _isTransitioning = false;
      return;
    }

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
            nextVideo = v;
            break;
          }
        }
      } catch (_) {}

      if (nextVideo == null) {
        final query = "${currentItem.artist} éxitos";
        final searchResults = await _yt.search.search(query);
        final list = searchResults
            .where((v) =>
                v.id.value != currentItem.id &&
                v.duration != null &&
                v.duration!.inMinutes < 15 &&
                v.duration!.inSeconds >= 60)
            .toList();
        if (list.isNotEmpty) nextVideo = list.first;
      }

      if (nextVideo != null) {
        final newItem = MediaItem(
          id: nextVideo.id.value,
          title: nextVideo.title,
          artist: nextVideo.author,
          duration: nextVideo.duration,
          artUri: Uri.parse(nextVideo.thumbnails.highResUrl),
        );
        final newQueue = List<MediaItem>.from(currentQueue)..add(newItem);
        await updateQueue(newQueue);
        await playMediaItem(newItem);
      }
    } catch (e) {
    } finally {
      _isTransitioning = false;
    }
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
    if (currentIndex > 0) await playMediaItem(queueList[currentIndex - 1]);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    final queueList = queue.value;
    if (index >= 0 && index < queueList.length) {
      await playMediaItem(queueList[index]);
    }
  }

  // --- OPCIÓN B: DESCARGA HÍBRIDA VALIDADA ---
  Future<bool> _downloadAndValidate(String url, File file) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    IOSink? sink;
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      final response = await request.close().timeout(const Duration(seconds: 12));
      final mime = response.headers.contentType?.mimeType ?? '';

      if ((response.statusCode != 200 && response.statusCode != 206) || mime.contains('text/html')) {
        return false;
      }

      sink = file.openWrite();
      await for (final chunk in response) {
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (await file.exists() && await file.length() > 100 * 1024) {
        return true;
      }
      if (await file.exists()) await file.delete();
      return false;
    } catch (_) {
      if (sink != null) {
        try { await sink.close(); } catch (_) {}
      }
      if (await file.exists()) {
        try { await file.delete(); } catch (_) {}
      }
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _getLocalAudioPath(String videoId) async {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/$videoId.m4a');

    if (await file.exists() && await file.length() > 100 * 1024) {
      return file.path;
    }
    if (await file.exists()) {
      await file.delete();
    }

    // 1. Intento vía red Piped con validación estricta de archivo descargado
    final pipedNodes = [
      'https://pipedapi.kavin.rocks',
      'https://pipedapi.adminforge.de',
      'https://api.piped.private.coffee',
      'https://pipedapi.smnz.de',
    ];

    for (final node in pipedNodes) {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      try {
        final req = await client.getUrl(Uri.parse('$node/streams/$videoId'));
        final res = await req.close().timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final body = await res.transform(utf8.decoder).join();
          final data = jsonDecode(body);
          final streams = data['audioStreams'];
          if (streams is List && streams.isNotEmpty) {
            final mp4Stream = streams.firstWhere(
              (s) => (s['mimeType']?.toString() ?? '').contains('mp4') && s['url'] != null,
              orElse: () => streams.first,
            );
            final audioUrl = mp4Stream['url']?.toString();
            if (audioUrl != null && audioUrl.isNotEmpty) {
              if (await _downloadAndValidate(audioUrl, file)) {
                return file.path;
              }
            }
          }
        }
      } catch (_) {
      } finally {
        client.close(force: true);
      }
    }

    // 2. Respaldo: descarga por bloques con el cliente interno de YoutubeExplode
    final yt = YoutubeExplode();
    IOSink? sink;
    try {
      final manifest = await yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.tv, YoutubeApiClient.ios],
      );
      final audioInfo = manifest.audioOnly.withHighestBitrate();
      final byteStream = yt.videos.streamsClient.get(audioInfo);
      sink = file.openWrite();
      await for (final chunk in byteStream) {
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (await file.exists() && await file.length() > 100 * 1024) {
        return file.path;
      }
      if (await file.exists()) await file.delete();
      throw Exception('Archivo descargado inválido (<100KB)');
    } catch (e) {
      if (sink != null) {
        try { await sink.close(); } catch (_) {}
      }
      if (await file.exists()) {
        try { await file.delete(); } catch (_) {}
      }
      throw Exception('Piped y YT fallaron: $e');
    } finally {
      yt.close();
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
      'artUri': item.artUri?.toString() ?? '',
      'duration': item.duration?.inMilliseconds ?? 0,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'playCount': playCount,
      'savedPosition': 0,
    });

    try {
      playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.loading, playing: true));
      await _player.stop();
      await _player.seek(Duration.zero);

      final localPath = await _getLocalAudioPath(item.id);
      final source = AudioSource.uri(Uri.file(localPath), tag: item);

      await _player.setAudioSource(source);

      if (savedPosition > 0) {
        await _player.seek(Duration(milliseconds: savedPosition));
      }
      await _player.play();
    } catch (e) {
      print("Playback Error: $e");
      mediaItem.add(item.copyWith(artist: "ERR: $e"));
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
