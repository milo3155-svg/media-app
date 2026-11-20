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
  final AndroidEqualizer equalizer = AndroidEqualizer();
  late final AudioPlayer _player;
  late final YoutubeExplode _yt;
  Timer? _countdownTimer;
  bool _isTransitioning = false;
  bool _isExtracting = false;
  int _playRequestId = 0;

  List> _sponsorSegments = [];
  DateTime _lastSponsorSkip = DateTime.fromMillisecondsSinceEpoch(0);

  final ValueNotifier<int> sleepTimerRemaining = ValueNotifier<int>(0);
  final ValueNotifier<double> playbackSpeed = ValueNotifier<double>(1.0);
  final ValueNotifier<double> playbackPitch = ValueNotifier<double>(1.0);
  final ValueNotifier<LoopMode> loopMode = ValueNotifier<LoopMode>(LoopMode.off);
  final ValueNotifier<bool> sponsorBlockEnabled = ValueNotifier<bool>(true);

  MyAudioHandler() {
    _player = AudioPlayer(
      audioPipeline: AudioPipeline(
        androidAudioEffects: [if (Platform.isAndroid) equalizer],
      ),
    );
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
      if (state == ProcessingState.completed && !_isExtracting) {
        _onTrackFinished();
      }
    });
    _player.positionStream.listen((pos) {
      if (_isExtracting || _isTransitioning || !_player.playing) return;
      if (_player.processingState != ProcessingState.ready) return;

      if (sponsorBlockEnabled.value && _sponsorSegments.isNotEmpty) {
        final posSec = pos.inMilliseconds / 1000.0;
        if (DateTime.now().difference(_lastSponsorSkip).inMilliseconds >= 1500) {
          for (final seg in _sponsorSegments) {
            final start = seg['start'] ?? 0.0;
            final end = seg['end'] ?? 0.0;
            if (posSec >= start && posSec < end - 0.5) {
              _lastSponsorSkip = DateTime.now();
              unawaited(_player.seek(Duration(milliseconds: (end * 1000).round())));
              return;
            }
          }
        }
      }

      final dur = _player.duration;
      if (dur != null && dur.inSeconds > 10) {
        if (dur.inMilliseconds - pos.inMilliseconds <= 800) {
          _onTrackFinished();
        }
      }
    });
  }

  void toggleSponsorBlock() {
    sponsorBlockEnabled.value = !sponsorBlockEnabled.value;
  }

  Future<void> _fetchSponsorSegments(String videoId, int requestId) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final uri = Uri.parse(
        'https://sponsor.ajay.app/api/skipSegments?videoID=$videoId&categories=["sponsor","selfpromo","interaction"]',
      );
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(const Duration(seconds: 6));
      if (res.statusCode != 200 || requestId != _playRequestId) return;
      final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 6));
      final decoded = jsonDecode(body);
      if (decoded is List && requestId == _playRequestId) {
        final parsed = >[];
        for (final entry in decoded) {
          if (entry is Map && entry['segment'] is List && (entry['segment'] as List).length >= 2) {
            final seg = entry['segment'] as List;
            final start = (seg[0] as num).toDouble();
            final end = (seg[1] as num).toDouble();
            if (end > start + 1.0) {
              parsed.add({'start': start, 'end': end});
            }
          }
        }
        _sponsorSegments = parsed;
      }
    } catch (_) {
    } finally {
      client.close(force: true);
    }
  }

  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9ñ\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Set<String> _extractWords(String text, {Set<String> ignore = const {}}) {
    const noise = {
      'official', 'video', 'music', 'lyrics', 'lyric', 'audio', 'hd', '4k',
      'hq', 'live', 'letra', 'version', 'remastered', 'visualizer', 'ft',
      'feat', 'mv', 'topic', 'vevo', 'clip', 'full', 'song', 'cancion'
    };
    return _normalizeText(text)
        .split(' ')
        .where((w) => w.length >= 2 && !noise.contains(w) && !ignore.contains(w))
        .toSet();
  }

  bool _isCloneOfAny(
    String candidateTitle,
    List<Set<String>> playedTitleSets,
    Set<String> artistWords,
    Set<String> playedNormalizedTitles, {
    required bool isLongTrack,
  }) {
    final norm = _normalizeText(candidateTitle);
    if (playedNormalizedTitles.contains(norm)) return true;
    if (isLongTrack) return false;
    final candWords = _extractWords(candidateTitle, ignore: artistWords);
    if (candWords.isEmpty) return false;
    for (final prevWords in playedTitleSets) {
      if (prevWords.isEmpty) continue;
      final matches = candWords.intersection(prevWords).length;
      final similarity = matches / math.min(candWords.length, prevWords.length);
      if (similarity >= 0.5) return true;
    }
    return false;
  }

  bool _isValidDuration(Duration? d, {required bool isLongTrack, required bool strict}) {
    if (isLongTrack) {
      if (d == null) return !strict;
      return strict ? d.inMinutes >= 12 : d.inMinutes >= 8;
    }
    if (strict) {
      return d != null && d.inMinutes < 10 && d.inSeconds >= 60;
    }
    return d == null || d.inSeconds >= 60;
  }

  bool _matchesPodcastContext(MediaItem candidate, MediaItem current) {
    final candArtist = _normalizeText(candidate.artist ?? '');
    final currArtist = _normalizeText(current.artist ?? '');
    if (currArtist.isNotEmpty && currArtist != 'youtube' && candArtist == currArtist) {
      return true;
    }
    final showPrefix = _normalizeText(_extractShowPrefix(current.title));
    if (showPrefix.length >= 4 && _normalizeText(candidate.title).contains(showPrefix)) {
      return true;
    }
    return false;
  }

  String _extractText(dynamic obj) {
    if (obj is Map) {
      if (obj['simpleText'] is String) return obj['simpleText'] as String;
      if (obj['runs'] is List) {
        return (obj['runs'] as List).whereType().map((r) => r['text']?.toString() ?? '').join();
      }
    }
    return '';
  }

  Duration? _parseDuration(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final parts = text.trim().split(':').map((p) => int.tryParse(p.trim())).toList();
    if (parts.any((p) => p == null)) return null;
    if (parts.length == 3) {
      return Duration(hours: parts[0]!, minutes: parts[1]!, seconds: parts[2]!);
    } else if (parts.length == 2) {
      return Duration(minutes: parts[0]!, seconds: parts[1]!);
    } else if (parts.length == 1) {
      return Duration(seconds: parts[0]!);
    }
    return null;
  }

  void _collectVideos(dynamic node, List<MediaItem> out, Set<String> seen) {
    if (node is Map) {
      final vr = node['videoRenderer'];
      if (vr is Map) {
        final videoId = vr['videoId']?.toString() ?? '';
        if (videoId.isNotEmpty && seen.add(videoId)) {
          final title = _extractText(vr['title']).trim();
          String author = _extractText(vr['ownerText']).trim();
          if (author.isEmpty) author = _extractText(vr['longBylineText']).trim();
          if (author.isEmpty) author = _extractText(vr['shortBylineText']).trim();
          if (author.isEmpty) author = 'YouTube';
          final duration = _parseDuration(_extractText(vr['lengthText']));
          if (title.isNotEmpty) {
            out.add(MediaItem(
              id: videoId,
              title: title,
              artist: author,
              duration: duration,
              artUri: Uri.parse('https://i.ytimg.com/vi/$videoId/hqdefault.jpg'),
            ));
          }
        }
      }
      for (final value in node.values) {
        _collectVideos(value, out, seen);
      }
    } else if (node is List) {
      for (final item in node) {
        _collectVideos(item, out, seen);
      }
    }
  }

  Future<List<MediaItem>> _searchYoutubeDirect(String query) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await client.postUrl(
        Uri.parse('https://www.youtube.com/youtubei/v1/search?prettyPrint=false'),
      );
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
      req.headers.set('Accept-Language', 'es-MX,es;q=0.9');
      final payload = jsonEncode({
        'context': {
          'client': {
            'clientName': 'WEB',
            'clientVersion': '2.20241120.00.00',
            'hl': 'es',
            'gl': 'MX',
          },
        },
        'query': query,
      });
      req.add(utf8.encode(payload));
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 8));
      final data = jsonDecode(body);
      final items = <MediaItem>[];
      final seen = <String>{};
      _collectVideos(data, items, seen);
      return items;
    } catch (_) {
      return [];
    } finally {
      client.close(force: true);
    }
  }

  void _onTrackFinished() {
    if (_isTransitioning || _isExtracting) return;
    if (loopMode.value == LoopMode.one) {
      _isTransitioning = true;
      _player.seek(Duration.zero).then((_) {
        unawaited(_player.play());
      }).whenComplete(() {
        Future.delayed(const Duration(milliseconds: 500), () => _isTransitioning = false);
      });
      return;
    }
    _isTransitioning = true;
    _handleAutoPlayRadio();
  }

  Future<MediaItem?> _searchNextCandidate(
    String query,
    Set<String> playedIds,
    List<Set<String>> playedTitleSets,
    Set<String> artistWords,
    Set<String> playedNormalizedTitles, {
    required bool isLongTrack,
    required bool strictDuration,
    bool Function(MediaItem)? predicate,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    final results = await _searchYoutubeDirect(trimmed);
    for (final item in results) {
      if (playedIds.contains(item.id)) continue;
      if (!_isValidDuration(item.duration, isLongTrack: isLongTrack, strict: strictDuration)) continue;
      if (predicate != null && !predicate(item)) continue;
      if (_isCloneOfAny(item.title, playedTitleSets, artistWords, playedNormalizedTitles, isLongTrack: isLongTrack)) {
        continue;
      }
      return item;
    }
    return null;
  }

  String _extractShowPrefix(String title) {
    final parts = title.split(RegExp(r'[:|\-]'));
    final first = parts.isNotEmpty ? parts.first.trim() : '';
    return first.length >= 4 ? first : title.trim();
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

    if (loopMode.value == LoopMode.all && currentQueue.length > 1) {
      await playMediaItem(currentQueue.first);
      _isTransitioning = false;
      return;
    }

    final bool isLongTrack = (currentItem.duration?.inMinutes ?? 0) >= 12;
    final playedIds = currentQueue.map((e) => e.id).toSet()..add(currentItem.id);
    final playedNormalizedTitles = <String>{
      _normalizeText(currentItem.title),
      for (final q in currentQueue) _normalizeText(q.title),
    };
    final artistWords = <String>{
      ..._extractWords(currentItem.artist ?? ''),
      for (final q in currentQueue) ..._extractWords(q.artist ?? ''),
    };
    final playedTitleSets = <Set<String>>[
      _extractWords(currentItem.title, ignore: artistWords),
      for (final q in currentQueue) _extractWords(q.title, ignore: artistWords),
    ];

    try {
      MediaItem? nextItem;
      try {
        var currentVideo = await _yt.videos.get(currentItem.id).timeout(const Duration(seconds: 6));
        var relatedVideos = await _yt.videos.getRelatedVideos(currentVideo).timeout(const Duration(seconds: 6));
        if (relatedVideos != null && relatedVideos.isNotEmpty) {
          for (var v in relatedVideos) {
            if (playedIds.contains(v.id.value)) continue;
            if (!_isValidDuration(v.duration, isLongTrack: isLongTrack, strict: true)) continue;
            if (_isCloneOfAny(v.title, playedTitleSets, artistWords, playedNormalizedTitles, isLongTrack: isLongTrack)) {
              continue;
            }
            final candidate = MediaItem(
              id: v.id.value,
              title: v.title,
              artist: v.author,
              duration: v.duration,
              artUri: Uri.parse(v.thumbnails.highResUrl),
            );
            if (isLongTrack && !_matchesPodcastContext(candidate, currentItem)) continue;
            nextItem = candidate;
            break;
          }
        }
      } catch (_) {}

      final seedArtist = (currentItem.artist ?? '').trim();

      if (isLongTrack) {
        final showPrefix = _extractShowPrefix(currentItem.title);
        nextItem ??= await _searchNextCandidate(
          showPrefix,
          playedIds,
          playedTitleSets,
          artistWords,
          playedNormalizedTitles,
          isLongTrack: true,
          strictDuration: true,
          predicate: (cand) => _matchesPodcastContext(cand, currentItem),
        );
        if (nextItem == null && seedArtist.isNotEmpty) {
          nextItem = await _searchNextCandidate(
            seedArtist,
            playedIds,
            playedTitleSets,
            artistWords,
            playedNormalizedTitles,
            isLongTrack: true,
            strictDuration: true,
            predicate: (cand) => _matchesPodcastContext(cand, currentItem),
          );
        }
        nextItem ??= await _searchNextCandidate(
          showPrefix,
          playedIds,
          playedTitleSets,
          artistWords,
          playedNormalizedTitles,
          isLongTrack: true,
          strictDuration: true,
        );
        nextItem ??= await _searchNextCandidate(
          seedArtist.isNotEmpty ? seedArtist : currentItem.title,
          playedIds,
          playedTitleSets,
          artistWords,
          playedNormalizedTitles,
          isLongTrack: true,
          strictDuration: false,
        );
      } else {
        if (nextItem == null && seedArtist.isNotEmpty) {
          nextItem = await _searchNextCandidate(
            "$seedArtist éxitos",
            playedIds,
            playedTitleSets,
            artistWords,
            playedNormalizedTitles,
            isLongTrack: false,
            strictDuration: true,
          );
        }
        nextItem ??= await _searchNextCandidate(
          "${currentItem.title} mix",
          playedIds,
          playedTitleSets,
          artistWords,
          playedNormalizedTitles,
          isLongTrack: false,
          strictDuration: true,
        );
        nextItem ??= await _searchNextCandidate(
          seedArtist.isNotEmpty ? seedArtist : currentItem.title,
          playedIds,
          playedTitleSets,
          artistWords,
          playedNormalizedTitles,
          isLongTrack: false,
          strictDuration: false,
        );
      }

      if (nextItem != null) {
        final newQueue = List<MediaItem>.from(currentQueue)..add(nextItem);
        await updateQueue(newQueue);
        await playMediaItem(nextItem);
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
  Future<void> setSpeed(double speed) async {
    final clamped = speed.clamp(0.5, 2.0);
    playbackSpeed.value = clamped;
    await _player.setSpeed(clamped);
  }

  Future<void> setPitch(double pitch) async {
    final clamped = pitch.clamp(0.5, 2.0);
    playbackPitch.value = clamped;
    await _player.setPitch(clamped);
  }

  Future<void> cycleLoopMode() async {
    final next = switch (loopMode.value) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    loopMode.value = next;
  }

  Future<void> seekRelative(Duration offset) async {
    final dur = _player.duration ?? mediaItem.value?.duration;
    final targetMs = _player.position.inMilliseconds + offset.inMilliseconds;
    final maxMs = dur?.inMilliseconds ?? targetMs;
    final clampedMs = targetMs.clamp(0, maxMs > 0 ? maxMs : 0);
    await _player.seek(Duration(milliseconds: clampedMs));
  }

  Future<void> reloadCurrentTrack() async {
    final current = mediaItem.value;
    if (current == null) return;
    _saveResumePosition(current.id, _player.position.inMilliseconds);
    await playMediaItem(current);
  }

  void reorderQueue(int oldIndex, int newIndex) {
    final currentQueue = List<MediaItem>.from(queue.value);
    if (oldIndex < 0 || oldIndex >= currentQueue.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= currentQueue.length) return;
    final moved = currentQueue.removeAt(oldIndex);
    currentQueue.insert(newIndex, moved);
    updateQueue(currentQueue);
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'kill') {
      _playRequestId++;
      _isExtracting = false;
      _sponsorSegments = [];
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
    if (playbackState.value.processingState == AudioProcessingState.error && mediaItem.value != null) {
      await playMediaItem(mediaItem.value!);
      return;
    }
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    unawaited(_player.play());
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
    final requestId = ++_playRequestId;
    _isExtracting = true;
    _sponsorSegments = [];
    mediaItem.add(item);

    if (sponsorBlockEnabled.value) {
      unawaited(_fetchSponsorSegments(item.id, requestId));
    }

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

    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.loading,
      playing: false,
    ));

    try {
      await _player.stop();
      await _player.seek(Duration.zero);
    } catch (_) {}

    Object? lastError;
    for (int attempt = 0; attempt < 2; attempt++) {
      if (requestId != _playRequestId) return;
      final yt = YoutubeExplode();
      try {
        final manifest = await yt.videos.streamsClient
            .getManifest(item.id)
            .timeout(const Duration(seconds: 15));
        if (requestId != _playRequestId) return;

        final Uri primaryUrl = manifest.muxed.isNotEmpty
            ? manifest.muxed.withHighestBitrate().url
            : manifest.audioOnly.withHighestBitrate().url;

        try {
          final source = LockCachingAudioSource(primaryUrl, tag: item);
          await _player.setAudioSource(source).timeout(const Duration(seconds: 15));
        } catch (_) {
          if (requestId != _playRequestId) return;
          final Uri fallbackUrl = manifest.audioOnly.isNotEmpty
              ? manifest.audioOnly.withHighestBitrate().url
              : primaryUrl;
          final fallbackSource = AudioSource.uri(fallbackUrl, tag: item);
          await _player.setAudioSource(fallbackSource).timeout(const Duration(seconds: 15));
        }

        if (requestId != _playRequestId) return;
        await _player.setSpeed(playbackSpeed.value);
        await _player.setPitch(playbackPitch.value);
        _isExtracting = false;

        if (savedPosition > 0 && (item.duration == null || savedPosition < item.duration!.inMilliseconds - 5000)) {
          await _player.seek(Duration(milliseconds: savedPosition));
        }
        if (requestId != _playRequestId) return;
        unawaited(_player.play());
        return;
      } catch (e) {
        lastError = e;
        if (attempt == 0 && requestId == _playRequestId) {
          await Future.delayed(const Duration(milliseconds: 700));
        }
      } finally {
        yt.close();
      }
    }

    if (requestId != _playRequestId) return;
    _isExtracting = false;
    print("Playback Error: $lastError");
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.error,
      playing: false,
    ));
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
