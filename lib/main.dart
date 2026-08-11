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

// ==========================================
// GESTOR DE REPRODUCCIÓN DUAL (RADIO + YT)
// ==========================================
class YMusicPlayerProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  WebViewController? _webViewController;
  MediaItemModel? _currentItem;
  bool _isLoading = false;

  MediaItemModel? get currentItem => _currentItem;
  WebViewController? get webViewController => _webViewController;
  bool get isLoading => _isLoading;

  YMusicPlayerProvider() {
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 10; Pixel 10 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36');
  }

  Future<void> playItem(MediaItemModel item) async {
    _currentItem = item;
    _isLoading = true;
    notifyListeners();

    // 1. Si es radio (stream directo), usamos el motor nativo Audioplayers
    if (item.directStreamUrl != null) {
      _webViewController?.loadRequest(Uri.parse('about:blank')); // Apaga el WebView
      await _audioPlayer.play(UrlSource(item.directStreamUrl!));
    } 
    // 2. Si es YouTube, usamos el WebView oculto
    else {
      await _audioPlayer.stop(); // Apaga la radio
      final String targetUrl = 'https://www.youtube.com/embed/${item.id}?autoplay=1&playsinline=1&controls=1&modestbranding=1&rel=0';
      _webViewController?.loadRequest(Uri.parse(targetUrl));
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> closePlayer() async {
    await _audioPlayer.stop();
    _webViewController?.loadRequest(Uri.parse('about:blank'));
    _currentItem = null;
    notifyListeners();
  }
}

// ... (El resto de las clases: MediaItemModel, VaultProvider, ThemeProvider, MediaApp, UI...)
// NOTA: Para no hacer el código gigante, mantén las clases que ya tenías abajo (MainNavigationScreen, Tabs, etc.)
// PERO asegúrate de cambiar las URLs de las radios en la clase SportsTab:
// W Radio: 'https://stream.wradio.com.mx/wradio.mp3'
// Formula: 'https://stream.radioformula.com.mx/formula.mp3'
