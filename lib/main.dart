import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();

  MyAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    _player.playbackEventStream.listen(_broadcastState);
    
    // Elemento inicial para despertar la sesión multimedia desde el inicio
    mediaItem.add(const MediaItem(
      id: 'init_audio',
      album: 'Spotify-Killer',
      title: 'Reproductor VIP',
      artist: 'Laboratorio Android',
    ));
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    ));
  }

  @override
  Future<void> play() async {
    await _player.play();
    _broadcastState(_player.playbackEvent);
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _broadcastState(_player.playbackEvent);
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async => debugPrint("Siguiente");

  @override
  Future<void> skipToPrevious() async => debugPrint("Anterior");

  @override
  Future<void> playMediaItem(MediaItem item) async {
    // 1. Vinculamos metadatos al frente (AHORA LLEVA LA IMAGEN)
    mediaItem.add(item);
    final url = item.extras?['url'] as String?;

    if (url != null) {
      try {
        await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
        
        // 2. Forzamos el estado activo con los controles visibles
        playbackState.add(playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            MediaControl.pause,
            MediaControl.skipToNext,
          ],
          processingState: AudioProcessingState.ready,
          playing: true,
        ));

        await _player.play();
      } catch (e) {
        debugPrint("Error crítico al reproducir: $e");
      }
    }
  }
}

AudioHandler? audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      // Le cambiamos el ID al canal para que Android lo cree desde cero y fresquito
      androidNotificationChannelId: 'com.example.media_app.audio.master_final_v3',
      androidNotificationChannelName: 'Reproductor VIP Multimedia',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );

  runApp(const MediaApp());
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spotify-Killer VIP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spotify-Killer VIP'),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
      body: Center(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurpleAccent,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          icon: const Icon(Icons.play_arrow, size: 32, color: Colors.white),
          label: const Text('PROBAR PANTALLA DE BLOQUEO',
              style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          onPressed: () {
            audioHandler?.playMediaItem(MediaItem(
              id: 'test_audio_1',
              title: 'Prueba de Sistema VIP',
              artist: 'Laboratorio Android',
              // 👇 LA PIEZA CLAVE QUE RECORDASTE: Imagen de Portada
              artUri: Uri.parse('https://picsum.photos/500/500'),
              extras: {'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'},
            ));
          },
        ),
      ),
    );
  }
}
