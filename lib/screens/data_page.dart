import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/remote_survey.dart';
import '../providers/api_survey_provider.dart';

class DataContent extends StatefulWidget {
  const DataContent({super.key});

  @override
  State<DataContent> createState() => _DataContentState();
}

class _DataContentState extends State<DataContent> {
  late Future<void> _loadFuture;
  late int _selectedYear;
  int _currentPage = 1;
  int _rowsPerPage = 8;
  final TextEditingController _desaCtrl = TextEditingController();
  String _desaQuery = '';

  List<int> _buildYearOptions() {
    final now = DateTime.now().year;
    return List<int>.generate(now - 2024 + 1, (i) => now - i);
  }

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    _loadFuture = context.read<ApiSurveyProvider>().loadSurveys(
      tahun: _selectedYear,
    );
  }

  @override
  void dispose() {
    _desaCtrl.dispose();
    super.dispose();
  }

  void _applyFilter(int? year) {
    if (year == null) return;
    setState(() {
      _selectedYear = year;
      _currentPage = 1;
      _loadFuture = context.read<ApiSurveyProvider>().loadSurveys(tahun: year);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ApiSurveyProvider>();
    final yearOptions = _buildYearOptions();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: _FilterPanel(
              selectedYear: _selectedYear,
              yearOptions: yearOptions,
              rowsPerPage: _rowsPerPage,
              desaCtrl: _desaCtrl,
              onYearChanged: _applyFilter,
              onRowsPerPageChanged: (value) {
                if (value == null) return;
                setState(() {
                  _rowsPerPage = value;
                  _currentPage = 1;
                });
              },
              onDesaChanged: (val) {
                setState(() {
                  _desaQuery = val;
                  _currentPage = 1;
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: _loadFuture,
              builder: (ctx, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final allSurveys = provider.surveys;
                final surveys = _desaQuery.isEmpty
                    ? allSurveys
                    : allSurveys
                          .where(
                            (s) => s.desa.toLowerCase().contains(
                              _desaQuery.toLowerCase(),
                            ),
                          )
                          .toList();
                if (surveys.isEmpty) {
                  return const Center(
                    child: Text(
                      'Belum ada data survey',
                      style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
                    ),
                  );
                }

                final totalData = surveys.length;
                final totalPages = (totalData / _rowsPerPage).ceil();
                final safeCurrentPage = _currentPage.clamp(1, totalPages);
                final start = (safeCurrentPage - 1) * _rowsPerPage;
                final end = (start + _rowsPerPage > totalData)
                    ? totalData
                    : start + _rowsPerPage;
                final shownStart = totalData == 0 ? 0 : start + 1;
                final pageItems = surveys.sublist(start, end);

                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(242),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            color: const Color(0xFFF1F5F9),
                            child: const Text(
                              'Data Survey Jaringan',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.all(10),
                              itemCount: pageItems.length,
                              separatorBuilder: (_, index) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final item = pageItems[i];
                                final no = start + i + 1;
                                return _SurveyListCard(
                                  no: no,
                                  survey: item,
                                  onTap: () {
                                    Navigator.of(context).pushNamed(
                                      '/survey-detail',
                                      arguments: item.id,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          _PaginationBar(
                            shownStart: shownStart,
                            shownEnd: end,
                            pageCount: pageItems.length,
                            totalData: totalData,
                            currentPage: safeCurrentPage,
                            totalPages: totalPages,
                            onPrev: safeCurrentPage > 1
                                ? () {
                                    setState(() {
                                      _currentPage = safeCurrentPage - 1;
                                    });
                                  }
                                : null,
                            onNext: safeCurrentPage < totalPages
                                ? () {
                                    setState(() {
                                      _currentPage = safeCurrentPage + 1;
                                    });
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final int selectedYear;
  final List<int> yearOptions;
  final int rowsPerPage;
  final TextEditingController desaCtrl;
  final ValueChanged<int?> onYearChanged;
  final ValueChanged<int?> onRowsPerPageChanged;
  final ValueChanged<String> onDesaChanged;

  const _FilterPanel({
    required this.selectedYear,
    required this.yearOptions,
    required this.rowsPerPage,
    required this.desaCtrl,
    required this.onYearChanged,
    required this.onRowsPerPageChanged,
    required this.onDesaChanged,
  });

  static InputDecoration _dropDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDE3EE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Pencarian desa
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 11,
                      color: Color(0xFF2563EB),
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Cari Desa',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 34,
                  child: TextField(
                    controller: desaCtrl,
                    onChanged: onDesaChanged,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: _dropDeco('Cari desa...').copyWith(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 30,
                        minHeight: 34,
                      ),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: desaCtrl,
                        builder: (_, val, _) => val.text.isEmpty
                            ? const SizedBox.shrink()
                            : GestureDetector(
                                onTap: () {
                                  desaCtrl.clear();
                                  onDesaChanged('');
                                },
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 15,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Tahun
          SizedBox(
            width: 104,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 11,
                      color: Color(0xFF2563EB),
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Tahun',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 34,
                  child: DropdownButtonFormField<int>(
                    initialValue: selectedYear,
                    isExpanded: true,
                    decoration: _dropDeco('').copyWith(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                    items: yearOptions
                        .map(
                          (year) => DropdownMenuItem<int>(
                            value: year,
                            child: Text(
                              year.toString(),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: onYearChanged,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Baris
          SizedBox(
            width: 78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.table_rows_rounded,
                      size: 11,
                      color: Color(0xFF2563EB),
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Baris',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 34,
                  child: DropdownButtonFormField<int>(
                    initialValue: rowsPerPage,
                    isExpanded: true,
                    decoration: _dropDeco('').copyWith(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                    items: const [
                      DropdownMenuItem<int>(value: 5, child: Text('5')),
                      DropdownMenuItem<int>(value: 8, child: Text('8')),
                      DropdownMenuItem<int>(value: 10, child: Text('10')),
                      DropdownMenuItem<int>(value: 15, child: Text('15')),
                    ],
                    onChanged: onRowsPerPageChanged,
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

class _SurveyListCard extends StatelessWidget {
  final int no;
  final RemoteSurvey survey;
  final VoidCallback onTap;

  const _SurveyListCard({
    required this.no,
    required this.survey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: no.isEven ? const Color(0xFFF8FAFC) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$no',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      survey.desa.isEmpty ? '-' : survey.desa,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Kecamatan: ${survey.kecamatan.isEmpty ? '-' : survey.kecamatan}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: [
                  _MetricChip(label: 'Operator', value: survey.operator),
                  _MetricChip(label: 'Jaringan', value: survey.jaringan),
                  _MetricChip(
                    label: 'RSRP',
                    value: survey.rsrp?.toString() ?? '-',
                  ),
                  _MetricChip(label: 'Sinyal', value: survey.kekuatanSinyal),
                  _MetricChip(label: 'Tahun', value: survey.tahunSurvei),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final safeValue = value.isEmpty ? '-' : value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $safeValue',
        style: const TextStyle(
          fontSize: 10.5,
          color: Color(0xFF1E3A8A),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final int shownStart;
  final int shownEnd;
  final int pageCount;
  final int totalData;
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.shownStart,
    required this.shownEnd,
    required this.pageCount,
    required this.totalData,
    required this.currentPage,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(top: BorderSide(color: Color(0xFFDDE3EE))),
      ),
      child: Row(
        children: [
          // Info block
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Data $shownStart–$shownEnd dari $totalData',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Halaman $currentPage dari $totalPages',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          // Prev button
          _PageBtn(
            icon: Icons.chevron_left_rounded,
            onTap: onPrev,
            tooltip: 'Sebelumnya',
          ),
          const SizedBox(width: 4),
          // Page indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x332563EB),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '$currentPage / $totalPages',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Next button
          _PageBtn(
            icon: Icons.chevron_right_rounded,
            onTap: onNext,
            tooltip: 'Berikutnya',
          ),
        ],
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  const _PageBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Icon(
              icon,
              size: 22,
              color: active ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
            ),
          ),
        ),
      ),
    );
  }
}

class DataPage extends StatelessWidget {
  static const routeName = '/data';
  const DataPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Survey')),
      body: const DataContent(),
    );
  }
}
