// ============================================================================
// BLOQUE 1: SERVICIO DE DESCARGAS Y BÓVEDA OFFLINE (download_service.dart)
// ============================================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> downloadAudio(BuildContext context, Video video, Color color) async {
  
  // --- SECCIÓN A: VALIDACIÓN DE PROTOCOLO PLUS ---
  final cerrojoBox = Hive.box('cerrojo_box');
  final isPlusUser = cerrojoBox.get('is_plus_user', defaultValue: false);

  if (!isPlusUser) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔒 Acceso Restringido: Requiere Protocolo Plus'),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 3),
      ),
    );
    return; // Corta la ejecución aquí, no descarga nada.
  }

  // --- SECCIÓN B: PERMISOS DEL SISTEMA ---
  if (Platform.isAndroid) {
    final audioStatus = await Permission.audio.request();
    if (!audioStatus.isGranted) {
      final storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se requieren permisos para la Bóveda')),
        );
        return;
      }
    }
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Iniciando intercepción: ${video.title}'), backgroundColor: color),
  );

  // --- SECCIÓN C: EXTRACCIÓN Y ESCRITURA EN DISCO ---
  try {
    final yt = YoutubeExplode();
    final manifest = await yt.videos.streamsClient.getManifest(video.id);
    final streamInfo = manifest.audioOnly.withHighestBitrate();

    final directory = await getApplicationDocumentsDirectory();
    // Limpieza del título para evitar caracteres que rompan el archivo
    final safeTitle = video.title.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
    final filePath = '${directory.path}/$safeTitle.m4a';
    final file = File(filePath);

    if (file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El archivo ya existe en la Cripta')),
      );
      yt.close();
      return;
    }

    final stream = yt.videos.streamsClient.get(streamInfo);
    final fileStream = file.openWrite();
    await stream.pipe(fileStream);
    await fileStream.flush();
    await fileStream.close();
    yt.close();

    // --- SECCIÓN D: REGISTRO EN HIVE ---
    final downloadsBox = Hive.box('downloads');
    downloadsBox.put(video.id.value, {
      'id': video.id.value,
      'title': video.title,
      'artist': video.author,
      'localPath': filePath,
      'artUri': video.thumbnails.highResUrl,
      'duration': video.duration?.inMilliseconds ?? 0,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Archivo encriptado: $safeTitle'), backgroundColor: Colors.green),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ Error de intercepción: $e'), backgroundColor: Colors.red),
    );
  }
}
// ============================================================================
// FIN DEL BLOQUE 1
// ============================================================================