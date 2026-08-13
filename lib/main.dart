import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MediaApp());
}

class MediaApp extends StatefulWidget {
  const MediaApp({super.key});

  @override
  State<MediaApp> createState() => _MediaAppState();
}

class _MediaAppState extends State<MediaApp> {
  Color _primaryColor = Colors.purpleAccent;

  @override
  void initState() {
    super.initState();
    _loadSavedColor();
    _configureAudioSession();
  }

  // Configuración clave para que no se detenga en background
  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  Future<void> _loadSavedColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('theme_color');
    if (colorValue != null) setState(() => _primaryColor = Color(colorValue));
  }

  Future<void> _changeThemeColor(Color color) async {
    setState(() => _primaryColor = color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_color', color.value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(primaryColor: _primaryColor, colorScheme: ColorScheme.dark(primary: _primaryColor)),
      home: MainScreen(primaryColor: _primaryColor, onChangeColor: _changeThemeColor),
    );
  }
}

class MainScreen extends StatefulWidget {
  final Color primaryColor;
  final Function(Color) onChangeColor;
  const MainScreen({super.key, required this.primaryColor, required this.onChangeColor});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  VideoPlayerController? _videoController;
  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _downloadedTracks = [];
  List<dynamic> _currentPlaylist = [];
  int _currentTrackIndex = -1;
  Map<String, dynamic>? _currentTrack;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _audioOnlyMode = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _position = Duration.zero;
            _playNextTrack();
          }
        });
      }
    });
    _audioPlayer.positionStream.listen((pos) => setState(() => _position = pos));
    _audioPlayer.durationStream.listen((dur) => setState(() => _duration = dur ?? Duration.zero));
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favorites = List<Map<String, dynamic>>.from(json.decode(prefs.getString('saved_favorites') ?? '[]'));
      _downloadedTracks = List<Map<String, dynamic>>.from(json.decode(prefs.getString('saved_downloads') ?? '[]'));
    });
  }

  Future<void> _saveLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_favorites', json.encode(_favorites));
    await prefs.setString('saved_downloads', json.encode(_downloadedTracks));
  }

  Future<void> _playTrack(Map<String, dynamic> track, {List<dynamic>? playlist, int? index}) async {
    if (playlist != null) _currentPlaylist = playlist;
    if (index != null) _currentTrackIndex = index;
    final mediaUrl = track['localPath'] ?? track['previewUrl'] ?? '';
    if (mediaUrl.isEmpty) return;

    try {
      if (_currentTrack?['previewUrl'] == track['previewUrl'] && _currentTrack?['localPath'] == track['localPath']) {
        if (_isPlaying) { await _audioPlayer.pause(); _videoController?.pause(); } 
        else { await _audioPlayer.play(); _videoController?.play(); }
      } else {
        setState(() => _currentTrack = track);
        await _videoController?.dispose();
        _videoController = null;
        if (track['localPath'] != null) await _audioPlayer.setFilePath(track['localPath']);
        else await _audioPlayer.setUrl(mediaUrl);
        await _audioPlayer.play();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al reproducir')));
    }
  }

  void _playNextTrack() {
    if (_currentPlaylist.isNotEmpty && _currentTrackIndex < _currentPlaylist.length - 1) {
      _currentTrackIndex++;
      _playTrack(_currentPlaylist[_currentTrackIndex], index: _currentTrackIndex);
    }
  }

  Future<void> _downloadTrack(Map<String, dynamic> track) async {
    // Pedir permiso primero
    var status = await Permission.storage.request();
    if (status.isGranted || await Permission.manageExternalStorage.request().isGranted) {
      try {
        final dir = Directory('/storage/emulated/0/Download');
        final filePath = '${dir.path}/${track['trackId'] ?? DateTime.now().millisecondsSinceEpoch}.m4a';
        await Dio().download(track['previewUrl'], filePath);
        setState(() {
          track['localPath'] = filePath;
          _downloadedTracks.add(track);
        });
        await _saveLocalData();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Descargado en carpeta pública! 📥')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de acceso al archivo')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permiso denegado')));
    }
  }
  

