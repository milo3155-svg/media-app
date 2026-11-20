import 'dart:async';
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
  bool _isExtracting = false;
  final ValueNotifier<int> sleepTimerRemaining = ValueNotifier<int>(0);

  MyAudioHandler() {
    _yt = YoutubeExplode();
    _player.playbackEventStream.listen((PlaybackEvent event) {
      if (_isExtracting) return;
      final completed = _player.processingState == ProcessingState.completed;
      final playing = _player.playing && !completed;
      if (!playing && mediaItem.value != null && !completed) {
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

  String _shortErr(Object e, String videoId) {
    final s = e
        .toString()
        .replaceAll(videoId, '')
        .replaceAll('YoutubeExplodeException:', '')
        .replaceAll('VideoUnplayableException:', '')
        .replaceAll('YoutubeExplode', '')
        .replaceAll('Exception:', '')
        .replaceAll('Video ', '')
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s.length > 42 ? s.substring(0, 42) : s;
  }

  void _onTrackFinished() {
    if (_isTransitioning || _isExtracting) return;
    _isTransitioning = true;
    _handleAutoPlayRadio();
  }

  Future<Video?> _searchNextCandidate(String query, Set<String> playedIds, {required bool strictDuration}) async {
    try {
      final results = await _yt.search.search(query).timeout(const Duration(seconds: 8));
      final list = results.where((v) {
        if (playedIds.contains(v.id.value)) return false;
        if (!strictDuration) return v.duration == null || v.duration!.inSeconds >= 60;
        return v.duration != null && v.duration!.inMinutes < 10 && v.duration!.inSeconds >= 60;
      }).toList();
      if (list.isNotEmpty) return list.first;
    } catch (_) {}
    return null;
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

    final playedIds = currentQueue.map((e) => e.id).toSet()..add(currentItem.id);

    try {
      Video? nextVideo;
      try {
        var currentVideo = await _yt.videos.get(currentItem.id).timeout(const Duration(seconds: 8));
        var relatedVideos = await _yt.videos.getRelatedVideos(currentVideo).timeout(const Duration(seconds: 8));
        if (relatedVideos != null && relatedVideos.isNotEmpty) {
          String clean1 = currentItem.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9áéíóúñ\s]'), '');
          Set<String> words1 = clean1.split(' ').where((w) => w.length > 2).toSet();
          for (var v in relatedVideos) {
            if (playedIds.contains(v.id.value)) continue;
            if (v.duration != null && (v.duration!.inMinutes >= 10 || v.duration!.inSeconds < 60)) continue;
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

      nextVideo ??= await _searchNextCandidate("${currentItem.artist ?? ''} éxitos", playedIds, strictDuration: true);
      nextVideo ??= await _searchNextCandidate("${currentItem.title} canción", playedIds, strictDuration: true);
      nextVideo ??= await _searchNextCandidate(currentItem.title, playedIds, strictDuration: false);

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
      } else {
        await _player.pause();
      }
    } catch (_) {
      await _player.pause();
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
  Future<void> play() async {
    if (_isExtracting) return;
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    await _player.play();
  }

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

  @override
  Future<void> playMediaItem(MediaItem item) async {
    _isExtracting = true;
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

    final yt = YoutubeExplode();
    try {
      playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.loading, playing: false));
      await _player.stop();
      await _player.seek(Duration.zero);

      final manifest = await yt.videos.streamsClient
          .getManifest(item.id)
          .timeout(const Duration(seconds: 15));

      final Uri primaryUrl = manifest.muxed.isNotEmpty
          ? manifest.muxed.withHighestBitrate().url
          : manifest.audioOnly.withHighestBitrate().url;

      try {
        final source = LockCachingAudioSource(primaryUrl, tag: item);
        await _player.setAudioSource(source).timeout(const Duration(seconds: 15));
      } catch (_) {
        final Uri fallbackUrl = manifest.audioOnly.isNotEmpty
            ? manifest.audioOnly.withHighestBitrate().url
            : primaryUrl;
        final fallbackSource = AudioSource.uri(fallbackUrl, tag: item);
        await _player.setAudioSource(fallbackSource).timeout(const Duration(seconds: 15));
      }

      _isExtracting = false;

      if (savedPosition > 0) {
        await _player.seek(Duration(milliseconds: savedPosition));
      }
      await _player.play();
    } catch (e) {
      _isExtracting = false;
      print("Playback Error: $e");
      mediaItem.add(item.copyWith(artist: "ERR: ${_shortErr(e, item.id)}"));
      playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.error, playing: false));
    } finally {
      yt.close();
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
