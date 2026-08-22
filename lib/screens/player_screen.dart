import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // Solo conservamos los estados visuales que son exclusivos de esta pantalla
  bool _isFavorite = false;
  bool _isAudioOnly = false;
  bool _ccEnabled = false;

  @override
  Widget build(BuildContext context) {
    // Conectamos esta pantalla al gestor global
    final musicProvider = context.watch<MusicProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.download), onPressed: () {}),
          IconButton(icon: const Icon(Icons.hd), onPressed: () {}),
          Row(
            children: [
              const Text('Solo Audio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Switch(
                value: _isAudioOnly,
                activeColor: Colors.purpleAccent,
                onChanged: (val) => setState(() => _isAudioOnly = val),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.35,
            color: Colors.black,
            child: const Center(
              child: Icon(Icons.play_circle_outline, size: 64, color: Colors.grey),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.closed_caption, color: _ccEnabled ? Colors.purpleAccent : Colors.white),
                onPressed: () => setState(() => _ccEnabled = !_ccEnabled),
              ),
              IconButton(
                icon: const Icon(Icons.fullscreen, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // El título ahora se lee desde el cerebro global
                      Text(
                        musicProvider.currentTrack,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Nombre del Canal / Artista',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                    color: _isFavorite ? Colors.purpleAccent : Colors.white,
                  ),
                  onPressed: () => setState(() => _isFavorite = !_isFavorite),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(icon: const Icon(Icons.skip_previous, size: 36, color: Colors.white), onPressed: () {}),
              IconButton(icon: const Icon(Icons.replay_10, size: 32, color: Colors.white), onPressed: () {}),
              Container(
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.deepPurple),
                child: IconButton(
                  // El botón reacciona al estado global en tiempo real
                  icon: Icon(musicProvider.isPlaying ? Icons.pause : Icons.play_arrow, size: 48, color: Colors.white),
                  onPressed: () {
                    // Envía la orden global de Play/Pausa
                    context.read<MusicProvider>().togglePlay();
                  },
                ),
              ),
              IconButton(icon: const Icon(Icons.forward_10, size: 32, color: Colors.white), onPressed: () {}),
              IconButton(icon: const Icon(Icons.skip_next, size: 36, color: Colors.white), onPressed: () {}),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Reproduciendo 1 de 20', style: TextStyle(color: Colors.grey)),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
