import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';

class YoutubeFeedService {
  static String _extractText(dynamic obj) {
    if (obj is Map) {
      if (obj['simpleText'] is String) return obj['simpleText'] as String;
      if (obj['runs'] is List) {
        return (obj['runs'] as List)
            .where((r) => r is Map)
            .map((r) => r['text']?.toString() ?? '')
            .join();
      }
    }
    return '';
  }

  static Duration? _parseDuration(String? text) {
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

  static void _collectVideos(dynamic node, List<MediaItem> out, Set<String> seen) {
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

  static Future<List<MediaItem>> fetchByQuery(String query, {int limit = 20}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
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
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 10));
      final data = jsonDecode(body);
      final items = <MediaItem>[];
      final seen = <String>{};
      _collectVideos(data, items, seen);
      return items.take(limit).toList();
    } catch (_) {
      return [];
    } finally {
      client.close(force: true);
    }
  }
}
