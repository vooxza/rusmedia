import 'package:flutter/material.dart';

import '../../core/api_client.dart';

const _ink = Color(0xFF17233D);
const _blue = Color(0xFF315CEB);
const _muted = Color(0xFF77839A);
const _line = Color(0xFFE8ECF3);
const _canvas = Color(0xFFF6F8FC);

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
  int _selected = 0;

  late Future<HealthStatus> _health;

  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _health = widget.api.health();
  }

  void _refreshHealth() {
    setState(() {
      _health = widget.api.health();
    });
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari RUSMEDIA?'),
        content: const Text(
          'Kamu perlu login kembali untuk mengakses dokumentasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (yes != true || !mounted) return;

    setState(() {
      _loggingOut = true;
    });

    try {
      await widget.onLogout();
    } finally {
      if (mounted) {
        setState(() {
          _loggingOut = false;
        });
      }
    }
  }

  void _notReady() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Integrasi pemilihan berkas dan multipart upload Flutter belum diaktifkan.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final pages = [
      _DashboardPage(
        user: widget.user,
        health: _health,
        onRefresh: _refreshHealth,
        onNavigate: (i) {
          setState(() {
            _selected = i;
          });
        },
      ),
      _FoldersPage(
        onOpen: () {
          _notReady();
        },
      ),
      const _SharedPage(),
      _UploadPage(
        onUpload: _notReady,
      ),
    ];

    final titles = [
      'Beranda',
      'File & Folder',
      'Dibagikan',
      'Unggah Dokumentasi',
    ];

    return Scaffold(
      backgroundColor: _canvas,
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              _SideNavigation(
                selected: _selected,
                onSelect: (i) {
                  setState(() {
                    _selected = i;
                  });
                },
                onLogout: _logout,
                loggingOut: _loggingOut,
              ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(
                    title: titles[_selected],
                    user: widget.user,
                    onLogout: _logout,
                    loggingOut: _loggingOut,
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 1440,
                        ),
                        child: pages[_selected],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _selected,
              onDestinationSelected: (i) {
                setState(() {
                  _selected = i;
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.grid_view_rounded),
                  label: 'Beranda',
                ),
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  label: 'Folder',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  label: 'Dibagikan',
                ),
                NavigationDestination(
                  icon: Icon(Icons.cloud_upload_outlined),
                  label: 'Unggah',
                ),
              ],
            ),
    );
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.selected,
    required this.onSelect,
    required this.onLogout,
    required this.loggingOut,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final bool loggingOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: _line,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.photo_library_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 11),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RUSMEDIA',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: _ink,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'School cloud storage',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 38),
          const Padding(
            padding: EdgeInsets.only(
              left: 12,
              bottom: 12,
            ),
            child: Text(
              'MENU UTAMA',
              style: TextStyle(
                color: _muted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          _NavItem(
            icon: Icons.grid_view_rounded,
            label: 'Beranda',
            selected: selected == 0,
            onTap: () => onSelect(0),
          ),
          _NavItem(
            icon: Icons.folder_outlined,
            label: 'File & Folder',
            selected: selected == 1,
            onTap: () => onSelect(1),
          ),
          _NavItem(
            icon: Icons.people_outline_rounded,
            label: 'Dibagikan',
            selected: selected == 2,
            onTap: () => onSelect(2),
          ),
          _NavItem(
            icon: Icons.cloud_upload_outlined,
            label: 'Unggah Dokumentasi',
            selected: selected == 3,
            onTap: () => onSelect(3),
          ),
          const Spacer(),
          const Divider(
            color: _line,
          ),
          _NavItem(
            icon:
                loggingOut ? Icons.hourglass_top_rounded : Icons.logout_rounded,
            label: loggingOut ? 'Keluar...' : 'Keluar',
            selected: false,
            onTap: loggingOut ? () {} : onLogout,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
        selected: selected,
        selectedTileColor: const Color(0xFFEDF2FF),
        leading: Icon(
          icon,
          size: 20,
          color: selected ? _blue : _muted,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? _blue : _ink,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.user,
    required this.onLogout,
    required this.loggingOut,
  });

  final String title;
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  final bool loggingOut;

  @override
  Widget build(BuildContext context) {
    final name = user['name']?.toString() ?? 'Pengguna';

    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(
        horizontal: 28,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: _line,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _ink,
            ),
          ),
          const Spacer(),
          if (MediaQuery.sizeOf(context).width > 520)
            Container(
              width: 260,
              height: 39,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              decoration: BoxDecoration(
                color: _canvas,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.search,
                    color: _muted,
                    size: 19,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Cari dokumentasi...',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 18),
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFEAF0FF),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: _blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (MediaQuery.sizeOf(context).width > 520) ...[
            const SizedBox(width: 9),
            Text(
              name,
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            IconButton(
              tooltip: loggingOut ? 'Sedang logout' : 'Logout',
              onPressed: loggingOut ? null : onLogout,
              icon: loggingOut
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.logout,
                      size: 19,
                      color: _muted,
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage({
    required this.user,
    required this.health,
    required this.onRefresh,
    required this.onNavigate,
  });

  final Map<String, dynamic> user;
  final Future<HealthStatus> health;
  final VoidCallback onRefresh;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final name = user['name']?.toString() ?? 'Pengguna';

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Text(
          'Selamat datang, $name 👋',
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Simpan, kelola, dan bagikan dokumentasi kegiatan sekolah dalam satu tempat.',
          style: TextStyle(
            color: _muted,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 25),
        LayoutBuilder(
          builder: (context, c) {
            final count = c.maxWidth > 850
                ? 4
                : c.maxWidth > 540
                    ? 2
                    : 1;

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: count,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: count == 1 ? 3.4 : 1.8,
              children: const [
                _StatCard(
                  title: 'Total Album',
                  value: '—',
                  icon: Icons.photo_album_outlined,
                  tint: Color(0xFFEAF0FF),
                ),
                _StatCard(
                  title: 'Total Foto',
                  value: '—',
                  icon: Icons.image_outlined,
                  tint: Color(0xFFE8F8F0),
                ),
                _StatCard(
                  title: 'Total Video',
                  value: '—',
                  icon: Icons.videocam_outlined,
                  tint: Color(0xFFFFF3E7),
                ),
                _StatCard(
                  title: 'Penyimpanan',
                  value: '—',
                  icon: Icons.storage_outlined,
                  tint: Color(0xFFF3ECFF),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 25),
        LayoutBuilder(
          builder: (context, c) {
            final horizontal = c.maxWidth > 760;

            final intro = Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.cloud_done_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Dokumentasi sekolah, lebih terorganisir.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mulai kumpulkan foto dan video kegiatan sekolah agar mudah ditemukan kembali.',
                    style: TextStyle(
                      color: Color(0xFFE0E8FF),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _blue,
                    ),
                    onPressed: () => onNavigate(3),
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'Unggah Dokumentasi',
                    ),
                  ),
                ],
              ),
            );

            final status = _ServiceCard(
              health: health,
              onRefresh: onRefresh,
            );

            if (horizontal) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: intro,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: status,
                  ),
                ],
              );
            }

            return Column(
              children: [
                intro,
                const SizedBox(height: 16),
                status,
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'Akses cepat',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: _ink,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickAction(
              icon: Icons.folder_open_outlined,
              title: 'Lihat File & Folder',
              onTap: () => onNavigate(1),
            ),
            _QuickAction(
              icon: Icons.people_outline,
              title: 'Berkas Dibagikan',
              onTap: () => onNavigate(2),
            ),
            _QuickAction(
              icon: Icons.cloud_upload_outlined,
              title: 'Unggah Berkas',
              onTap: () => onNavigate(3),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: _line,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: _blue,
            ),
          ),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.bold,
                  fontSize: 21,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.health,
    required this.onRefresh,
  });

  final Future<HealthStatus> health;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: _line,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Status layanan',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _ink,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(
                  Icons.refresh,
                  size: 19,
                ),
              ),
            ],
          ),
          FutureBuilder<HealthStatus>(
            future: health,
            builder: (context, s) {
              if (s.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (s.hasError) {
                return const Text(
                  'Tidak dapat menghubungi server.',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                );
              }

              final h = s.requireData;

              return Column(
                children: [
                  _StatusLine(
                    label: 'Backend server',
                    active: h.ok,
                  ),
                  const Divider(height: 20),
                  _StatusLine(
                    label: 'Database',
                    active: h.database,
                  ),
                  const Divider(height: 20),
                  _StatusLine(
                    label: 'Object storage',
                    active: h.storage,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          active ? Icons.check_circle : Icons.error,
          color: active ? Colors.green : Colors.red,
          size: 18,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _ink,
            ),
          ),
        ),
        Text(
          active ? 'Aktif' : 'Bermasalah',
          style: TextStyle(
            fontSize: 11,
            color: active ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 18,
      ),
      label: Text(title),
      style: OutlinedButton.styleFrom(
        foregroundColor: _ink,
        side: const BorderSide(
          color: _line,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      ),
    );
  }
}

class _FoldersPage extends StatelessWidget {
  const _FoldersPage({
    required this.onOpen,
  });

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const Text(
          'File & Folder',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _ink,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Kelola dokumentasi berdasarkan album dan kategori.',
          style: TextStyle(
            color: _muted,
          ),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: _line,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.folder_open_rounded,
                size: 54,
                color: _blue,
              ),
              const SizedBox(height: 12),
              const Text(
                'Belum ada data album',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Daftar album akan muncul di sini setelah Album API tersedia.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _muted,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onOpen,
                icon: const Icon(
                  Icons.info_outline,
                ),
                label: const Text(
                  'Detail folder (pratinjau)',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SharedPage extends StatelessWidget {
  const _SharedPage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const Text(
          'Berkas Dibagikan',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _ink,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Dokumentasi yang dibagikan kepada orang lain.',
          style: TextStyle(
            color: _muted,
          ),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: _line,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.share_outlined,
                size: 52,
                color: _blue,
              ),
              SizedBox(height: 12),
              Text(
                'Belum ada berkas dibagikan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Fitur berbagi akan aktif setelah endpoint pengelolaan album dan izin akses dibuat.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UploadPage extends StatelessWidget {
  const _UploadPage({
    required this.onUpload,
  });

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const Text(
          'Unggah Dokumentasi',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _ink,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Tambahkan foto dan video kegiatan sekolah.',
          style: TextStyle(
            color: _muted,
          ),
        ),
        const SizedBox(height: 22),
        InkWell(
          onTap: onUpload,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 42,
              horizontal: 20,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFFB9C8F8),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 58,
                  color: _blue,
                ),
                SizedBox(height: 14),
                Text(
                  'Pilih foto atau video',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'PNG, JPG, MP4 dan format media lainnya',
                  style: TextStyle(
                    color: _muted,
                  ),
                ),
                SizedBox(height: 15),
                Text(
                  'Pilih Berkas',
                  style: TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Catatan: API backend album dan multipart sudah disiapkan. Tombol pemilihan file akan diaktifkan pada tahap integrasi Flutter berikutnya.',
          style: TextStyle(
            color: _muted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
