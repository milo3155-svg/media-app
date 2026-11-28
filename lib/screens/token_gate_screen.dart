import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:android_id/android_id.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';

final ValueNotifier<bool> canDownloadNotifier = ValueNotifier<bool>(false);
final ValueNotifier<String?> activeTokenNotifier = ValueNotifier<String?>(null);
final ValueNotifier<String> supportWhatsappNotifier = ValueNotifier<String>('525610338036');

Future<void> openSupportWhatsApp(String message) async {
  final phone = supportWhatsappNotifier.value.replaceAll(RegExp(r'[^0-9]'), '');
  final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class TokenGateScreen extends StatefulWidget {
  const TokenGateScreen({super.key});

  @override
  State<TokenGateScreen> createState() => _TokenGateScreenState();
}

class _TokenGateScreenState extends State<TokenGateScreen> {
  final TextEditingController _controller = TextEditingController();
  final Box _authBox = Hive.box('auth');
  StreamSubscription? _tokenSub;
  String? _savedToken;
  String? _deviceId;
  String? _errorText;
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _initGate();
  }

  Future<void> _initGate() async {
    _loadWhatsAppConfig();
    try {
      _deviceId = await const AndroidId().getId();
    } catch (_) {
      _deviceId = null;
    }

    final stored = _authBox.get('token')?.toString();
    if (!mounted) return;
    setState(() => _savedToken = stored);
    activeTokenNotifier.value = stored;

    if (_savedToken != null && _savedToken!.isNotEmpty) {
      _listenToToken(_savedToken!);
    }
  }

  Future<void> _loadWhatsAppConfig() async {
    try {
      final cfg = await FirebaseFirestore.instance.collection('config').doc('app').get();
      final remotePhone = cfg.data()?['whatsapp']?.toString().trim();
      if (remotePhone != null && remotePhone.isNotEmpty) {
        supportWhatsappNotifier.value = remotePhone;
      }
    } catch (_) {}
  }

  void _listenToToken(String token) {
    _tokenSub?.cancel();
    _tokenSub = FirebaseFirestore.instance
        .collection('tokens')
        .doc(token)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) {
        _tokenSub?.cancel();
        _logoutToken('Acceso revocado desde la Mesa de Control.');
        return;
      }
      final data = doc.data() ?? {};
      if (data['musica'] != true) {
        _tokenSub?.cancel();
        _logoutToken('Permiso de Música desactivado.');
        return;
      }
      if (_isExpired(data)) {
        _tokenSub?.cancel();
        _logoutToken('Tu suscripción ha expirado.');
        return;
      }
      final boundDevice = data['deviceId']?.toString().trim() ?? '';
      if (boundDevice.isNotEmpty && _deviceId != null && boundDevice != _deviceId) {
        _tokenSub?.cancel();
        _logoutToken('Este token está vinculado a otro dispositivo.');
        return;
      }
      canDownloadNotifier.value = data['descargas'] == true;
    });
  }

  @override
  void dispose() {
    _tokenSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _normalizeToken(String raw) {
    return raw.trim().toUpperCase().replaceFirst('TKN-', '').trim();
  }

  bool _isExpired(Map<String, dynamic> data) {
    final expiraTs = data['expira'];
    if (expiraTs is Timestamp) {
      return DateTime.now().isAfter(expiraTs.toDate());
    }
    final creado = data['creado'];
    final dias = data['dias'];
    if (creado is Timestamp && dias is int && dias > 0) {
      final expira = creado.toDate().add(Duration(days: dias));
      return DateTime.now().isAfter(expira);
    }
    return false;
  }

  Future<void> _activateToken() async {
    final token = _normalizeToken(_controller.text);
    if (token.isEmpty) {
      setState(() => _errorText = 'Ingresa tu token de acceso.');
      return;
    }

    setState(() {
      _isValidating = true;
      _errorText = null;
    });

    try {
      _deviceId ??= await const AndroidId().getId();
      final docRef = FirebaseFirestore.instance.collection('tokens').doc(token);
      final doc = await docRef.get();

      if (!doc.exists) {
        setState(() => _errorText = 'Token inválido o eliminado.');
        return;
      }

      final data = doc.data() ?? {};
      if (data['musica'] != true) {
        setState(() => _errorText = 'Este token no tiene permiso para Música.');
        return;
      }

      if (_isExpired(data)) {
        setState(() => _errorText = 'Tu acceso ha expirado.');
        return;
      }

      final boundDevice = data['deviceId']?.toString().trim() ?? '';
      if (boundDevice.isNotEmpty && _deviceId != null && boundDevice != _deviceId) {
        setState(() => _errorText = 'Este token ya está activo en otro dispositivo.');
        return;
      }

      if (boundDevice.isEmpty && _deviceId != null && _deviceId!.isNotEmpty) {
        await docRef.update({'deviceId': _deviceId});
      }

      canDownloadNotifier.value = data['descargas'] == true;
      activeTokenNotifier.value = token;
      await _authBox.put('token', token);
      if (!mounted) return;
      setState(() => _savedToken = token);
      _listenToToken(token);
    } catch (_) {
      setState(() => _errorText = 'Error de conexión. Verifica tu internet.');
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  Future<void> _logoutToken(String reason) async {
    await audioHandler.stop();
    await _authBox.delete('token');
    canDownloadNotifier.value = false;
    activeTokenNotifier.value = null;
    if (!mounted) return;
    setState(() {
      _savedToken = null;
      _errorText = reason;
    });
  }

  void _showReferralDialog(Color color) {
    final refController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Me recomendó un amigo', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: refController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Token o nombre de tu amigo',
            hintStyle: const TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: color)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: color)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final ref = refController.text.trim();
              Navigator.pop(ctx);
              final msg = ref.isEmpty
                  ? 'Hola, vengo recomendado por un amigo y quiero solicitar acceso a la app de Música.'
                  : 'Hola, vengo recomendado por ($ref) y quiero solicitar acceso a la app de Música.';
              openSupportWhatsApp(msg);
            },
            child: Text('Ir a WhatsApp', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginScreen(Color color) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConspiracyLogo(size: 90, color: color),
                const SizedBox(height: 20),
                const Text(
                  'ACCESO RESTRINGIDO',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ingresa tu token (ej. 9414 o TKN-9414)',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2),
                  decoration: InputDecoration(
                    hintText: 'TKN-XXXX',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: color),
                    ),
                  ),
                  onSubmitted: (_) => _activateToken(),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorText!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isValidating ? null : _activateToken,
                    child: _isValidating
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                        : const Text('ACTIVAR ACCESO', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.chat, size: 18, color: Colors.greenAccent),
                    label: const Text('Solicitar acceso por WhatsApp'),
                    onPressed: () => openSupportWhatsApp('Hola, quiero solicitar un token de acceso para la app de Música.'),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  icon: Icon(Icons.card_giftcard, size: 18, color: color),
                  label: Text('Me recomendó un amigo', style: TextStyle(color: color)),
                  onPressed: () => _showReferralDialog(color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: appColor,
      builder: (context, color, _) {
        if (_savedToken == null || _savedToken!.isEmpty) {
          return _buildLoginScreen(color);
        }

        return StreamBuilder(
          stream: FirebaseFirestore.instance.collection('tokens').doc(_savedToken).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return Scaffold(
                backgroundColor: const Color(0xFF0D0D0D),
                body: Center(child: CircularProgressIndicator(color: color)),
              );
            }

            if (snapshot.hasError) {
              return _buildLoginScreen(color);
            }

            final doc = snapshot.data;
            if (doc == null || !doc.exists) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _logoutToken('Acceso revocado desde la Mesa de Control.');
              });
              return _buildLoginScreen(color);
            }

            final data = doc.data() ?? {};
            if (data['musica'] != true) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _logoutToken('Permiso de Música desactivado.');
              });
              return _buildLoginScreen(color);
            }

            if (_isExpired(data)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _logoutToken('Tu suscripción ha expirado.');
              });
              return _buildLoginScreen(color);
            }

            final boundDevice = data['deviceId']?.toString().trim() ?? '';
            if (boundDevice.isNotEmpty && _deviceId != null && boundDevice != _deviceId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _logoutToken('Este token está vinculado a otro dispositivo.');
              });
              return _buildLoginScreen(color);
            }

            canDownloadNotifier.value = data['descargas'] == true;
            return const MainNavigationScreen();
          },
        );
      },
    );
  }
}
