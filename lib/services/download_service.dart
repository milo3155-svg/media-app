import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DownloadService {
  static final ValueNotifier> progressMap =
      ValueNotifier>({});

  static String? getLocalPath(String videoId) {
    if (!Hive.isBoxOpen('downloads')) return null;
    final box = Hive.box('downloads');
    if (!box.containsKey(videoId)) return null;
    final data = box.get(videoId);
    if (data is Map) {
      final path = data['localPath']?.toString() ?? '';
      if (path.isNotEmpty && File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }

  static bool isDownloaded(String videoId) => getLocalPath(videoId) != null;

  static void _updateProgress(String videoId, double? value) {
    final next = Map<String, double>.from(progressMap.value);
    if (value == null) {
      next.remove(videoId);
    } else {
      next[videoId] = value.clamp(0.0, 1.0);
    }
    progressMap.value = next;
  }

  static Future<bool> downloadTrack(MediaItem item) async {
    if (progressMap.value.containsKey(item.id)) return false;
    if (isDownloaded(item.id)) return true;

    _updateProgress(item.id, 0.01);
    final yt = YoutubeExplode();
    IOSink? sink;
    File? targetFile;

    try {
      final box = Hive.box('downloads');
      final baseDir = File(box.path!).parent;
      final audioDir = Directory('${baseDir.path}/offline_audio');
      if (!audioDir.existsSync()) {
        audioDir.createSync(recursive: true);
      }

      final manifest = await yt.videos.streamsClient
          .getManifest(item.id)
          .timeout(const Duration(seconds: 20));

      final streamInfo = manifest.audioOnly.isNotEmpty
          ? manifest.audioOnly.withHighestBitrate()
          : manifest.muxed.withHighestBitrate();

      final ext = streamInfo.container.name;
      targetFile = File('${audioDir.path}/${item.id}.$ext');
      sink = targetFile.openWrite();

      final totalBytes = streamInfo.size.totalBytes;
      int receivedBytes = 0;

      final stream = yt.videos.streamsClient.get(streamInfo);
      await for (final chunk in stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          _updateProgress(item.id, receivedBytes / totalBytes);
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      await box.put(item.id, {
        'id': item.id,
        'title': item.title,
        'artist': item.artist ?? '',
        'artUri': item.artUri?.toString() ?? '',
        'duration': item.duration?.inMilliseconds ?? 0,
        'localPath': targetFile.path,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      _updateProgress(item.id, null);
      return true;
    } catch (_) {
      try {
        await sink?.close();
      } catch (_) {}
      try {
        if (targetFile != null && targetFile.existsSync()) {
          targetFile.deleteSync();
        }
      } catch (_) {}
      _updateProgress(item.id, null);
      return false;
    } finally {
      yt.close();
    }
  }

  static Future<void> deleteDownload(String videoId) async {
    final box = Hive.box('downloads');
    if (box.containsKey(videoId)) {
      final data = box.get(videoId);
      if (data is Map) {
        final path = data['localPath']?.toString() ?? '';
        if (path.isNotEmpty) {
          final file = File(path);
          if (file.existsSync()) {
            try {
              file.deleteSync();
            } catch (_) {}
          }
        }
      }
      await box.delete(videoId);
    }
  }
}
