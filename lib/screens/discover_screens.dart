import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../services/youtube_feed_service.dart';

String _formatDur(Duration? d) {
  if (d == null || d == Duration.zero) return "";
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return "${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds";
}

Widget _panoramicThumb(String? url, Duration? duration) {
  final cleanUrl = (url ?? '').trim();
  final durText = _formatDur(duration);
  return Stack(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: cleanUrl.isEmpty
            ? Container(
                width: 136,
                height: 76,
                color: const Color(0xFF1F1F1F),
                alignment: Alignment.center,
                child: const Icon(Icons.music_note, color: Colors.white38),
              )
            : Image.network(
                cleanUrl,
                width: 136,
                height: 76,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 136,
                  height: 76,
                  color: const Color(0xFF1F1F1F),
                  alignment: Alignment.center,
                  child: const Icon(Icons.music_note, color: Colors.white38),
                ),
              ),
      ),
      if (durText.isNotEmpty)
        Positioned(
          right: 4,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              durText,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
    ],
  );
}

class HomeFeedTab extends StatefulWidget {
  final Color accentColor;
  final Future<void> Function(MediaItem item) onPlay;
  final void Function(BuildContext context, MediaItem item) onOptions;

  const HomeFeedTab({
    super.key,
    required this.accentColor,
    required this.onPlay,
    required this.onOptions,
  });

  @override
  State<HomeFeedTab> createState() => _HomeFeedTabState();
}

class _HomeFeedTabState extends State<HomeFeedTab> with AutomaticKeepAliveClientMixin {
  final List<String> _chipLabels = ['Todo', 'Música', 'Pódcasts', 'Mixes', 'Rock', 'Electrónica'];
  final Map<String, String> _chipQueries = {
    'Todo': 'musica exitos latinoamerica 2026',
    'Música': 'top canciones populares mexico 2026',
    'Pódcasts': 'podcasts populares en español completos',
    'Mixes': 'music mix playlist 1 hora',
    'Rock': 'rock en español clasicos exitos',
    'Electrónica': 'electronic music mix edm house',
  };

  String _selectedChip = 'Todo';
  List<MediaItem> _items = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadFeed(_selectedChip);
  }

  Future<void> _loadFeed(String chip) async {
    setState(() {
      _selectedChip = chip;
      _isLoading = true;
    });
    final query = _chipQueries[chip] ?? 'musica populares';
    final results = await YoutubeFeedService.fetchByQuery(query, limit: 20);
    if (!mounted) return;
    setState(() {
      _items = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            itemCount: _chipLabels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final label = _chipLabels[index];
              final selected = label == _selectedChip;
              return ChoiceChip(
                label: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: selected,
                selectedColor: widget.accentColor,
                backgroundColor: const Color(0xFF1F1F1F),
                side: BorderSide(color: selected ? widget.accentColor : Colors.white24),
                onSelected: (_) {
                  if (!selected) _loadFeed(label);
                },
              );
            },
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: widget.accentColor))
              : _items.isEmpty
                  ? Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.accentColor,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () => _loadFeed(_selectedChip),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    )
                  : RefreshIndicator(
                      color: widget.accentColor,
                      onRefresh: () => _loadFeed(_selectedChip),
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 110, top: 4),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return InkWell(
                            onTap: () => widget.onPlay(item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _panoramicThumb(item.artUri?.toString(), item.duration),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.artist ?? 'YouTube',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                                    onPressed: () => widget.onOptions(context, item),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

class TrendingTab extends StatefulWidget {
  final Color accentColor;
  final Future<void> Function(MediaItem item) onPlay;
  final void Function(BuildContext context, MediaItem item) onOptions;

  const TrendingTab({
    super.key,
    required this.accentColor,
    required this.onPlay,
    required this.onOptions,
  });

  @override
  State<TrendingTab> createState() => _TrendingTabState();
}

class _TrendingTabState extends State<TrendingTab> with AutomaticKeepAliveClientMixin {
  List<MediaItem> _trendingClips = [];
  List<MediaItem> _weeklyTop = [];
  List<MediaItem> _dailyClips = [];
  bool _isLoading = true;
  bool _expandTrending = false;
  bool _expandWeekly = false;
  bool _expandDaily = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      YoutubeFeedService.fetchByQuery('videoclips en tendencia musica mexico 2026', limit: 15),
      YoutubeFeedService.fetchByQuery('canciones mas populares de la semana mexico', limit: 15),
      YoutubeFeedService.fetchByQuery('estrenos musicales hoy video oficial', limit: 15),
    ]);
    if (!mounted) return;
    setState(() {
      _trendingClips = results[0];
      _weeklyTop = results[1];
      _dailyClips = results[2];
      _isLoading = false;
    });
  }

  Widget _buildSection({
    required String title,
    required List<MediaItem> items,
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    final visible = expanded ? items : items.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
          child: Row(
            children: [
              Container(width: 4, height: 18, color: widget.accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        ...visible.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final item = entry.value;
          return InkWell(
            onTap: () => widget.onPlay(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _panoramicThumb(item.artUri?.toString(), item.duration),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.artist ?? 'YouTube'} • #$rank',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                    onPressed: () => widget.onOptions(context, item),
                  ),
                ],
              ),
            ),
          );
        }),
        if (items.length > 4)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: onToggle,
                child: Text(
                  expanded ? 'Mostrar menos' : 'Mostrar más (${items.length - 4})',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: widget.accentColor));
    }
    return RefreshIndicator(
      color: widget.accentColor,
      onRefresh: _loadTrending,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          _buildSection(
            title: 'Videoclips en tendencia',
            items: _trendingClips,
            expanded: _expandTrending,
            onToggle: () => setState(() => _expandTrending = !_expandTrending),
          ),
          _buildSection(
            title: 'Canciones más populares de la semana',
            items: _weeklyTop,
            expanded: _expandWeekly,
            onToggle: () => setState(() => _expandWeekly = !_expandWeekly),
          ),
          _buildSection(
            title: 'Videoclips más populares del día',
            items: _dailyClips,
            expanded: _expandDaily,
            onToggle: () => setState(() => _expandDaily = !_expandDaily),
          ),
        ],
      ),
    );
  }
}
