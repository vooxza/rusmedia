
import 'package:flutter/material.dart';

import '../../core/api_client.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.api,
    required this.user,
    required this.onLogout,
  });

  final ApiClient api;
  final Map<String, dynamic> user;
  final Future<void> Function() onLogout;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<HealthStatus> _health;

  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _health = widget.api.health();
  }

  void _retry() {
    setState(() {
      _health = widget.api.health();
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text(
            'Apakah kamu yakin ingin keluar dari akun ini?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _loggingOut = true;
    });

    await widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // Mengambil data pengguna dari API.
    final name = widget.user['name']?.toString() ?? 'Pengguna';
    final email = widget.user['email']?.toString() ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'RUSMEDIA',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loggingOut ? null : _logout,
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Selamat Datang!',
                    style: text.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Semua momen sekolah, tersimpan dalam satu tempat.',
                    style: text.bodyLarge?.copyWith(
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Kartu profil pengguna.
                  Card(
                    elevation: 1,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 28,
                            backgroundColor: Color(0xFFEFF6FF),
                            child: Icon(
                              Icons.person_rounded,
                              size: 32,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: text.bodyMedium?.copyWith(
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    'Status Layanan',
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Status koneksi backend.
                  Card(
                    elevation: 1,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: FutureBuilder<HealthStatus>(
                        future: _health,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            return Column(
                              children: [
                                const Icon(
                                  Icons.cloud_off_rounded,
                                  size: 36,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  snapshot.error.toString(),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: _retry,
                                  child: const Text('Coba Lagi'),
                                ),
                              ],
                            );
                          }

                          final health = snapshot.requireData;

                          return Column(
                            children: [
                              _ServiceStatus(
                                title: 'Backend Server',
                                isActive: health.ok,
                              ),
                              const Divider(height: 24),
                              _ServiceStatus(
                                title: 'Database',
                                isActive: health.database,
                              ),
                              const Divider(height: 24),
                              _ServiceStatus(
                                title: 'Storage',
                                isActive: health.storage,
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: _retry,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Periksa Ulang'),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tombol logout.
                  OutlinedButton.icon(
                    onPressed: _loggingOut ? null : _logout,
                    icon: _loggingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.logout_rounded),
                    label: Text(
                      _loggingOut ? 'Sedang Logout...' : 'Logout',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceStatus extends StatelessWidget {
  const _ServiceStatus({
    required this.title,
    required this.isActive,
  });

  final String title;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isActive ? Icons.check_circle : Icons.cancel,
          color: isActive ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          isActive ? 'Aktif' : 'Bermasalah',
          style: TextStyle(
            color: isActive ? Colors.green : Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
