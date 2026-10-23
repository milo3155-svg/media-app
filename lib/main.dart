import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math' as math;
import 'dart:async'; 

// 1. IMPORTAMOS NUESTRO MOTOR AISLADO Y BLINDADO
import 'services/audio_handler.dart';

late MyAudioHandler audioHandler;
final ValueNotifier<bool> isHDMode = ValueNotifier<bool>(true);
final ValueNotifier<Color> appColor = ValueNotifier<Color>(Colors.cyanAccent); 

String formatGlobalDuration(Duration? d) {
  if (d == null || d == Duration.zero) return "";
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return "${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds";
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('favorites'); 
  await Hive.openBox('history'); 
  await Hive.openBox('search_history'); 
  await Hive.openBox('playlists'); 
  
  final session = await AudioSession.instance; 
  await session.configure(const AudioSessionConfiguration.music());
  
  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(), 
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.media_app.audio_master_v62', 
      androidNotificationChannelName: 'Spotify Killer VIP', 
      androidNotificationOngoing: false, 
      androidShowNotificationBadge: true, 
      androidStopForegroundOnPause: false, 
      androidNotificationIcon: 'drawable/ic_notification' 
    )
  ) as MyAudioHandler; // Casteo estricto a nuestro motor personalizado
  
  runApp(const MediaApp());
}

class ConspiracyLogo extends StatelessWidget {
  final double size; final Color color; const ConspiracyLogo({super.key, this.size = 150.0, required this.color});
  @override Widget build(BuildContext context) { return SizedBox(width: size, height: size, child: CustomPaint(painter: _OsirisEyePainter(color: color))); }
}

class _OsirisEyePainter extends CustomPainter {
  final Color color; _OsirisEyePainter({required this.color});
  void _drawTextOnLine(Canvas canvas, String text, Offset start, Offset end, double fontSize) {
    final midPoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2); final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    canvas.save(); canvas.translate(midPoint.dx, midPoint.dy); canvas.rotate(angle);
    final textSpan = TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'Courier'));
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr); textPainter.layout(); textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height - 2)); canvas.restore();
  }
  @override void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = w * 0.05..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round;
    final p1 = Offset(w * 0.15, h * 0.15); final p2 = Offset(w * 0.15, h * 0.85); final p3 = Offset(w * 0.90, h * 0.50); 
    final playPath = Path()..moveTo(p1.dx, p1.dy)..lineTo(p2.dx, p2.dy)..lineTo(p3.dx, p3.dy)..close(); canvas.drawPath(playPath, paint);
    final fontSize = w * 0.08; _drawTextOnLine(canvas, "Θ ⅃ Θ", p1, p2, fontSize); _drawTextOnLine(canvas, "Δ Ξ", p2, p3, fontSize); _drawTextOnLine(canvas, "Θ Ϟ Ι ℟ Ι Ϟ", p3, p1, fontSize);
    final eyeLeft = w * 0.28; final eyeRight = w * 0.62; final eyeY = h * 0.50; final eyeCenterX = w * 0.45;
    final eyePath = Path()..moveTo(eyeLeft, eyeY)..quadraticBezierTo(eyeCenterX, h * 0.32, eyeRight, eyeY)..quadraticBezierTo(eyeCenterX, h * 0.68, eyeLeft, eyeY); canvas.drawPath(eyePath, paint);
    final wavePaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = w * 0.03; canvas.drawCircle(Offset(eyeCenterX, h * 0.50), w * 0.08, wavePaint); canvas.drawCircle(Offset(eyeCenterX, h * 0.50), w * 0.03, wavePaint); canvas.drawLine(Offset(eyeCenterX - w * 0.12, h * 0.50), Offset(eyeCenterX + w * 0.12, h * 0.50), wavePaint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

void globalShowOptions(BuildContext context, Video video, Color color) {
  final newItem = MediaItem(
    id: video.id.value,
    title: video.title,
    artist: video.author,
    duration: video.duration,
    artUri: Uri.parse(video.thumbnails.highResUrl),
  );

  showModalBottomSheet(
    context: context, backgroundColor: const Color(0xFF1A1A1A), isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), 
    builder: (context) { 
      final inQueue = audioHandler.queue.value.any((i) => i.id == video.id.value);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10), 
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            ListTile(
              leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(video.thumbnails.lowResUrl, width: 40, height: 40, fit: BoxFit.cover)), 
              title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)), 
              subtitle: Text("${video.author} •${formatGlobalDuration(video.duration)}", style: const TextStyle(color: Colors.grey))
            ), 
            const Divider(color: Colors.white24),
