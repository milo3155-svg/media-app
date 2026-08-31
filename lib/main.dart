import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(const MediaApp());
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Youtube Streamer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController searchController = TextEditingController();
  final YoutubeExplode yt = YoutubeExplode();
  final AudioPlayer audioPlayer = AudioPlayer();

  List<Video> videos = [];
  bool isLoading = false;
  String? playingVideoId;

  Future<void> searchVideos(String query) async {
    if (query.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final results = await yt.search.getVideos(query);
      if (!mounted) return;
      setState(() {
        videos = results.take(15).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al buscar: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> playAudio(Video video) async {
    try {
      setState(() => playingVideoId = video.id.value);

      var manifest = await yt.videos.streamsClient.getManifest(video.id);
      var streamInfo = manifest.audioOnly.withHighestBitrate();

      await audioPlayer.stop();
      
      // MAGIA NEGRA: Engañamos a YouTube pasándole un User-Agent falso de PC
      await audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(streamInfo.url.toString()),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': '*/*',
          },
        ),
      );
      
      audioPlayer.play();
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fallo: ${e.toString()}')),
      );
      setState(() => playingVideoId = null);
    }
  }

  @override
  void dispose() {
    yt.close();
    audioPlayer.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Youtube Direct Streamer'),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Buscar video o música...',
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.deepPurpleAccent),
                  onPressed: () => searchVideos(searchController.text),
                ),
              ),
              onSubmitted: searchVideos,
            ),
          ),
          if (isLoading)
            const LinearProgressIndicator(color: Colors.deepPurpleAccent),
          Expanded(
            child: ListView.builder(
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                final isPlaying = playingVideoId == video.id.value;

                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      video.thumbnails.mediumResUrl,
                      width: 60,
                      height: 45,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(
                    video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isPlaying ? Colors.deepPurpleAccent : Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    video.author,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      color: Colors.deepPurpleAccent,
                      size: 32,
                    ),
                    onPressed: () => playAudio(video),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
