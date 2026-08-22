import 'package:flutter/material.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // Variables de estado para animar los botones al tocarlos
  bool _isPlaying = false;
  bool _isFavorite = false;
  bool _isAudioOnly = false;
  bool _ccEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32),
          onPressed: () => Navigator.pop(context), // Botón para minimizar
        ),
        actions: [
          IconButton(icon: const Icon(Icons.download), onPressed: () {}),
          IconButton(icon: const Icon(Icons.hd), onPressed: () {}), // Calidades
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
          // Área del reproductor (Video o Carátula)
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.35,
            color: Colors.black, // Aquí irá el video o la imagen limpia
            child: const Center(
              child: Icon(Icons.play_circle_outline, size: 64, color: Colors.grey),
            ),
          ),
          
          // Fila debajo del video: Subtítulos y Maximizar
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
          
          // Información de la pista
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Título de la pista (Simulada)',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Nombre del Canal / Artista',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                // Botón de Favoritos (Pulgar Arriba)
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
          
          // Controles Centrales de Reproducción
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(icon: const Icon(Icons.skip_previous, size: 36, color: Colors.white), onPressed: () {}),
              IconButton(icon: const Icon(Icons.replay_10, size: 32, color: Colors.white), onPressed: () {}), // Atrás 10s
              Container(
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.deepPurple),
                child: IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 48, color: Colors.white),
                  onPressed: () => setState(() => _isPlaying = !_isPlaying),
                ),
              ),
              IconButton(icon: const Icon(Icons.forward_10, size: 32, color: Colors.white), onPressed: () {}), // Adelante 10s
              IconButton(icon: const Icon(Icons.skip_next, size: 36, color: Colors.white), onPressed: () {}),
            ],
          ),
          
          const Spacer(),
          
          // Pie de Pantalla (Cola de reproducción)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Reproduciendo 1 de 20', style: TextStyle(color: Colors.grey)),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
                  onPressed: () {}, // Aquí levantaremos la lista de reproducción (Up Next)
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
