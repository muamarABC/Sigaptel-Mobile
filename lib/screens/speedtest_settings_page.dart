import 'package:flutter/material.dart';

import '../services/network_metrics_service.dart';

class SpeedtestSettingsPage extends StatefulWidget {
  static const routeName = '/speedtest-settings';

  const SpeedtestSettingsPage({super.key});

  @override
  State<SpeedtestSettingsPage> createState() => _SpeedtestSettingsPageState();
}

class _SpeedtestSettingsPageState extends State<SpeedtestSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _downloadUrlC = TextEditingController();
  final _uploadUrlC = TextEditingController();
  final _pingUrlC = TextEditingController();
  final _downloadBytesC = TextEditingController();
  final _uploadBytesC = TextEditingController();
  SpeedTestMode _selectedMode = SpeedTestMode.standar;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _downloadUrlC.dispose();
    _uploadUrlC.dispose();
    _pingUrlC.dispose();
    _downloadBytesC.dispose();
    _uploadBytesC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await SpeedTestSettings.load();
    if (!mounted) {
      return;
    }

    setState(() {
      _downloadUrlC.text = settings.downloadUrl;
      _uploadUrlC.text = settings.uploadUrl;
      _pingUrlC.text = settings.pingUrl;
      _downloadBytesC.text = settings.downloadBytes.toString();
      _uploadBytesC.text = settings.uploadBytes.toString();
      _selectedMode = settings.mode;
      _loading = false;
    });
  }

  String? _urlValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'URL wajib diisi';
    }
    final uri = Uri.tryParse(text);
    if (uri == null || !(uri.hasScheme && uri.hasAuthority)) {
      return 'Format URL tidak valid';
    }
    return null;
  }

  String? _bytesValidator(String? value) {
    final text = value?.trim() ?? '';
    final parsed = int.tryParse(text);
    if (parsed == null || parsed <= 0) {
      return 'Harus angka > 0';
    }
    return null;
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final settings = SpeedTestSettings(
        downloadUrl: _downloadUrlC.text.trim(),
        uploadUrl: _uploadUrlC.text.trim(),
        pingUrl: _pingUrlC.text.trim(),
        downloadBytes: int.parse(_downloadBytesC.text.trim()),
        uploadBytes: int.parse(_uploadBytesC.text.trim()),
        mode: _selectedMode,
      );
      await settings.save();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan speed test disimpan.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _resetDefaults() {
    final defaults = SpeedTestSettings.defaults();
    setState(() {
      _downloadUrlC.text = defaults.downloadUrl;
      _uploadUrlC.text = defaults.uploadUrl;
      _pingUrlC.text = defaults.pingUrl;
      _downloadBytesC.text = defaults.downloadBytes.toString();
      _uploadBytesC.text = defaults.uploadBytes.toString();
      _selectedMode = defaults.mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings Speed Test')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Atur mode akurasi, endpoint, dan bytes untuk speed test.',
                      style: TextStyle(color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SpeedTestMode>(
                      initialValue: _selectedMode,
                      decoration: const InputDecoration(
                        labelText: 'Mode Pengujian',
                        border: OutlineInputBorder(),
                      ),
                      items: SpeedTestMode.values
                          .map(
                            (mode) => DropdownMenuItem<SpeedTestMode>(
                              value: mode,
                              child: Text(mode.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedMode = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _downloadUrlC,
                      decoration: const InputDecoration(
                        labelText: 'Download URL',
                        border: OutlineInputBorder(),
                      ),
                      validator: _urlValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _uploadUrlC,
                      decoration: const InputDecoration(
                        labelText: 'Upload URL',
                        border: OutlineInputBorder(),
                      ),
                      validator: _urlValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pingUrlC,
                      decoration: const InputDecoration(
                        labelText: 'Ping URL',
                        border: OutlineInputBorder(),
                      ),
                      validator: _urlValidator,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _downloadBytesC,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Download Bytes',
                              border: OutlineInputBorder(),
                            ),
                            validator: _bytesValidator,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _uploadBytesC,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Upload Bytes',
                              border: OutlineInputBorder(),
                            ),
                            validator: _bytesValidator,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Unduhan diuji selama 6–10 detik per putaran dengan dua koneksi. Ukuran permintaan minimal 50 MB per koneksi agar transfer berlangsung selama tes. Download URL harus mengirim data biner langsung (HTTP 200), bisa diakses tanpa login, dan mendukung GET berulang. Gunakan server yang dekat dengan lokasi pengujian untuk hasil yang lebih relevan.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save),
                          label: Text(_saving ? 'Menyimpan...' : 'Simpan'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _resetDefaults,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Reset Default'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
