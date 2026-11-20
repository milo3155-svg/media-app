import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/download_service.dart';

class DownloadsScreen extends StatelessWidget {
  final Color accentColor;
  final Future<void> Function(List<MediaItem> items, int index) onPlayQueue;

  const DownloadsScreen({
    super.key,
    required this.accentColor,
    required this.onPlayQueue,
  });

  @override
  Widget build(BuildContext context) {
    if (!Hive.isBoxOpen('downloads')) {
      return const Center(
        child: Text('Inicializando descargas...', style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: [
        ValueListenableBuilder<dynamic>(
          valueListenable: DownloadService.progressMap,
          builder: (context, rawMap, _) {
            final active = (rawMap is Map) ? rawMap : {};
            if (active.isEmpty) return const SizedBox.shrink();
            return Container(
              color: const Color(0xFF1A1A1A),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Descargando (${active.length})',
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  ...active.entries.map((e) {
                    final pct = ((e.value as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ID: ${e.key} • ${(pct * 100).round()}%',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: pct,
                            color: accentColor,
                            backgroundColor: Colors.white12,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: Hive.box('downloads').listenable(),
            builder: (context, Box box, _) {
              final rawList = box.values.where((v) => v is Map).toList();
              rawList.sort((a, b) => ((b['timestamp'] ?? 0) as int).compareTo((a['timestamp'] ?? 0) as int));

              if (rawList.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_done, color: Colors.white24, size: 54),
                      SizedBox(height: 12),
                      Text('Sin pistas descargadas', style: TextStyle(color: Colors.grey, fontSize: 15)),
                    ],
                  ),
                );
              }

              final mediaItems = rawList.map((e) {
                final art = e['artUri']?.toString() ?? '';
                final durMs = (e['duration'] ?? 0) as int;
                return MediaItem(
                  id: e['id']?.toString() ?? '',
                  title: e['title']?.toString() ?? 'Sin título',
                  artist: e['artist']?.toString() ?? '',
                  artUri: art.isNotEmpty ? Uri.tryParse(art) : null,
                  duration: durMs > 0 ? Duration(milliseconds: durMs) : null,
                );
              }).toList();

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 110, top: 6),
                itemCount: mediaItems.length,
                itemBuilder: (context, index) {
                  final item = mediaItems[index];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: (item.artUri?.toString().isNotEmpty ?? false)
                          ? Image.network(
                              item.artUri.toString(),
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 50,
                                height: 50,
                                color: const Color(0xFF1F1F1F),
                                child: const Icon(Icons.music_note, color: Colors.white38),
                              ),
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              color: const Color(0xFF1F1F1F),
                              child: const Icon(Icons.music_note, color: Colors.white38),
                            ),
                    ),
                    title: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      'Offline • ${item.artist ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: accentColor.withOpacity(0.85), fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () => DownloadService.deleteDownload(item.id),
                    ),
                    onTap: () => onPlayQueue(mediaItems, index),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
