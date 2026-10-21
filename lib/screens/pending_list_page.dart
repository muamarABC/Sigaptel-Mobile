import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/api_survey_provider.dart';
import '../providers/survey_provider.dart';

class PendingListPage extends StatelessWidget {
  const PendingListPage({super.key});

  String _fmt(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SurveyProvider>();
    final pending = provider.pendingSurveys;

    Future<void> syncNow() async {
      final apiProvider = context.read<ApiSurveyProvider>();
      final hasNetwork = await apiProvider.hasNetwork();
      if (!context.mounted) {
        return;
      }

      if (!hasNetwork) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Belum ada jaringan internet untuk sync'),
          ),
        );
        return;
      }

      final result = await provider.syncPendingSurveys(
        (survey) => apiProvider.saveSurveyByVillageAndYear(survey),
      );
      if (!context.mounted) {
        return;
      }
      final summary = result.messages.isNotEmpty
          ? result.messages.first
          : 'Sync selesai. Terkirim: ${result.sent}, gagal: ${result.failed}.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(summary)));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Pending Upload'),
        actions: [
          IconButton(
            tooltip: 'Sync sekarang',
            onPressed: provider.isSyncingPending ? null : syncNow,
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: pending.isEmpty
          ? const Center(child: Text('Tidak ada data pending'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: pending.length,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = pending[index];
                final s = item.survey;
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
                        '${index + 1}. ${s.desa} - ${s.kecamatan}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Operator: ${s.operatorName} | Jaringan: ${s.jaringan} | Tahun: ${s.tahunSurvei}',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dibuat: ${_fmt(item.createdAt)}',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Retry Count: ${item.retryCount}',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Error Terakhir: ${item.lastError ?? '-'}',
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
