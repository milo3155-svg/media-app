import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../main.dart';

class TokenGateScreen extends StatefulWidget {
  const TokenGateScreen({super.key});

  @override
  State<TokenGateScreen> createState() => _TokenGateScreenState();
}

class _TokenGateScreenState extends State<TokenGateScreen> {
  final TextEditingController _controller = TextEditingController();
  final Box _authBox = Hive.box('auth');
  String? _savedToken;
  String? _errorText;
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _savedToken = _authBox.get('token')?.toString();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _normalizeToken(String raw) {
    return raw.trim().toUpperCase().replaceFirst('TKN-', '').trim();
  }

  bool _isExpired(Map<String, dynamic> data) {
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
      final doc = await FirebaseFirestore.instance.collection('tokens').doc(token).get();
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

      await _authBox.put('token', token);
      if (!mounted) return;
      setState(() => _savedToken = token);
    } catch (_) {
      setState(() => _errorText = 'Error de conexión. Verifica tu internet.');
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  Future<void> _logoutToken(String reason) async {
    await audioHandler.stop();
    await _authBox.delete('token');
    if (!mounted) return;
    setState(() {
      _savedToken = null;
      _errorText = reason;
    });
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

        return StreamBuilder<DocumentSnapshot>>(
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

            return const MainNavigationScreen();
          },
        );
      },
    );
  }
}
