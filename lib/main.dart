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
    // Escuchamos los eventos del reproductor para actualizar el estado global
    _player.playbackEventStream.listen(_broadcastState);
    
    // Forzamos un elemento multimedia inicial para que Android reconozca la sesión desde el inicio
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
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> playMediaItem(MediaItem item) async {
    mediaItem.add(item);
    final url = item.extras?['url'] as String?;

    if (url != null) {
      try {
        await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
        play();
      } catch (e) {
        debugPrint("Error al reproducir: $e");
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
      androidNotificationChannelId: 'com.example.media_app.audio.media_channel_v5',
      androidNotificationChannelName: 'Reproductor Multimedia VIP',
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
              extras: {'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'},
            ));
          },
        ),
      ),
    );
  }
}
