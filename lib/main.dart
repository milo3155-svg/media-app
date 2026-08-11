import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => VaultProvider()),
        ChangeNotifierProvider(create: (_) => YMusicPlayerProvider()),
      ],
      child: const MediaApp(),
    ),
  );
}

class MediaItemModel {
  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;
  final String? directStreamUrl;

  MediaItemModel({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    this.directStreamUrl,
  });
}

class YMusicPlayerProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  WebViewController? _webViewController;
  MediaItemModel? _currentItem;

  MediaItemModel? get currentItem => _currentItem;
  WebViewController? get webViewController => _webViewController;

  YMusicPlayerProvider() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 10; Pixel 10 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36');
  }

  Future<void> playItem(MediaItemModel item) async {
    _currentItem = item;
    
    // Si es radio, usamos el motor nativo
    if (item.directStreamUrl != null) {
      _webViewController?.loadRequest(Uri.parse('about:blank'));
      await _audioPlayer.play(UrlSource(item.directStreamUrl!));
    } 
    // Si es YouTube, usamos el motor web persistente
    else {
      await _audioPlayer.stop();
      final String url = 'https://www.youtube.com/embed/${item.id}?autoplay=1';
      _webViewController?.loadRequest(Uri.parse(url));
    }
    notifyListeners();
  }

  void stop() async {
    await _audioPlayer.stop();
    _webViewController?.loadRequest(Uri.parse('about:blank'));
    _currentItem = null;
    notifyListeners();
  }
}

// ... (El resto de las clases: VaultProvider, ThemeProvider, MediaApp, UI)
// ¡OJO! En la UI, asegúrate de llamar a playerProvider.webViewController dentro de la pantalla del reproductor.
