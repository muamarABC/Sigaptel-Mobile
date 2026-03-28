import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class ProfilePage extends StatelessWidget {
  static const routeName = '/profile';
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE0F2FE),
              Color(0xFFF8FAFC),
              Color(0xFFECFEFF),
            ],
          ),
        ),
        child: SafeArea(
          child: user == null
              ? const Center(
                  child: Text(
                    'Data profil belum tersedia',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(48),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withAlpha(70),
                                ),
                              ),
                              child: const Icon(
                                Icons.workspace_premium_rounded,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user.jabatan,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ProfileCard(
                        title: 'Informasi Pengguna',
                        children: [
                          _ProfileItem(
                            icon: Icons.badge_outlined,
                            label: 'Nama',
                            value: user.name,
                          ),
                          _ProfileItem(
                            icon: Icons.work_outline,
                            label: 'Jabatan',
                            value: user.jabatan,
                          ),
                          _ProfileItem(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: user.email,
                          ),
                          _ProfileItem(
                            icon: Icons.phone_outlined,
                            label: 'Phone',
                            value: user.phone,
                          ),
                          _ProfileItem(
                            icon: Icons.security_outlined,
                            label: 'Role',
                            value: user.role,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12000000),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFBE123C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              final authProvider = context.read<AuthProvider>();
                              final shouldLogout = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) {
                                  return AlertDialog(
                                    title: const Row(
                                      children: [
                                        Icon(Icons.logout_rounded, color: Color(0xFFBE123C)),
                                        SizedBox(width: 8),
                                        Expanded(child: Text('Keluar dari akun?')),
                                      ],
                                    ),
                                    content: const Text(
                                      'Kamu akan keluar dari sesi saat ini dan kembali ke halaman login.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(false),
                                        child: const Text('Batal'),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFFBE123C),
                                        ),
                                        onPressed: () => Navigator.of(dialogContext).pop(true),
                                        child: const Text('Ya, Keluar'),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (shouldLogout != true) {
                                return;
                              }

                              await authProvider.logout();
                              if (!context.mounted) {
                                return;
                              }
                              Navigator.of(context).pushReplacementNamed('/login');
                            },
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text(
                              'Logout',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProfileCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF0C4A6E)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
