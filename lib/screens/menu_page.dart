import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'survey_page.dart';
import 'data_page.dart';
import 'map_page.dart';
import 'speedtest_settings_page.dart';
import 'starlink_page.dart';
import 'vsat_page.dart';
import 'gallery_watermark_page.dart';

const Color _ink = Color(0xFF122B3A);
const Color _muted = Color(0xFF6B7C89);
const Color _canvas = Color(0xFFF4F7F9);
const Color _primaryBlue = Color(0xFF2563EB);

// ─── Halaman tab Survei Jaringan ──────────────────────────────────────────────
class _SurveyDataPage extends StatelessWidget {
  const _SurveyDataPage();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _canvas,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _ink,
          elevation: 0,
          toolbarHeight: 56,
          titleSpacing: 4,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Survei Jaringan',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              Text(
                'Pengukuran kualitas jaringan',
                style: TextStyle(
                  fontSize: 10,
                  color: _muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F7),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(3),
                  indicator: BoxDecoration(
                    color: _primaryBlue,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x262563EB),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: _muted,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.radar_rounded, size: 17),
                          SizedBox(width: 6),
                          Text('Survei'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.dataset_rounded, size: 17),
                          SizedBox(width: 6),
                          Text('Data'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: const TabBarView(children: [SurveyContent(), DataContent()]),
      ),
    );
  }
}

// ─── Halaman placeholder untuk pengembangan berikutnya ────────────────────────
class _ComingSoonPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> colors;

  const _ComingSoonPage({
    required this.title,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withAlpha(55),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 46),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: colors.first.withAlpha(20),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'SEGERA HADIR',
                  style: TextStyle(
                    color: colors.first,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Fitur ini sedang dalam pengembangan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Beranda menu ─────────────────────────────────────────────────────────────
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _canvas,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pusat Aktivitas',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: _ink,
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Pilih layanan yang ingin Anda buka',
                          style: TextStyle(fontSize: 12.5, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFFE1E8ED)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.grid_view_rounded,
                          size: 14,
                          color: _primaryBlue,
                        ),
                        SizedBox(width: 5),
                        Text(
                          '4 Layanan',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _MenuCard(
                title: 'Survei Jaringan',
                subtitle:
                    'Catat kualitas sinyal seluler langsung dari lapangan.',
                eyebrow: 'PENGUKURAN JARINGAN',
                icon: Icons.cell_tower_rounded,
                tag: 'AKTIF',
                colors: const [Color(0xFF155EEF), Color(0xFF3987F6)],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _SurveyDataPage(),
                  ),
                ),
              ),
              const SizedBox(height: 13),
              _MenuCard(
                title: 'Starlink',
                subtitle:
                    'Pendataan perangkat Starlink di Kabupaten Barito Timur.',
                eyebrow: 'INTERNET SATELIT',
                icon: Icons.satellite_alt_rounded,
                tag: 'AKTIF',
                colors: const [Color(0xFF6738C8), Color(0xFF9870F2)],
                onTap: () =>
                    Navigator.of(context).pushNamed(StarlinkPage.routeName),
              ),
              const SizedBox(height: 13),
              _MenuCard(
                title: 'VSAT BAKTI',
                subtitle: 'Pantau jaringan VSAT dan status aktivasi di lokasi.',
                eyebrow: 'KONEKTIVITAS',
                icon: Icons.router_rounded,
                tag: 'AKTIF',
                colors: const [Color(0xFF087E8B), Color(0xFF23B5BD)],
                onTap: () =>
                    Navigator.of(context).pushNamed(VsatPage.routeName),
              ),
              const SizedBox(height: 13),
              _MenuCard(
                title: 'Watermark Foto',
                subtitle:
                    'Tambahkan tanggal, waktu, koordinat, dan identitas petugas ke foto.',
                eyebrow: 'DOKUMENTASI LAPANGAN',
                icon: Icons.photo_camera_back_rounded,
                tag: 'TOOLS',
                colors: const [Color(0xFF087F68), Color(0xFF35B891)],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const GalleryWatermarkPage(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _FooterNote(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String eyebrow;
  final IconData icon;
  final String tag;
  final List<Color> colors;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.eyebrow,
    required this.icon,
    required this.tag,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE4EBEF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F2D3D),
                blurRadius: 16,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 61,
                height: 66,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withAlpha(45),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      right: -12,
                      top: -12,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(20),
                        ),
                      ),
                    ),
                    Icon(icon, color: Colors.white, size: 30),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.first,
                        fontSize: 9,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: _ink,
                              letterSpacing: -0.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _StatusTag(
                          label: tag,
                          color: tag == 'TOOLS'
                              ? const Color(0xFF0F766E)
                              : const Color(0xFF16845B),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: _muted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: colors.first.withAlpha(180),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: color.withAlpha(18),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withAlpha(40)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 8.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.35,
      ),
    ),
  );
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.shield_outlined, size: 14, color: Colors.blueGrey.shade300),
      const SizedBox(width: 6),
      Text(
        'SIGAPTEL  •  Tim Manajemen Layanan SPBE  •  Versi 2.0',
        style: TextStyle(
          fontSize: 10,
          color: Colors.blueGrey.shade400,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

// ─── Navigasi utama ───────────────────────────────────────────────────────────
class MenuPage extends StatefulWidget {
  static const routeName = '/menu';
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    HomeTab(),
    MapPage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 18,
        title: Row(
          children: [
            Container(
              width: 37,
              height: 37,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F5F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                'web/gambar/Mask.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.cell_tower_rounded, color: _primaryBlue),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SIGAPTEL',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: _ink,
                  ),
                ),
                Text(
                  'BARITO TIMUR',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: _primaryBlue,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: IconButton(
              tooltip: 'Pengaturan Speed Test',
              onPressed: () => Navigator.of(
                context,
              ).pushNamed(SpeedtestSettingsPage.routeName),
              style: IconButton.styleFrom(
                backgroundColor: _canvas,
                foregroundColor: _ink,
              ),
              icon: const Icon(Icons.settings_rounded, size: 21),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x100F2D3D),
              blurRadius: 18,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            height: 68,
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            indicatorColor: const Color(0xFFDBEAFE),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Menu',
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map_rounded),
                label: 'Peta',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
