import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../../category/providers/category_provider.dart';
import '../../account/providers/account_provider.dart';
import '../models/transaction_models.dart';
import '../../account/models/account_models.dart';
import '../../../core/constants/app_colors.dart';

// ── CSV parsing ────────────────────────────────────────────────────────────────

String _detectDelimiter(String text) {
  final line = text.split('\n').first;
  final counts = {',': 0, ';': 0, '\t': 0};
  for (final ch in line.characters) {
    if (counts.containsKey(ch)) counts[ch] = counts[ch]! + 1;
  }
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

({List<String> headers, List<List<String>> rows}) _parseCsv(String text) {
  final delim = _detectDelimiter(text);
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) return (headers: [], rows: []);

  List<String> parseLine(String line) {
    final fields = <String>[];
    var cur = '';
    var inQ = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQ && i + 1 < line.length && line[i + 1] == '"') {
          cur += '"';
          i++;
        } else {
          inQ = !inQ;
        }
      } else if (ch == delim && !inQ) {
        fields.add(cur.trim());
        cur = '';
      } else {
        cur += ch;
      }
    }
    fields.add(cur.trim());
    return fields;
  }

  final headers =
      parseLine(lines[0]).map((h) => h.replaceAll(RegExp(r'^"|"$'), '')).toList();
  final rows = lines.skip(1).map(parseLine).toList();
  return (headers: headers, rows: rows);
}

String? _parseDate(String val) {
  final s = val.trim();
  if (s.isEmpty) return null;

  final ymd = RegExp(r'^\d{4}-(\d{1,2})-(\d{1,2})$');
  if (ymd.hasMatch(s)) {
    final parts = s.split('-');
    return '${parts[0]}-${parts[1].padLeft(2, '0')}-${parts[2].padLeft(2, '0')}';
  }

  final dmy = RegExp(r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$');
  final m1 = dmy.firstMatch(s);
  if (m1 != null) {
    return '${m1.group(3)}-${m1.group(2)!.padLeft(2, '0')}-${m1.group(1)!.padLeft(2, '0')}';
  }

  try {
    final dt = DateTime.parse(s);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  } catch (_) {}

  return null;
}

double? _parseAmount(String val) {
  if (val.trim().isEmpty) return null;
  var s = val.trim().replaceAll(RegExp(r'[RrIiDdpP\s]+'), '').trim();
  if (s.isEmpty) return null;

  final negative = s.startsWith('-');
  s = s.replaceAll(RegExp(r'^[-+]'), '');

  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  if (lastComma > lastDot) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else {
    s = s.replaceAll(',', '');
  }

  final n = double.tryParse(s);
  if (n == null || n < 0) return null;
  return negative ? -n : n;
}

String? _normalizeType(String val) {
  final v = val.toLowerCase().trim();
  const income = ['income', 'pemasukan', 'masuk', 'kredit', 'credit', 'in'];
  const expense = ['expense', 'pengeluaran', 'keluar', 'debit', 'out'];
  if (income.contains(v)) return 'income';
  if (expense.contains(v)) return 'expense';
  if (v == 'transfer') return 'transfer';
  return null;
}

final _fieldOptions = [
  (value: 'date', label: 'Tanggal'),
  (value: 'type', label: 'Tipe'),
  (value: 'amount', label: 'Jumlah'),
  (value: 'category', label: 'Kategori (nama)'),
  (value: 'account', label: 'Rekening (nama)'),
  (value: 'to_account', label: 'Ke Rekening (nama)'),
  (value: 'description', label: 'Catatan'),
  (value: '__skip', label: '— Lewati —'),
];

Map<String, String> _autoDetectMapping(List<String> headers) {
  final rules = [
    (['date', 'tanggal', 'tgl', 'waktu', 'time'], 'date'),
    (['type', 'tipe', 'jenis', 'kind'], 'type'),
    (['amount', 'jumlah', 'nominal', 'nilai', 'harga', 'total'], 'amount'),
    (['category', 'kategori', 'kat', 'cat'], 'category'),
    (['account', 'rekening', 'rek', 'akun', 'from_account', 'dari', 'from'], 'account'),
    (['to_account', 'to account', 'ke_rekening', 'ke rekening', 'tujuan', 'to'], 'to_account'),
    (['description', 'catatan', 'keterangan', 'desc', 'note', 'memo'], 'description'),
  ];

  final map = <String, String>{};
  final usedFields = <String>{};

  for (final header in headers) {
    final h = header.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), ' ').trim();
    String? matched;
    for (final (keywords, field) in rules) {
      if (keywords.any((k) => h == k || h.contains(k))) {
        if (!usedFields.contains(field)) {
          matched = field;
          usedFields.add(field);
        }
        break;
      }
    }
    map[header] = matched ?? '__skip';
  }
  return map;
}

// ── Data model ─────────────────────────────────────────────────────────────────

class _ParsedRow {
  final int index;
  final String date;
  final String type;
  final double amount;
  final String categoryId;
  final String categoryName;
  final String accountId;
  final String accountName;
  final String toAccountId;
  final String toAccountName;
  final String description;
  final List<String> errors;
  final List<String> warnings;

  const _ParsedRow({
    required this.index,
    required this.date,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.accountId,
    required this.accountName,
    required this.toAccountId,
    required this.toAccountName,
    required this.description,
    required this.errors,
    required this.warnings,
  });

  String get status =>
      errors.isNotEmpty ? 'error' : warnings.isNotEmpty ? 'warning' : 'valid';
}

List<_ParsedRow> _parseRows(
  List<List<String>> rows,
  List<String> headers,
  Map<String, String> mapping,
  List<CategoryModel> categories,
  List<AccountModel> accounts,
) {
  return rows.asMap().entries.map((entry) {
    final i = entry.key;
    final row = entry.value;

    String get(String field) {
      final header = mapping.entries
          .where((e) => e.value == field)
          .map((e) => e.key)
          .firstOrNull;
      if (header == null) return '';
      final idx = headers.indexOf(header);
      return idx >= 0 && idx < row.length ? row[idx].trim() : '';
    }

    final errs = <String>[];
    final warns = <String>[];

    final rawDate = get('date');
    final date = rawDate.isNotEmpty ? _parseDate(rawDate) : null;
    if (date == null) errs.add('Tanggal tidak valid: "$rawDate"');

    final rawType = get('type');
    final rawAmountStr = get('amount');
    final rawAmount = _parseAmount(rawAmountStr);

    var type = _normalizeType(rawType) ?? '';
    if (type.isEmpty && rawAmount != null) {
      type = rawAmount < 0 ? 'expense' : 'income';
    }
    if (type.isEmpty) errs.add('Tipe tidak dikenali: "$rawType"');

    final amount = rawAmount != null ? rawAmount.abs() : 0.0;
    if (rawAmount == null) {
      errs.add('Jumlah tidak valid: "$rawAmountStr"');
    } else if (amount <= 0) {
      errs.add('Jumlah harus lebih dari 0');
    }

    final rawCat = get('category');
    var categoryId = '';
    var categoryName = rawCat;
    if (type != 'transfer') {
      if (rawCat.isEmpty) {
        errs.add('Kolom Kategori kosong');
      } else {
        final cat = categories
            .where((c) => c.name.toLowerCase() == rawCat.toLowerCase())
            .firstOrNull;
        if (cat != null) {
          categoryId = cat.id;
        } else {
          warns.add('Kategori "$rawCat" tidak ditemukan — akan dilewati');
        }
      }
    }

    final rawAcc = get('account');
    var accountId = '';
    var accountName = rawAcc;
    if (rawAcc.isNotEmpty) {
      final acc = accounts
          .where((a) => a.name.toLowerCase() == rawAcc.toLowerCase())
          .firstOrNull;
      if (acc != null) {
        accountId = acc.id;
      } else {
        warns.add('Rekening "$rawAcc" tidak ditemukan');
      }
    }

    final rawToAcc = get('to_account');
    var toAccountId = '';
    var toAccountName = rawToAcc;
    if (type == 'transfer' && rawToAcc.isNotEmpty) {
      final acc = accounts
          .where((a) => a.name.toLowerCase() == rawToAcc.toLowerCase())
          .firstOrNull;
      if (acc != null) {
        toAccountId = acc.id;
      } else {
        warns.add('Rekening tujuan "$rawToAcc" tidak ditemukan');
      }
    }

    final description = get('description');

    return _ParsedRow(
      index: i,
      date: date ?? '',
      type: type,
      amount: amount,
      categoryId: categoryId,
      categoryName: categoryName,
      accountId: accountId,
      accountName: accountName,
      toAccountId: toAccountId,
      toAccountName: toAccountName,
      description: description,
      errors: errs,
      warnings: warns,
    );
  }).toList();
}

// ── Screen ─────────────────────────────────────────────────────────────────────

enum _ImportStep { upload, map, preview, result }

class ImportCsvScreen extends StatefulWidget {
  const ImportCsvScreen({super.key});

  @override
  State<ImportCsvScreen> createState() => _ImportCsvScreenState();
}

class _ImportCsvScreenState extends State<ImportCsvScreen> {
  _ImportStep _step = _ImportStep.upload;
  String _fileName = '';
  List<String> _headers = [];
  List<List<String>> _rawRows = [];
  Map<String, String> _mapping = {};
  List<_ParsedRow> _parsedRows = [];
  bool _importing = false;
  int _importedCount = 0;
  int _failedCount = 0;
  int? _expandedRow;

  void _loadCsv(String name, String text) {
    final (:headers, :rows) = _parseCsv(text);
    if (headers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File kosong atau format tidak dikenali')),
      );
      return;
    }
    setState(() {
      _fileName = name;
      _headers = headers;
      _rawRows = rows;
      _mapping = _autoDetectMapping(headers);
      _step = _ImportStep.map;
      _expandedRow = null;
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'tsv', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    _loadCsv(file.name, utf8.decode(bytes));
  }

  void _toPreview() {
    final categories = context.read<CategoryProvider>().categories;
    final accounts = context.read<AccountProvider>().accounts;
    setState(() {
      _parsedRows = _parseRows(_rawRows, _headers, _mapping, categories, accounts);
      _step = _ImportStep.preview;
      _expandedRow = null;
    });
  }

  Future<void> _doImport() async {
    final valid = _parsedRows.where((r) => r.status != 'error').toList();
    if (valid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada baris yang valid untuk diimpor')),
      );
      return;
    }
    setState(() => _importing = true);
    try {
      final rows = valid.map((r) {
        final m = <String, dynamic>{
          'date': r.date,
          'type': r.type,
          'amount': r.amount,
          'description': r.description,
        };
        if (r.categoryId.isNotEmpty) m['category_id'] = r.categoryId;
        if (r.accountId.isNotEmpty) m['account_id'] = r.accountId;
        if (r.toAccountId.isNotEmpty) m['to_account_id'] = r.toAccountId;
        return m;
      }).toList();

      final res = await context.read<TransactionProvider>().batchCreate(rows);
      setState(() {
        _importedCount = res['imported'] ?? 0;
        _failedCount = res['failed'] ?? 0;
        _step = _ImportStep.result;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengimpor: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _reset() => setState(() {
        _step = _ImportStep.upload;
        _fileName = '';
        _headers = [];
        _rawRows = [];
        _mapping = {};
        _parsedRows = [];
        _importing = false;
        _importedCount = 0;
        _failedCount = 0;
        _expandedRow = null;
      });

  @override
  Widget build(BuildContext context) {
    final validCount = _parsedRows.where((r) => r.status != 'error').length;
    final errorCount = _parsedRows.where((r) => r.status == 'error').length;
    final warnCount = _parsedRows.where((r) => r.status == 'warning').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Import CSV',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_fileName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _fileName.length > 18
                      ? '...${_fileName.substring(_fileName.length - 16)}'
                      : _fileName,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _StepIndicator(current: _step),
          Expanded(
            child: switch (_step) {
              _ImportStep.upload => _UploadStep(onPickFile: _pickFile),
              _ImportStep.map => _MapStep(
                  headers: _headers,
                  rawRows: _rawRows,
                  mapping: _mapping,
                  onChanged: (h, v) => setState(() => _mapping[h] = v),
                ),
              _ImportStep.preview => _PreviewStep(
                  rows: _parsedRows,
                  expandedRow: _expandedRow,
                  onToggleExpand: (i) =>
                      setState(() => _expandedRow = _expandedRow == i ? null : i),
                ),
              _ImportStep.result => _ResultStep(
                  imported: _importedCount,
                  failed: _failedCount,
                ),
            },
          ),
          _Footer(
            step: _step,
            validCount: validCount,
            errorCount: errorCount,
            warnCount: warnCount,
            importing: _importing,
            onBack: () => setState(() {
              _step = _step == _ImportStep.preview
                  ? _ImportStep.map
                  : _ImportStep.upload;
              _expandedRow = null;
            }),
            onNext: _step == _ImportStep.map ? _toPreview : _doImport,
            onReset: _reset,
            onClose: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// ── Step indicator ─────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final _ImportStep current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    const steps = [
      (_ImportStep.upload, 'Upload'),
      (_ImportStep.map, 'Pemetaan'),
      (_ImportStep.preview, 'Preview'),
      (_ImportStep.result, 'Selesai'),
    ];
    final currentIdx = steps.indexWhere((s) => s.$1 == current);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            _StepChip(
              label: steps[i].$2,
              active: steps[i].$1 == current,
              done: i < currentIdx,
            ),
            if (i < steps.length - 1)
              const Icon(Icons.chevron_right, size: 14, color: Colors.black26),
          ],
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool done;
  const _StepChip({required this.label, required this.active, required this.done});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    if (active) {
      bg = AppColors.primary;
      fg = Colors.white;
    } else if (done) {
      bg = AppColors.primary.withValues(alpha: 0.15);
      fg = AppColors.primary;
    } else {
      bg = Colors.black.withValues(alpha: 0.07);
      fg = Colors.black45;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Step 1: Upload ─────────────────────────────────────────────────────────────

class _UploadStep extends StatelessWidget {
  final VoidCallback onPickFile;
  const _UploadStep({required this.onPickFile});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GestureDetector(
            onTap: onPickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.upload_file_rounded, size: 52, color: AppColors.primary.withValues(alpha: 0.6)),
                  const SizedBox(height: 12),
                  const Text(
                    'Pilih file CSV',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Format: .csv · .tsv · .txt',
                    style: TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: onPickFile,
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text('Buka File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FORMAT YANG DIDUKUNG',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black45, letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                const _InfoLine('Delimiter: koma (,) · titik koma (;) · tab — auto-detect'),
                const _InfoLine('Tanggal: YYYY-MM-DD · DD/MM/YYYY · DD-MM-YYYY'),
                const _InfoLine('Jumlah: angka biasa, prefix Rp/IDR, ribuan (1.000.000)'),
                const _InfoLine('Tipe: income/pemasukan · expense/pengeluaran · transfer'),
                const _InfoLine('Jumlah negatif → pengeluaran otomatis jika kolom tipe kosong'),
                const SizedBox(height: 10),
                const Text(
                  'Contoh CSV:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Date,Type,Category,Account,Amount,Description\n'
                    '2026-06-01,expense,Makanan,BCA,15000,Makan siang\n'
                    '2026-06-02,income,Gaji,,5000000,Gaji Juni',
                    style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.black87),
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

class _InfoLine extends StatelessWidget {
  final String text;
  const _InfoLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 12, color: Colors.black45)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.black54))),
        ],
      ),
    );
  }
}

// ── Step 2: Map columns ────────────────────────────────────────────────────────

class _MapStep extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rawRows;
  final Map<String, String> mapping;
  final void Function(String header, String field) onChanged;

  const _MapStep({
    required this.headers,
    required this.rawRows,
    required this.mapping,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final mappedCount = mapping.values.where((v) => v != '__skip').length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.white,
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Cocokkan kolom CSV ke field transaksi',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$mappedCount/${headers.length} dipetakan',
                  style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: headers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final header = headers[i];
              final samples = rawRows
                  .take(3)
                  .map((r) => i < r.length ? r[i] : '')
                  .where((s) => s.isNotEmpty)
                  .join(' / ');
              final currentVal = mapping[header] ?? '__skip';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: currentVal != '__skip'
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : Colors.black12,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            header,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                          if (samples.isNotEmpty)
                            Text(
                              samples,
                              style: const TextStyle(fontSize: 11, color: Colors.black45),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: currentVal,
                      isDense: true,
                      underline: const SizedBox(),
                      borderRadius: BorderRadius.circular(8),
                      items: _fieldOptions
                          .map((o) => DropdownMenuItem(
                                value: o.value,
                                child: Text(o.label, style: const TextStyle(fontSize: 12)),
                              ))
                          .toList(),
                      onChanged: (v) => onChanged(header, v ?? '__skip'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '${rawRows.length} baris data ditemukan',
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ),
      ],
    );
  }
}

// ── Step 3: Preview ────────────────────────────────────────────────────────────

class _PreviewStep extends StatelessWidget {
  final List<_ParsedRow> rows;
  final int? expandedRow;
  final void Function(int) onToggleExpand;

  const _PreviewStep({
    required this.rows,
    required this.expandedRow,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final valid = rows.where((r) => r.status == 'valid').length;
    final warns = rows.where((r) => r.status == 'warning').length;
    final errs = rows.where((r) => r.status == 'error').length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: Colors.white,
          child: Row(
            children: [
              _StatusChip(label: '$valid valid', color: Colors.green),
              if (warns > 0) ...[
                const SizedBox(width: 6),
                _StatusChip(label: '$warns peringatan', color: Colors.orange),
              ],
              if (errs > 0) ...[
                const SizedBox(width: 6),
                _StatusChip(label: '$errs error', color: Colors.red),
              ],
              const Spacer(),
              Text('${rows.length} baris', style: const TextStyle(fontSize: 11, color: Colors.black45)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) => _PreviewRowTile(
              row: rows[i],
              expanded: expandedRow == i,
              onTap: () => onToggleExpand(i),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Ketuk baris untuk lihat detail · Baris error tidak akan diimpor',
            style: TextStyle(fontSize: 11, color: Colors.black38),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _PreviewRowTile extends StatelessWidget {
  final _ParsedRow row;
  final bool expanded;
  final VoidCallback onTap;
  const _PreviewRowTile({required this.row, required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color rowBg = Colors.white;
    Color statusColor = Colors.green;
    IconData statusIcon = Icons.check_circle_outline_rounded;

    if (row.status == 'error') {
      rowBg = Colors.red.shade50;
      statusColor = Colors.red;
      statusIcon = Icons.cancel_outlined;
    } else if (row.status == 'warning') {
      rowBg = Colors.orange.shade50;
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber_rounded;
    }

    Color amountColor = Colors.black87;
    if (row.type == 'income') amountColor = Colors.green.shade700;
    if (row.type == 'expense') amountColor = Colors.red.shade700;
    if (row.type == 'transfer') amountColor = Colors.blue.shade700;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: rowBg,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${row.index + 1}',
                    style: const TextStyle(fontSize: 11, color: Colors.black38),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.date.isNotEmpty ? row.date : '—',
                    style: TextStyle(
                      fontSize: 12,
                      color: row.date.isEmpty ? Colors.red : Colors.black87,
                    ),
                  ),
                ),
                if (row.type.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: amountColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      row.type == 'income'
                          ? 'Masuk'
                          : row.type == 'expense'
                              ? 'Keluar'
                              : 'Transfer',
                      style: TextStyle(fontSize: 10, color: amountColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  row.amount > 0
                      ? 'Rp ${row.amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}'
                      : '—',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: row.amount > 0 ? amountColor : Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(statusIcon, size: 16, color: statusColor),
              ],
            ),
            if (row.categoryName.isNotEmpty || row.accountName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 2),
                child: Text(
                  [
                    if (row.categoryName.isNotEmpty) row.categoryName,
                    if (row.accountName.isNotEmpty) row.accountName,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ),
            if (expanded && (row.errors.isNotEmpty || row.warnings.isNotEmpty))
              Container(
                margin: const EdgeInsets.only(top: 6, left: 28),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: row.status == 'error'
                      ? Colors.red.withValues(alpha: 0.08)
                      : Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: row.status == 'error'
                        ? Colors.red.withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in row.errors)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.cancel_outlined, size: 12, color: Colors.red),
                          const SizedBox(width: 4),
                          Expanded(child: Text(e, style: const TextStyle(fontSize: 11, color: Colors.red))),
                        ],
                      ),
                    for (final w in row.warnings)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange),
                          const SizedBox(width: 4),
                          Expanded(child: Text(w, style: const TextStyle(fontSize: 11, color: Colors.orange))),
                        ],
                      ),
                  ],
                ),
              ),
            const Divider(height: 1),
          ],
        ),
      ),
    );
  }
}

// ── Step 4: Result ─────────────────────────────────────────────────────────────

class _ResultStep extends StatelessWidget {
  final int imported;
  final int failed;
  const _ResultStep({required this.imported, required this.failed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, size: 56, color: Colors.green),
            ),
            const SizedBox(height: 16),
            const Text(
              'Import Selesai!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _ResultCard(
                    value: imported,
                    label: 'Berhasil diimpor',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ResultCard(
                    value: failed,
                    label: 'Gagal',
                    color: failed > 0 ? Colors.red : Colors.black38,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _ResultCard({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}

// ── Footer ─────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final _ImportStep step;
  final int validCount;
  final int errorCount;
  final int warnCount;
  final bool importing;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onReset;
  final VoidCallback onClose;

  const _Footer({
    required this.step,
    required this.validCount,
    required this.errorCount,
    required this.warnCount,
    required this.importing,
    required this.onBack,
    required this.onNext,
    required this.onReset,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: switch (step) {
        _ImportStep.upload => Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(onPressed: onClose, child: const Text('Batal')),
            ],
          ),
        _ImportStep.map => Row(
            children: [
              OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('Kembali'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.preview_rounded, size: 18),
                label: const Text('Preview'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        _ImportStep.preview => Row(
            children: [
              OutlinedButton.icon(
                onPressed: importing ? null : onBack,
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('Kembali'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: (importing || validCount == 0) ? null : onNext,
                icon: importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.upload_rounded, size: 18),
                label: Text(importing
                    ? 'Mengimpor...'
                    : 'Import $validCount Transaksi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        _ImportStep.result => Row(
            children: [
              OutlinedButton(onPressed: onClose, child: const Text('Tutup')),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Import Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
      },
    );
  }
}
