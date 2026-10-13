
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../home/home_page.dart';
import 'login_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.api,
  });

  final ApiClient api;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthStorage _storage = AuthStorage();

  bool _loading = true;
  bool _authenticated = false;

  String? _sessionError;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  // Memeriksa token dan mengambil data pengguna.
  Future<void> _checkSession() async {
    setState(() {
      _loading = true;
      _sessionError = null;
    });

    try {
      final token = await _storage.getToken();

      if (token == null || token.isEmpty) {
        widget.api.setAuthToken(null);
        _authenticated = false;
        _user = null;
      } else {
        widget.api.setAuthToken(token);

        // Validasi token sekaligus mengambil profil pengguna.
        _user = await widget.api.me();
        _authenticated = true;
      }
    } on ApiException catch (e) {
      if (e.status == 401) {
        await _storage.clearToken();
        widget.api.setAuthToken(null);

        _authenticated = false;
        _user = null;
      } else {
        _sessionError = e.message;
      }
    } catch (_) {
      _sessionError = 'Gagal memeriksa sesi. Silakan coba lagi.';
    }

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  // Dipanggil ketika login berhasil.
  void _onLogin(Map<String, dynamic> user) {
    setState(() {
      _user = user;
      _authenticated = true;
      _sessionError = null;
    });
  }

  // Logout dari aplikasi.
  Future<void> logout() async {
    try {
      await widget.api.logout();
    } catch (_) {
      // Tetap hapus sesi lokal jika server tidak tersedia.
    }

    await _storage.clearToken();
    widget.api.setAuthToken(null);

    if (!mounted) return;

    setState(() {
      _authenticated = false;
      _user = null;
      _sessionError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_sessionError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 56,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tidak dapat memeriksa sesi',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _sessionError!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _checkSession,
                  child: const Text('Coba Lagi'),
                ),
                TextButton(
                  onPressed: () async {
                    await _storage.clearToken();
                    widget.api.setAuthToken(null);

                    if (!mounted) return;

                    setState(() {
                      _authenticated = false;
                      _user = null;
                      _sessionError = null;
                    });
                  },
                  child: const Text('Kembali ke Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_authenticated) {
      return HomePage(
        api: widget.api,
        user: _user ?? {},
        onLogout: logout,
      );
    }

    return LoginPage(
      api: widget.api,
      storage: _storage,
      onLogin: _onLogin,
    );
  }
}
