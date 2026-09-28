import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_downloader/flutter_downloader.dart';

// Importa tu Bóveda Offline
import 'offline_vault_screen.dart';

class VIPHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)';
  }
}

// Variables Globales
late MyAudioHandler audioHandler;
final ValueNotifier<bool> isHDMode = ValueNotifier<bool>(true);
final ValueNotifier<Color> appColor = ValueNotifier<Color>(Colors.cyanAccent);
final ValueNotifier<int> sleepTimerRemaining = ValueNotifier<int>(0);

Future<String?> obtenerAudioDirecto(String videoId) async {
  try {
    final yt = YoutubeExplode();
    final manifest = await yt.videos.streamsClient.getManifest(videoId);
    final streamsMp4 = manifest.audioOnly.where((stream) => stream.container.name == 'mp4');
    final streamInfo = streamsMp4.withHighestBitrate();
    yt.close();
    return streamInfo.url.toString();
  } catch (e) {
    print("Error obteniendo URL: \$e");
    return null;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = VIPHttpOverrides();

  await Hive.initFlutter();
  await Hive.openBox('favorites');
  await Hive.openBox('history');
  await Hive.openBox('search_history');
  await Hive.openBox('playlists');
  await Hive.openBox('downloads'); // Caja para la Bóveda Offline

  await FlutterDownloader.initialize(debug: true, ignoreSsl: true);

  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.tuapp.audio',
      androidNotificationChannelName: 'Spotify Killer VIP',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(const MediaApp());
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: appColor,
      builder: (context, color, child) {
        return MaterialApp(
          title: 'Spotify Killer VIP',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: color,
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF121212),
              elevation: 0,
            ),
          ),
          // Aquí arranca tu pantalla visual principal
          home: const MainScreen(),
        );
      },
    );
  }
}
class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  final _yt = YoutubeExplode();
  bool _isAutoPlayEnabled = true;
  String? _lastPlayedId;
  DateTime? _lastPlayTime;

  MyAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);
    
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });

    _player.positionStream.listen((position) {
      final currentState = playbackState.value;
      playbackState.add(currentState.copyWith(updatePosition: position));
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
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
      queueIndex: event.currentIndex,
    ));
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'playLocal' && extras != null) {
      final localPath = extras['localPath'] as String;
      final title = extras['title'] as String;
      final artist = extras['artist'] as String;
      final artUri = extras['artUri'] as String;
      final duration = extras['duration'] as int? ?? 0;
      
      final newItem = MediaItem(
        id: localPath,
        title: title,
        artist: artist,
        artUri: Uri.parse(artUri),
        duration: Duration(seconds: duration),
        extras: {'isLocal': true},
      );
      
      mediaItem.add(newItem);
      await _player.setFilePath(localPath);
      play();
    }
  }

  @override
  Future<void> playMediaItem(MediaItem item) async {
    final now = DateTime.now();
    if (_lastPlayedId == item.id && _lastPlayTime != null) {
      if (now.difference(_lastPlayTime!).inSeconds < 2) {
        print("Bloqueo anti-rebote activado para: \${item.title}");
        return;
      }
    }
    
    _lastPlayedId = item.id;
    _lastPlayTime = now;
    mediaItem.add(item);
    
    final historyBox = Hive.box('history');
    final itemMap = {
      'id': item.id,
      'title': item.title,
      'artist': item.artist ?? 'Desconocido',
      'duration': item.duration?.inSeconds ?? 0,
      'artUri': item.artUri?.toString() ?? '',
    };
    
    historyBox.put(item.id, itemMap);
    if (historyBox.length > 50) {
      historyBox.deleteAt(0);
    }

    try {
      final url = await obtenerAudioDirecto(item.id);
      if (url != null) {
        await _player.setUrl(url);
        play();
      } else {
        print("No se pudo obtener URL para: \${item.title}");
      }
    } catch (e) {
      print("Error en playMediaItem: \$e");
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    queue.add(newQueue);
  }

  @override
  Future<void> skipToNext() async {
    final queueList = queue.value;
    if (queueList.isEmpty) return;
    
    final currentItem = mediaItem.value;
    final currentIndex = queueList.indexWhere((item) => item.id == currentItem?.id);
    
    if (currentIndex != -1 && currentIndex < queueList.length - 1) {
      await playMediaItem(queueList[currentIndex + 1]);
    } else if (_isAutoPlayEnabled && currentItem != null && currentItem.extras?['isLocal'] != true) {
      await _autoPlayNext(currentItem.id);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final queueList = queue.value;
    if (queueList.isEmpty) return;
    
    final currentItem = mediaItem.value;
    final currentIndex = queueList.indexWhere((item) => item.id == currentItem?.id);
    
    if (currentIndex > 0) {
      await playMediaItem(queueList[currentIndex - 1]);
    }
  }

  Future<void> _autoPlayNext(String videoId) async {
    try {
      final video = await _yt.videos.get(videoId);
      final relatedList = await _yt.videos.getRelatedVideos(video);
if (relatedList == null || relatedList.isEmpty) return;
final related = relatedList.first;
      
      final nextItem = MediaItem(
        id: related.id.value,
        title: related.title,
        artist: related.author,
        duration: related.duration,
        artUri: Uri.parse(related.thumbnails.highResUrl),
      );
      
      final currentQueue = queue.value.toList();
      currentQueue.add(nextItem);
      queue.add(currentQueue);
      
      await playMediaItem(nextItem);
    } catch (e) {
      print("Error en AutoPlay: \$e");
    }
  }
}

// --- Funciones Globales para acceder desde la UI ---
Future<void> globalPlay(MediaItem item) async {
  await audioHandler.updateQueue([item]);
  await audioHandler.playMediaItem(item);
}

Future<void> globalPlayQueue(List<MediaItem> items, int startIndex) async {
  await audioHandler.updateQueue(items);
  await audioHandler.playMediaItem(items[startIndex]);
}
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _tokenController = TextEditingController();
  bool _error = false;
  bool _accesoPermitido = false;

  void _validarToken() {
    // Si necesitas validación real, cámbialo aquí.
    if (_tokenController.text.trim().isNotEmpty) {
      setState(() {
        _accesoPermitido = true;
        _error = false;
      });
    } else {
      setState(() {
        _error = true;
      });
    }
  }

  Future<void> downloadAudio(BuildContext context, dynamic item) async {
    final messenger = ScaffoldMessenger.of(context);
    YoutubeExplode? yt;
    
    bool isDialogShowing = false;
    void closeDialog() {
      if (isDialogShowing && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        isDialogShowing = false;
      }
    }

    try {
      isDialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF4ADE80)),
        ),
      );

      var status = await Permission.storage.request();
      if (!status.isGranted) {
        closeDialog();
        messenger.showSnackBar(const SnackBar(content: Text('Permiso de almacenamiento denegado')));
        return;
      }

      yt = YoutubeExplode();
      final manifest = await yt.videos.streamsClient.getManifest(item['id']);
      final audioStreamInfo = manifest.audioOnly.withHighestBitrate();

      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        closeDialog();
        messenger.showSnackBar(const SnackBar(content: Text('No se pudo acceder al almacenamiento')));
        return;
      }

      final String safeTitle = (item['title'] as String).replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
      final String fileName = '\$safeTitle.mp3';
      final String savePath = '\${directory.path}/\$fileName';

      closeDialog(); // Cerramos el loader antes de mostrar el mensaje de inicio

      messenger.showSnackBar(SnackBar(content: Text('Iniciando descarga: \$safeTitle...')));

      final taskId = await FlutterDownloader.enqueue(
        url: audioStreamInfo.url.toString(),
        savedDir: directory.path,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: false,
      );

      if (taskId != null) {
        final box = Hive.box('downloads');
        final downloadData = {
          'id': item['id'],
          'title': item['title'],
          'artist': item['artist'] ?? 'Desconocido',
          'artUri': item['artUri'] ?? '',
          'duration': item['duration'] ?? 0,
          'localPath': savePath,
        };
        await box.put(item['id'], downloadData);
        messenger.showSnackBar(const SnackBar(content: Text('¡Descarga finalizada! Agregada a tu Bóveda.')));
      }
    } catch (e) {
      closeDialog();
      print("Error en descarga: \$e");
      messenger.showSnackBar(SnackBar(content: Text('Error en la descarga: \$e')));
    } finally {
      yt?.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_accesoPermitido) {
      return Scaffold(
        backgroundColor: const Color(0xFF111111),
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Color(0xFF4ADE80)),
              const SizedBox(height: 24),
              const Text(
                'ACCESO RESTRINGIDO',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 2.0),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ingresa tu token de seguridad para continuar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _tokenController,
                style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 18, letterSpacing: 3.0),
                decoration: InputDecoration(
                  hintText: 'Pega tu TKN aquí...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  errorText: _error ? 'Token inválido o sin permisos' : null,
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4ADE80))),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4ADE80),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _validarToken,
                child: const Text(
                  'VALIDAR ACCESO', 
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spotify Killer VIP', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.offline_pin, color: Color(0xFF4ADE80)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => OfflineVaultScreen(audioHandler: audioHandler)),
              );
            },
            tooltip: 'Bóveda Offline',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, size: 100, color: Colors.cyanAccent),
            const SizedBox(height: 20),
            const Text(
              '¡Bienvenido al sistema principal!',
              style: TextStyle(fontSize: 24, color: Colors.white),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                // Ejemplo de prueba: Reproducir una canción global
                final testItem = MediaItem(
                  id: 'dQw4w9WgXcQ',
                  title: 'Prueba de Conexión',
                  artist: 'Sistema',
                  artUri: Uri.parse('https://img.youtube.com/vi/dQw4w9WgXcQ/0.jpg'),
                  duration: const Duration(minutes: 3, seconds: 32),
                );
                globalPlay(testItem);
              },
              icon: const Icon(Icons.play_arrow, color: Colors.black),
              label: const Text('Reproducir Audio de Prueba', style: TextStyle(color: Colors.black)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            ),
          ],
        ),
      ),
    );
  }
}