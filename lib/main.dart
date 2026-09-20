import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() => runApp(const SandboxApp());

class SandboxApp extends StatelessWidget {
  const SandboxApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LaboratorioScreen(),
    );
  }
}

class LaboratorioScreen extends StatefulWidget {
  const LaboratorioScreen({super.key});
  @override
  State<LaboratorioScreen> createState() => _LaboratorioScreenState();
}

class _LaboratorioScreenState extends State<LaboratorioScreen> {
  String log = "Sistema listo. Esperando inicio de prueba...";
  bool isDownloading = false;

  void _escribirLog(String mensaje) {
    setState(() {
      log = "$log\n$mensaje";
    });
  }

  Future<void> iniciarPruebaClinica() async {
    setState(() {
      log = "--- INICIANDO PRUEBA DE DESCARGA ---";
      isDownloading = true;
    });

    try {
      final yt = YoutubeExplode();
      
      _escribirLog("1. Conectando a servidores de YouTube...");
      // Video de prueba ultra corto (18 segundos)
      var manifest = await yt.videos.streamsClient.getManifest('jNQXAC9IVRw'); 
      var streamInfo = manifest.audioOnly.withHighestBitrate();
      
      _escribirLog("2. Pidiendo permiso al almacenamiento del Pixel...");
      final directory = await getApplicationDocumentsDirectory();
      final savePath = '${directory.path}/prueba_aislada.m4a';
      
      _escribirLog("3. Creando archivo vacío en: $savePath");
      final file = File(savePath);
      final fileStream = file.openWrite();
      
      _escribirLog("4. DESCARGANDO Y ESCRIBIENDO DATOS... (Espera)");
      final stream = yt.videos.streamsClient.get(streamInfo);
      await stream.pipe(fileStream);
      
      _escribirLog("5. Sellando y cerrando el archivo...");
      await fileStream.flush();
      await fileStream.close();
      yt.close();
      
      _escribirLog("✅ ÉXITO TOTAL: ¡El archivo se guardó físicamente!");
      
    } catch (e) {
      _escribirLog("❌ ERROR CRÍTICO DETECTADO:");
      _escribirLog(e.toString());
    } finally {
      setState(() {
        isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Laboratorio de Diagnóstico'),
        backgroundColor: Colors.red[900],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDownloading ? Colors.grey : Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              onPressed: isDownloading ? null : iniciarPruebaClinica,
              child: Text(isDownloading ? 'DESCARGANDO...' : 'EJECUTAR PRUEBA CRÍTICA', 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 20),
            const Text("Monitor del Sistema:", style: TextStyle(color: Colors.white70, fontSize: 18)),
            const Divider(color: Colors.white30),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  log, 
                  style: const TextStyle(
                    color: Colors.greenAccent, 
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}