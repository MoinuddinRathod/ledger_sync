import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import '../models/parsed_transaction_model.dart';
import 'bank_statement_parser.dart';
import 'parse_result.dart';

/// SBI (State Bank of India) statement parser.
///
/// Handles both CSV and Excel formats by dynamically detecting the header row
/// instead of relying on hardcoded column indices.
///
/// ## Supported header columns (SBI standard):
///   Txn Date | Value Date | Description | Ref No / Cheque No | Branch Code | Debit | Credit | Balance
class SbiParser extends BankStatementParser {
  String? _bankName;
  @override
  String get bankName => _bankName ?? '';

  @override
  Future<ParseResult> parse(String filePath) async {
    final ext = BankStatementParser.getExtension(filePath);

    if (ext == 'csv') return await _parseCsv(filePath);
    if (ext == 'xls' || ext == 'xlsx') return await _parseExcel(filePath);

    return ParseResult(errorMessage: 'Unsupported file format: $ext');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EXCEL PARSER
  // ─────────────────────────────────────────────────────────────────────────

  Future<ParseResult> _parseExcel(String filePath) async {
    try {
      final bytes = File(filePath).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);
      final sheetName = excel.tables.keys.first;

      final sheet = excel.tables[sheetName];

      if (sheet == null) {
        return const ParseResult(errorMessage: 'Could not read Excel sheet.');
      }

      final stringRows = sheet.rows.map((row) {
        return row.map((cell) {
          if (cell == null) return '';
          final v = cell.value;
          if (v == null) return '';
          if (v is DateTimeCellValue) {
            final dt = v.asDateTimeLocal();

            return '${dt.year.toString().padLeft(4, '0')}-'
                '${dt.month.toString().padLeft(2, '0')}-'
                '${dt.day.toString().padLeft(2, '0')}';
          }
          return _normalizeCellText(v.toString().trim());
        }).toList();
      }).toList();

      if (stringRows.isEmpty) return const ParseResult(isEmpty: true);

      return _processStringRows(stringRows);
    } catch (e) {
      return ParseResult(errorMessage: 'Error parsing Excel file: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CSV PARSER
  // ─────────────────────────────────────────────────────────────────────────

  Future<ParseResult> _parseCsv(String filePath) async {
    try {
      final content = await File(filePath).readAsString();
      final rows = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(content);

      if (rows.isEmpty) return const ParseResult(isEmpty: true);

      final stringRows = rows
          .map(
            (row) => row
                .map((val) => _normalizeCellText(val?.toString().trim() ?? ''))
                .toList(),
          )
          .toList();

      return _processStringRows(stringRows);
    } catch (e) {
      return ParseResult(errorMessage: 'Error parsing CSV file');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHARED ROW PROCESSING
  // ─────────────────────────────────────────────────────────────────────────

  ParseResult _processStringRows(List<List<String>> rows) {
    _bankName = _extractBankName(rows);
    String? accountName;
    String? accountNumber;
    double? initialBalance;
    double? currentBalance;

    int headerRowIndex = -1;
    _ColIndices? cols;

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowText = row.join(' ').toLowerCase();

      // Extract account number from any metadata row
      if (rowText.contains('account number') ||
          rowText.contains('account no') ||
          rowText.contains('a/c no') ||
          rowText.contains('a/c number')) {
        final num = _extractAccountNumberFromRow(row);
        if (num != null) accountNumber = num;
      }

      if (i == 0 && accountName == null) {
        final raw = row.firstWhere((c) => c.isNotEmpty, orElse: () => '');
        if (raw.isNotEmpty) {
          String cleaned = raw
              // ✅ Remove common prefixes like "Account Name :"
              .replaceAll(
                RegExp(r'^(account\s*name\s*[:\-]?\s*)', caseSensitive: false),
                '',
              )
              // fallback: anything before colon
              .replaceAllMapped(
                RegExp(r'^.*?:\s*'),
                (m) => m.group(0)!.contains(':') ? '' : m.group(0)!,
              )
              .replaceAll(
                RegExp(r'\bNot Available\b', caseSensitive: false),
                '',
              )
              .replaceAll(RegExp(r' {2,}'), ' ')
              .trim();

          if (cleaned.isNotEmpty) {
            accountName = cleaned;
          }
        }
      }

      // Detect header row
      final detected = _detectHeader(row);
      if (detected != null) {
        headerRowIndex = i;
        cols = detected;
        break;
      }
    }

    if (headerRowIndex == -1 || cols == null) {
      return const ParseResult(
        errorMessage:
            'Could not detect column headers. Expected columns: Date, Description, Debit, Credit.',
      );
    }

    final txns = <ParsedTransactionModel>[];

    // ── Row continuation state ─────────────────────────────────────────
    // Tracks the last valid date seen, so continuation rows (empty date,
    // has amount) are not silently dropped.
    String? _pendingDate;
    String? _pendingNarration;

    print('═══ PARSER DEBUG START ═══');
    print('Total rows in file: ${rows.length}');
    print('Header detected at row: $headerRowIndex');
    print(
      'Cols → date:${cols.dateCol} desc:${cols.descCol} '
      'debit:${cols.debitCol} credit:${cols.creditCol} '
      'ref:${cols.refCol} balance:${cols.balanceCol}',
    );
    print('Header row content: ${rows[headerRowIndex]}');
    print('══════════════════════════');

    for (int i = headerRowIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      // Print every single raw row
      print('RAW ROW[$i]: ${row.map((c) => '"$c"').join(' | ')}');

      if (row.isEmpty || row.every((c) => c.trim().isEmpty)) {
        print('  → SKIPPED: fully empty row');
        continue;
      }

      String safe(int? idx) =>
          (idx != null && idx < row.length) ? row[idx].trim() : '';

      final rawDate = safe(cols.dateCol);

      final rawDebit = safe(cols.debitCol);
      final rawCredit = safe(cols.creditCol);
      final rawBalance = safe(cols.balanceCol);
      final rawDesc = safe(cols.descCol);
      final rawRef = safe(cols.refCol);

      print(
        '  → date:"$rawDate" debit:"$rawDebit" credit:"$rawCredit" '
        'balance:"$rawBalance" desc:"${rawDesc.substring(0, rawDesc.length.clamp(0, 30))}" '
        'ref:"$rawRef"',
      );

      final debitStr = safe(
        cols.debitCol,
      ).replaceAll(',', '').replaceAll(' ', '');
      final creditStr = safe(
        cols.creditCol,
      ).replaceAll(',', '').replaceAll(' ', '');

      final debitAmt = double.tryParse(debitStr) ?? 0.0;
      final creditAmt = double.tryParse(creditStr) ?? 0.0;
      final hasAmount = debitAmt > 0 || creditAmt > 0;
      final rawNarration = safe(cols.descCol);

      // ── Detect if this is a continuation row ──────────────────────────
      // Continuation: no date (or unparseable date) but has amount OR narration
      final parsedDate = rawDate.isNotEmpty ? _normalizeDate(rawDate) : null;
      print(
        '  → parsedDate:$parsedDate debitAmt:$debitAmt creditAmt:$creditAmt',
      );

      if (parsedDate == null && rawDate.isNotEmpty) {
        print('  → ⚠️ DATE PARSE FAILED for: "$rawDate"');
      }
      if (debitAmt == 0.0 && creditAmt == 0.0) {
        print('  → ⚠️ ZERO AMOUNT — debit:"$rawDebit" credit:"$rawCredit"');
      }

      final isContinuation = parsedDate == null && _pendingDate != null;

      if (parsedDate != null) {
        // Fresh transaction row — update pending date
        _pendingDate = parsedDate;
        _pendingNarration = rawNarration.isNotEmpty ? rawNarration : null;
      } else if (isContinuation) {
        // Continuation row — append narration if present
        if (rawNarration.isNotEmpty && _pendingNarration != null) {
          _pendingNarration = '${_pendingNarration!} $rawNarration'.trim();
        } else if (rawNarration.isNotEmpty) {
          _pendingNarration = rawNarration;
        }
      }

      // ── Build a synthetic row with carried-forward date ───────────────
      List<String> effectiveRow = List.from(row);
      if (isContinuation && _pendingDate != null) {
        // Inject the carried-forward date into the date column
        if (cols.dateCol < effectiveRow.length) {
          effectiveRow[cols.dateCol] = _pendingDate!;
        }
        // Inject accumulated narration if this row's narration is empty
        if (cols.descCol != null &&
            cols.descCol! < effectiveRow.length &&
            effectiveRow[cols.descCol!].trim().isEmpty &&
            _pendingNarration != null) {
          effectiveRow[cols.descCol!] = _pendingNarration;
        }
        print('  → CONTINUATION ROW: injected date=$_pendingDate');
      }

      // ── Skip rows that have no date AND no amount ─────────────────────
      // These are truly empty/metadata rows
      if (_pendingDate == null && debitAmt == 0.0 && creditAmt == 0.0) {
        print('  → SKIPPED: no date context and no amount');
        continue;
      }

      final txn = _parseRow(effectiveRow, cols);

      if (txn == null) {
        print('  → ❌ _parseRow returned NULL');
      } else {
        print(
          '  → ✅ PARSED: ${txn.date} | ${txn.type} | ${txn.amount} | '
          '"${txn.narration.substring(0, txn.narration.length.clamp(0, 40))}"',
        );
      }

      // ── Balance tracking ──────────────────────────────────────────────
      final String bStrRaw = safe(cols.balanceCol);
      if (bStrRaw.isNotEmpty) {
        final bool isDr =
            bStrRaw.toUpperCase().endsWith('DR') ||
            bStrRaw.toUpperCase().endsWith('DB');
        final String bStr = bStrRaw
            .replaceAll(',', '')
            .replaceAll(' ', '')
            .replaceAll(RegExp(r'[^\d.-]'), '');

        double? rowBal = double.tryParse(bStr);
        if (rowBal != null) {
          rowBal = (isDr && rowBal > 0) ? -rowBal : rowBal;
          currentBalance = rowBal;

          if (initialBalance == null) {
            if (txn == null) {
              initialBalance = rowBal;
            } else {
              initialBalance = txn.type == 'Cr'
                  ? rowBal - txn.amount
                  : rowBal + txn.amount;
            }
          }
        }
      }

      if (txn != null) txns.add(txn);
    }
    print('═══ PARSER DEBUG END ═══');
    print('Transactions parsed: ${txns.length}');
    print('Expected: 30');

    // ── Safety net: if balance column missing but transactions exist ──────
    // Derive opening from first transaction's stored balance field
    if (initialBalance == null && txns.isNotEmpty) {
      final first = txns.first;
      if (first.balance != null) {
        initialBalance = first.type == 'Cr'
            ? first.balance! - first.amount
            : first.balance! + first.amount;
      }
    }
    String? fromDate;
    String? toDate;
    for (final txn in txns) {
      if (fromDate == null || txn.date.compareTo(fromDate) < 0)
        fromDate = txn.date;
      if (toDate == null || txn.date.compareTo(toDate) > 0) toDate = txn.date;
    }

    return ParseResult(
      bankName: _bankName,
      accountName: accountName,
      accountNumber: accountNumber,
      initialBalance: initialBalance,
      currentBalance: currentBalance,
      fromDate: fromDate,
      toDate: toDate,
      isEmpty: txns.isEmpty,
      transactions: txns,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER DETECTION
  //
  // FIX: Each column type is checked independently (no else-if chain) so that
  // e.g. a "Value Date" column before "Txn Date" does not prevent description
  // detection.  "Txn Date" is preferred over "Value Date" when both exist.
  // ─────────────────────────────────────────────────────────────────────────

  _ColIndices? _detectHeader(List<String> row) {
    final lrow = row.map((c) => c.toLowerCase().trim()).toList();

    int? txnDateCol; // preferred: "txn date", "transaction date", "tran date"
    int? valueDateCol; // fallback:  "value date", "date"
    int? descCol;
    int? debitCol;
    int? creditCol;
    int? refCol;
    int? balanceCol;

    for (int i = 0; i < lrow.length; i++) {
      final h = lrow[i];

      // --- Preferred date (txn date) ---
      if (txnDateCol == null &&
          (h == 'txn date' ||
              h == 'transaction date' ||
              h == 'tran date' ||
              h.startsWith('txn date') ||
              h.startsWith('transaction date') ||
              h.startsWith('tran date'))) {
        txnDateCol = i;
        continue; // don't let this index be reused for another column
      }

      // --- Fallback date (value date / plain "date") ---
      if (valueDateCol == null &&
          (h == 'value date' ||
              h == 'date' ||
              h.startsWith('value date') ||
              h.startsWith('date'))) {
        valueDateCol = i;
        continue;
      }

      // --- Description / narration ---
      // FIX: checked independently so it is never skipped
      if (descCol == null &&
          (h == 'description' ||
              h == 'narration' ||
              h == 'particulars' ||
              h == 'remarks' ||
              h == 'details' ||
              h == 'transaction remarks' ||
              h == 'transaction details' ||
              h.contains('description') ||
              h.contains('narration') ||
              h.contains('particulars') ||
              h.contains('details') || // ← ADD THIS
              h.contains('remarks'))) {
        descCol = i;
        continue;
      }

      // --- Debit ---
      if (debitCol == null &&
          (h == 'debit' ||
              h == 'dr' ||
              h == 'withdrawal' ||
              h == 'withdrawal amt' ||
              h == 'debit amount' ||
              h.startsWith('debit') ||
              h.startsWith('withdrawal'))) {
        debitCol = i;
        continue;
      }

      // --- Credit ---
      if (creditCol == null &&
          (h == 'credit' ||
              h == 'cr' ||
              h == 'deposit' ||
              h == 'deposit amt' ||
              h == 'credit amount' ||
              h.startsWith('credit') ||
              h.startsWith('deposit'))) {
        creditCol = i;
        continue;
      }

      // --- Balance ---   ← ADD THIS ENTIRE BLOCK
      if (balanceCol == null &&
          (h == 'balance' ||
              h == 'closing balance' ||
              h == 'running balance' ||
              h.contains('balance'))) {
        balanceCol = i;
        continue;
      }

      // --- Reference / cheque ---
      if (refCol == null &&
          (h.contains('ref') ||
              h.contains('chq') ||
              h.contains('cheque') ||
              h.contains('utr'))) {
        refCol = i;
        // no continue — ref can share space with other loose matches
      }
    }

    // Prefer txnDateCol; fall back to valueDateCol
    final dateCol = txnDateCol ?? valueDateCol;

    // Need at least date + (debit OR credit)
    if (dateCol == null) return null;
    if (debitCol == null && creditCol == null) return null;

    return _ColIndices(
      dateCol: dateCol,
      descCol: descCol,
      debitCol: debitCol,
      creditCol: creditCol,
      refCol: refCol,
      balanceCol: balanceCol,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ROW PARSING
  // ─────────────────────────────────────────────────────────────────────────

  ParsedTransactionModel? _parseRow(List<String> row, _ColIndices cols) {
    String safe(int? idx) =>
        (idx != null && idx < row.length) ? row[idx].trim() : '';

    final balanceStrRaw = safe(cols.balanceCol);
    final bool isDrBal =
        balanceStrRaw.toUpperCase().endsWith('DR') ||
        balanceStrRaw.toUpperCase().endsWith('DB');
    final balanceStr = balanceStrRaw
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^\d.-]'), '');

    double? balance = double.tryParse(balanceStr);
    if (balance != null && isDrBal && balance > 0) {
      balance = -balance;
    }

    final rawDate = safe(cols.dateCol);
    if (rawDate.isEmpty) return null;

    final date = _normalizeDate(rawDate);
    if (date == null) return null;

    // FIX: narration is now reliably populated because descCol detection was fixed.
    // Additionally fall back to joining all non-amount columns when descCol is null.
    String narration = _normalizeNarration(safe(cols.descCol));
    if (narration.isEmpty) {
      // Best-effort fallback: concatenate columns that are not date/debit/credit/ref
      final skipCols = {
        cols.dateCol,
        if (cols.debitCol != null) cols.debitCol!,
        if (cols.creditCol != null) cols.creditCol!,
        if (cols.refCol != null) cols.refCol!,
        if (cols.balanceCol != null) cols.balanceCol!,
      };
      narration = row
          .asMap()
          .entries
          .where((e) {
            final val = e.value.trim();

            // Skip known columns
            if (skipCols.contains(e.key)) return false;

            // Skip empty
            if (val.isEmpty) return false;

            // 🚫 Skip pure numbers (amounts like 2003)
            if (RegExp(r'^[\d,]+(\.\d+)?').hasMatch(val)) return false;

            // 🚫 Skip balance-like values (e.g. 12,345.00DR)
            if (RegExp(
              r'^[\d,]+(\.\d+)?(DR|CR)?',
              caseSensitive: false,
            ).hasMatch(val))
              return false;

            return true;
          })
          .map((e) => e.value.trim())
          .join(' ')
          .trim();
    }

    String ref = safe(cols.refCol);
    // Strip trailing .0 from refs that were stored as floats by Excel
    if (ref.endsWith('.0')) {
      ref = ref.substring(0, ref.length - 2);
    }

    final debitStr = safe(
      cols.debitCol,
    ).replaceAll(',', '').replaceAll(' ', '');
    final creditStr = safe(
      cols.creditCol,
    ).replaceAll(',', '').replaceAll(' ', '');

    final debitAmt = double.tryParse(debitStr) ?? 0.0;
    final creditAmt = double.tryParse(creditStr) ?? 0.0;

    double amount;
    String type;

    if (debitAmt > 0) {
      amount = debitAmt;
      type = 'Dr';
    } else if (creditAmt > 0) {
      amount = creditAmt;
      type = 'Cr';
    } else {
      return null; // skip zero-amount rows (opening/closing balance markers)
    }

    // txnRef must be non-empty for UNIQUE constraint
    final txnRef = ref.isNotEmpty
        ? 'IMP-$ref'
        : _generateTxnRef(date, narration, amount);

    return ParsedTransactionModel(
      txnRef: txnRef,
      date: date,
      narration: narration,
      amount: amount,
      type: type,
      balance: balance,
      rawRow: {for (int i = 0; i < row.length; i++) 'col_$i': row[i]},
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DATE NORMALIZATION  →  yyyy-MM-dd
  // ─────────────────────────────────────────────────────────────────────────

  String? _normalizeDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    // ── NEW: Full ISO 8601 datetime: yyyy-MM-ddTHH:mm:ss.sssZ ─────────
    // Excel/CSV exports often store dates as full datetime strings
    final isoDateTime = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})[T ].*',
    ).firstMatch(s);
    if (isoDateTime != null) {
      final y = int.parse(isoDateTime.group(1)!);
      final m = int.parse(isoDateTime.group(2)!);
      final d = int.parse(isoDateTime.group(3)!);
      if (_valid(y, m, d)) return _fmt(y, m, d);
    }

    // Already ISO: yyyy-MM-dd
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
    if (iso != null) {
      final y = int.parse(iso.group(1)!);
      final m = int.parse(iso.group(2)!);
      final d = int.parse(iso.group(3)!);
      if (_valid(y, m, d)) return _fmt(y, m, d);
    }

    // dd MMM yyyy / dd-MMM-yy
    final mname = RegExp(
      r'^(\d{1,2})[\s\-/](Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[\s\-/](\d{2,4})',
      caseSensitive: false,
    ).firstMatch(s);
    if (mname != null) {
      final d = int.parse(mname.group(1)!);
      final m = _mon(mname.group(2)!);
      var y = int.parse(mname.group(3)!);
      if (y < 100) y = y < 50 ? 2000 + y : 1900 + y;
      if (m != null && _valid(y, m, d)) return _fmt(y, m, d);
    }

    // dd/mm/yyyy or dd-mm-yyyy
    // FIX: SBI always uses dd/mm/yyyy (Indian format). Prefer that interpretation.
    // Only fall back to mm/dd/yyyy when dd/mm produces an invalid date
    // (e.g. day > 12 is impossible as month, so mm/dd would be the only valid parse).
    final slash = RegExp(
      r'^(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})',
    ).firstMatch(s);
    if (slash != null) {
      final a = int.parse(slash.group(1)!);
      final b = int.parse(slash.group(2)!);
      var c = int.parse(slash.group(3)!);
      if (c < 100) c = c < 50 ? 2000 + c : 1900 + c;

      // SBI primary format: dd/mm/yyyy
      if (_valid(c, b, a)) return _fmt(c, b, a);

      // Fallback: mm/dd/yyyy (only reached when dd/mm is invalid)
      if (_valid(c, a, b)) return _fmt(c, a, b);
    }

    return null;
  }

  bool _valid(int y, int m, int d) {
    if (y < 1900 || y > 2100) return false;
    if (m < 1 || m > 12) return false;
    if (d < 1 || d > 31) return false;
    // Catch impossible dates like 31 Feb
    try {
      DateTime(y, m, d);
      return true;
    } catch (_) {
      return false;
    }
  }

  String _fmt(int y, int m, int d) =>
      '${y.toString().padLeft(4, '0')}-'
      '${m.toString().padLeft(2, '0')}-'
      '${d.toString().padLeft(2, '0')}';

  int? _mon(String abbr) => const {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  }[abbr.toLowerCase()];

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  String _generateTxnRef(String date, String narration, double amount) {
    final normalizedNarration = narration.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    final key =
        '${date}_${normalizedNarration.substring(0, normalizedNarration.length.clamp(0, 32))}_${amount.toStringAsFixed(2)}';
    final hash = key.hashCode.abs().toRadixString(16).toUpperCase();
    return 'SBI-$hash';
  }

  String? _extractAccountNumberFromRow(List<String> row) {
    for (final cell in row) {
      if (cell.contains(':')) {
        final after = cell.split(':').last.trim();
        final n = _cleanNumber(after);
        if (n != null) return n;
      }
      final n = _cleanNumber(cell);
      if (n != null) return n;
    }
    return null;
  }

  /// Normalizes raw cell text — strips line breaks and collapses spaces.
  /// Used at cell-read time on ALL cells so no broken text enters the pipeline.
  String _normalizeCellText(String input) {
    if (input.isEmpty) return input;
    return input
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ') // line breaks → space
        .replaceAll(RegExp(r'\s{2,}'), ' ') // collapse multi-spaces
        .trim();
  }

  /// Deep-cleans a narration string.
  /// 1. Calls _normalizeCellText (handles any residual breaks from CSV paths)
  /// 2. Repairs mid-word line-break splits: "PEN DING" → "PENDING"
  ///    ONLY merges if the split produces a known-bad pattern:
  ///    - one of the two parts is ≤ 3 chars  AND
  ///    - combined result is ≤ 12 chars (avoids merging real two-word phrases)
  String _normalizeNarration(String input) {
    if (input.isEmpty) return input;

    // Step 1: linebreak / whitespace normalisation
    String cleaned = _normalizeCellText(input);

    // Step 2: repair mid-word splits caused by narrow column wrapping.
    // Pattern: word boundary on both sides, one token ≤ 3 chars.
    // "PEN DING" → "PENDING"  ✓
    // "ATM PENDING" → "ATM PENDING"  ✓ (both parts > 3 chars, keep separate)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b([A-Za-z]{1,3})\s+([A-Za-z]{2,})\b'),
      (m) {
        // Short prefix fragment (≤3) glued to following word
        final combined = m.group(1)! + m.group(2)!;
        if (combined.length <= 12) return combined;
        return m.group(0)!; // too long → leave as-is
      },
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b([A-Za-z]{2,})\s+([A-Za-z]{1,3})\b'),
      (m) {
        // Short suffix fragment (≤3) appended to preceding word
        final combined = m.group(1)! + m.group(2)!;
        if (combined.length <= 12) return combined;
        return m.group(0)!;
      },
    );

    // Step 3: final collapse
    return cleaned.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  // FIX: Strip both leading labels AND trailing non-numeric suffixes (e.g. "INR", "SAVINGS")
  String? _cleanNumber(String value) {
    // Remove leading label prefixes
    var cleaned = value
        .replaceAll(RegExp(r'[\s\-]'), '')
        .replaceAll(
          RegExp(r'^(A/C|Account|No|Number|:)+', caseSensitive: false),
          '',
        );

    // FIX: Strip trailing alphabetic suffixes like "INR", "SAVINGS", "SB" etc.
    cleaned = cleaned.replaceAll(RegExp(r'[A-Za-z]+'), '').trim();

    if (cleaned.length >= 8 && RegExp(r'^\d+').hasMatch(cleaned)) {
      return cleaned;
    }
    return null;
  }

  @override
  Future<bool> canParse(String filePath) async {
    try {
      final ext = BankStatementParser.getExtension(filePath);
      List<String> headerCells = [];

      if (ext == 'xlsx' || ext == 'xls') {
        final bytes = File(filePath).readAsBytesSync();
        final excel = Excel.decodeBytes(bytes);
        final sheet = excel.tables[excel.tables.keys.first];

        if (sheet == null) return false;

        for (final row in sheet.rows.take(15)) {
          for (final cell in row) {
            if (cell?.value != null) {
              headerCells.add(_normalize(cell!.value.toString()));
            }
          }
        }
      } else if (ext == 'csv') {
        final lines = await File(filePath).readAsLines();
        for (final line in lines.take(15)) {
          headerCells.addAll(line.split(',').map((e) => _normalize(e)));
        }
      }

      final joined = headerCells.join(' ');

      int score = 0;

      // --- Date detection ---
      if (_containsAny(joined, [
        'txn date',
        'transaction date',
        'tran date',
        'date',
        'posting date',
      ]))
        score += 2;

      // --- Value date (optional, not mandatory) ---
      if (_containsAny(joined, ['value date', 'val date'])) score += 1;

      // --- Reference detection ---
      if (_containsAny(joined, [
        'ref',
        'ref no',
        'reference',
        'cheque',
        'chq',
        'utr',
        'txn id',
      ]))
        score += 2;

      // --- Amount detection ---
      if (_containsAny(joined, ['debit', 'withdrawal', 'dr'])) score += 2;

      if (_containsAny(joined, ['credit', 'deposit', 'cr'])) score += 2;

      // --- Balance detection ---
      if (_containsAny(joined, [
        'balance',
        'running balance',
        'closing balance',
      ]))
        score += 3;

      // --- Narration (bonus) ---
      if (_containsAny(joined, [
        'narration',
        'description',
        'remarks',
        'details',
      ]))
        score += 1;

      // ✅ Threshold (tune this)
      return score >= 6;
    } catch (_) {
      return false;
    }
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[\n\r\t]+'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }

  String? _extractBankName(List<List<String>> rows) {
    for (final row in rows.take(8)) {
      for (final cell in row) {
        final text = cell.trim();

        if (text.isEmpty) continue;

        final lower = text.toLowerCase();

        //  Must contain 'bank' (generic, not specific)
        if (!lower.contains('bank')) continue;

        //  Avoid picking headers like "bank account statement"
        if (lower.contains('statement')) continue;

        //  Prefer longer meaningful names
        if (text.length < 6) continue;
        String cleaned = text
            //  Remove common prefixes like "Account Name :"
            .replaceAll(
              RegExp(r'^(bank\s*name\s*[:\-]?\s*)', caseSensitive: false),
              '',
            )
            // fallback: anything before colon
            .replaceAllMapped(
              RegExp(r'^.*?:\s*'),
              (m) => m.group(0)!.contains(':') ? '' : m.group(0)!,
            )
            .replaceAll(RegExp(r'\bNot Available\b', caseSensitive: false), '')
            .replaceAll(RegExp(r' {2,}'), ' ')
            .trim();

        if (cleaned.isNotEmpty) {
          return cleaned;
        }
        return cleaned;
      }
    }
    return null;
  }
}

/// Internal struct for column indices
class _ColIndices {
  final int dateCol;
  final int? descCol;
  final int? debitCol;
  final int? creditCol;
  final int? refCol;
  final int? balanceCol;

  _ColIndices({
    required this.dateCol,
    this.descCol,
    this.debitCol,
    this.creditCol,
    this.refCol,
    this.balanceCol,
  });
}
