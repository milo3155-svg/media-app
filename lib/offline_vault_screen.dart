import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

// Si tu audioHandler está en otro archivo o es global, impórtalo aquí.
// import 'main.dart'; // O el archivo donde resida temporalmente el audioHandler

class OfflineVaultScreen extends StatelessWidget {
  // Declaramos que esta pantalla necesita recibir el audioHandler
  final dynamic audioHandler; 

  // Modificamos el constructor para obligar a que se lo pasen
  const OfflineVaultScreen({Key? key, required this.audioHandler}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Bóveda Offline', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A1A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box('downloads').listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return const Center(
              child: Text(
                'Tu bóveda está vacía.\n¡Descarga música para escucharla sin conexión!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: box.length,
            itemBuilder: (context, index) {
              final key = box.keyAt(index);
              final item = box.get(key);

              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4.0),
                  child: item['artUri'] != null && item['artUri'].toString().isNotEmpty
                      ? Image.network(item['artUri'].toString(), width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 48, height: 48, color: Colors.grey[900], child: const Icon(Icons.music_note, color: Colors.grey)))
                      : Container(width: 48, height: 48, color: Colors.grey[900], child: const Icon(Icons.music_note, color: Colors.grey)),
                ),
                title: Text(item['title'] ?? 'Desconocido', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                subtitle: Text(item['artist'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  
                   IconButton(
  icon: const Icon(Icons.play_arrow, color: Colors.blueAccent),
  onPressed: () async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bóveda: Reproduciendo ${item['title']}...'))
    );

    try {
    await audioHandler.customAction('playLocal', {
        'localPath': item['localPath'],
        'id': item['id'],
        'title': item['title'],
        'artist': item['artist'] ?? 'Bóveda Offline',
        'artUri': item['artUri'] ?? '',
        'duration': item['duration'] ?? 0,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión local: $e'))
      );
    }
  },
),

                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () {
                        // Eliminar el archivo físico (opcional por ahora, solo borramos el registro)
                        try{
                           final file = File(item['localPath']);
                           if(file.existsSync()){
                               file.deleteSync();
                           }
                        }catch(e){
                           print("Error borrando archivo local: $e");
                        }
                        box.delete(key);
                     box.delete(key);
                }, // Cierra la función onPressed
              ), // Cierra el IconButton de eliminar
            ], // Cierra los children del Row
          ), // Cierra el Row
        ); // Cierra el ListTile (la tarjeta de la canción)
      }, // Cierra el itemBuilder de la lista
      ); // Cierra el ListView.builder
      }, // Cierra el builder del ValueListenableBuilder
    ), // Cierra el ValueListenableBuilder
    ); // Cierra el Scaffold
  } // Cierra el Widget build
} // Cierra la clase OfflineVaultScreen
  
