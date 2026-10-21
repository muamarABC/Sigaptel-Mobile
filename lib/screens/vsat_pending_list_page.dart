import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/api_vsat_provider.dart';
import '../providers/vsat_pending_provider.dart';

class VsatPendingListPage extends StatelessWidget {
  const VsatPendingListPage({super.key});

  String _fmt(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Future<void> _syncNow(BuildContext context) async {
    final pendingProvider = context.read<VsatPendingProvider>();
    final apiProvider = context.read<ApiVsatProvider>();

    if (pendingProvider.isSyncing || pendingProvider.items.isEmpty) {
      return;
    }

    final hasNetwork = await apiProvider.hasNetwork();
    if (!context.mounted) {
      return;
    }

    if (!hasNetwork) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masih offline. Sync ditunda.')),
      );
      return;
    }

    await pendingProvider.setSyncing(true);

    final failedItems = <PendingVsatItem>[];
    var sent = 0;

    try {
      for (final item in pendingProvider.items) {
        try {
          final photoFile = File(item.photoPath);
          if (!photoFile.existsSync()) {
            throw Exception('Foto tidak ditemukan pada perangkat.');
          }

          final error = await apiProvider.store(item.fields, photoFile);
          if (error != null) {
            throw Exception(error);
          }

          sent += 1;
        } catch (e) {
          failedItems.add(
            item.copyWith(
              retryCount: item.retryCount + 1,
              lastError: e.toString(),
            ),
          );
        }
      }

      await pendingProvider.replaceAll(failedItems);
    } finally {
      await pendingProvider.setSyncing(false);
    }

    if (!context.mounted) {
      return;
    }

    final failed = failedItems.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sync selesai. Terkirim: $sent, gagal: $failed.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VsatPendingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending VSAT Bakti'),
        actions: [
          IconButton(
            tooltip: 'Sync sekarang',
            onPressed: provider.isSyncing ? null : () => _syncNow(context),
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: provider.items.isEmpty
          ? const Center(child: Text('Tidak ada data pending VSAT'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: provider.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = provider.items[index];
                final lokasi = item.fields['nama_lokasi'] ?? '-';
                final desa = item.fields['desa'] ?? '-';
                final kecamatan = item.fields['kecamatan'] ?? '-';
                final status = item.fields['status'] ?? '-';

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${index + 1}. $lokasi',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$desa, $kecamatan | Status: $status',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dibuat: ${_fmt(item.createdAt)}',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Retry: ${item.retryCount}',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Error terakhir: ${item.lastError ?? '-'}',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
