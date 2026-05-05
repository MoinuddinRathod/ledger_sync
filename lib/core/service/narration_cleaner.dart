/// Parsed result from a raw SBI narration string.
class ParsedNarration {
  final String transactionMode; // UPI, NEFT, IMPS, ATM, INTEREST, OTHER
  final String direction; // CR (credit), DR (debit), or ''
  final String upiRef; // UPI reference number (only for UPI)
  final String partyName; // Counter-party name, cleaned
  final String partyBank; // Counter-party bank code
  final String upiHandle; // UPI VPA / handle (only for UPI)
  final String rawClean; // Full narration with whitespace collapsed

  const ParsedNarration({
    required this.transactionMode,
    required this.direction,
    required this.upiRef,
    required this.partyName,
    required this.partyBank,
    required this.upiHandle,
    required this.rawClean,
  });

  @override
  String toString() =>
      'ParsedNarration(mode: $transactionMode, dir: $direction, '
      'party: $partyName, bank: $partyBank, upiRef: $upiRef, handle: $upiHandle)';
}

class NarrationCleaner {
  /// Main entry point — pass the raw narration cell value.
  static ParsedNarration parse(String raw) {
    // ── Step 1: collapse the line-break artifact from the PDF/xlsx export ──
    // SBI wraps long strings at ~40 chars with "\n  " (newline + 2 spaces).
    // Merge those back into a single continuous string.
    final clean = raw
        .replaceAll(RegExp(r'\n\s+'), '') // remove line-wrap artifacts
        .replaceAll(RegExp(r'\s{2,}'), ' ') // collapse multiple spaces
        .trim();

    if (_isCharge(clean)) return _parseCharge(clean);
    // ✅ ADD THIS FIRST
    if (_isSlashFormat(clean)) {
      return _parseSlashFormat(clean);
    }

    // ── Step 2: detect transaction mode and direction ──
    if (_isUpi(clean)) return _parseUpi(clean);
    if (_isNeft(clean)) return _parseNeft(clean);
    if (_isImps(clean)) return _parseImps(clean);
    if (_isAtm(clean)) return _parseAtm(clean);
    if (_isInterest(clean)) return _parseInterest(clean);

    // fallback — return cleaned string with no structured fields
    return ParsedNarration(
      transactionMode: 'OTHER',
      direction: '',
      upiRef: '',
      partyName: clean,
      partyBank: '',
      upiHandle: '',
      rawClean: clean,
    );
  }

  // ─────────────────────────────────────────────
  // DETECTORS
  // ─────────────────────────────────────────────

  static bool _isUpi(String s) =>
      s.contains(RegExp(r'UPI/(CR|DR)/', caseSensitive: false));

  static bool _isNeft(String s) =>
      s.contains(RegExp(r'NEFT', caseSensitive: false));

  static bool _isImps(String s) =>
      s.contains(RegExp(r'IMPS/', caseSensitive: false));

  static bool _isAtm(String s) =>
      s.contains(RegExp(r'ATM', caseSensitive: false));

  static bool _isInterest(String s) =>
      s.contains(RegExp(r'INTERES', caseSensitive: false)) ||
      s.contains(RegExp(r'CR I NT DB', caseSensitive: false));

  // ─────────────────────────────────────────────
  // UPI PARSER
  //
  // Format after clean:
  //   DEP TFR UPI/CR/<upiRef>/<partyName>/<bankCode>/<upiHandle>/...
  //   WDL TFR UPI/DR/<upiRef>/<partyName>/<bankCode>/<upiHandle>/...
  //
  // The upiHandle field is split across the line-break in raw data,
  // e.g. "paytmq\n  r69j" → after clean → "paytmqr69j"
  // ─────────────────────────────────────────────
  static ParsedNarration _parseUpi(String clean) {
    // Extract direction
    final dirMatch = RegExp(
      r'UPI/(CR|DR)/',
      caseSensitive: false,
    ).firstMatch(clean);
    final direction = dirMatch != null ? dirMatch.group(1)!.toUpperCase() : '';

    // Everything after UPI/CR/ or UPI/DR/
    final afterDir = clean.split(RegExp(r'UPI/(CR|DR)/', caseSensitive: false));
    if (afterDir.length < 2) {
      return ParsedNarration(
        transactionMode: 'UPI',
        direction: direction,
        upiRef: '',
        partyName: '',
        partyBank: '',
        upiHandle: '',
        rawClean: clean,
      );
    }

    final payload = afterDir[1]; // "<upiRef>/<name>/<bank>/<handle>/..."
    final parts = payload.split('/');

    final upiRef = parts.isNotEmpty ? parts[0].trim() : '';
    final partyName = parts.length > 1 ? _cleanName(parts[1]) : '';
    final partyBank = parts.length > 2 ? parts[2].trim().toUpperCase() : '';

    // UPI handle: may contain the truncated suffix glued back by Step 1.
    // Strip trailing junk (SBI appends "/UPI 009..." or "/Sent 009..." etc.)
    String upiHandle = parts.length > 3 ? parts[3].trim() : '';
    upiHandle = upiHandle.split(
      RegExp(r'\s'),
    )[0]; // drop everything after first space

    return ParsedNarration(
      transactionMode: 'UPI',
      direction: direction,
      upiRef: upiRef,
      partyName: partyName,
      partyBank: partyBank,
      upiHandle: upiHandle,
      rawClean: clean,
    );
  }

  // ─────────────────────────────────────────────
  // NEFT PARSER
  //
  // Format after clean:
  //   DEP TFR NEFT*<senderBankIFSC>*<UTRNumber>*<partyName>*BATCH ...
  // ─────────────────────────────────────────────
  static ParsedNarration _parseNeft(String clean) {
    // ✅ Case 1: Slash format (NEW FIX)
    if (clean.contains('/')) {
      final parts = clean.split('/');

      return ParsedNarration(
        transactionMode: 'NEFT',
        direction: parts.length > 1 ? parts[1].toUpperCase() : '',
        upiRef: parts.length > 2 ? parts[2].trim() : '',
        partyName: parts.length > 3 ? _cleanName(parts[3]) : '',
        partyBank: parts.length > 4 ? parts[4].trim().toUpperCase() : '',
        upiHandle: '',
        rawClean: clean,
      );
    }

    // ✅ Case 2: Old * format (existing logic)
    final neftMatch = RegExp(r'NEFT\*([^\s]+)').firstMatch(clean);
    final neftSegment = neftMatch != null ? neftMatch.group(1) ?? '' : '';

    final parts = neftSegment.split('*');

    final partyBank = parts.isNotEmpty ? parts[0].trim().toUpperCase() : '';
    final upiRef = parts.length > 1 ? parts[1].trim() : '';
    final partyName = parts.length > 2 ? _cleanName(parts[2]) : '';

    return ParsedNarration(
      transactionMode: 'NEFT',
      direction: 'CR',
      upiRef: upiRef,
      partyName: partyName,
      partyBank: partyBank,
      upiHandle: '',
      rawClean: clean,
    );
  }

  // ─────────────────────────────────────────────
  // IMPS PARSER
  //
  // Format after clean:
  //   DEP TFR IMPS/<refNo>/<description>/...
  // ─────────────────────────────────────────────
  static ParsedNarration _parseImps(String clean) {
    final impsMatch = RegExp(
      r'IMPS/(\d+)/([^/]+)',
      caseSensitive: false,
    ).firstMatch(clean);
    final upiRef = impsMatch?.group(1)?.trim() ?? '';
    final partyName = _cleanName(impsMatch?.group(2) ?? '');

    return ParsedNarration(
      transactionMode: 'IMPS',
      direction: clean.toUpperCase().contains('DEP') ? 'CR' : 'DR',
      upiRef: upiRef,
      partyName: partyName,
      partyBank: '',
      upiHandle: '',
      rawClean: clean,
    );
  }

  // ─────────────────────────────────────────────
  // ATM PARSER
  // ─────────────────────────────────────────────
  static ParsedNarration _parseAtm(String clean) {
    // Examples:
    //   "ATM PEN DING AMC"         → fee
    //   "DEBIT ATMCard AMC 478679*0770" → card AMC
    //   "ATM WDL ATM CASH 6033210185 42 FBL BOMBAY" → cash withdrawal
    final isWithdrawal = clean.toUpperCase().contains('WDL');

    String direction = isWithdrawal ? 'DR' : 'DR';
    String partyName = clean
        .replaceAll(RegExp(r'ATM\s*(WDL|PEN|CARD)?', caseSensitive: false), '')
        .replaceAll(RegExp(r'DEBIT\s*', caseSensitive: false), '')
        .replaceAll(
          RegExp(r'AMC', caseSensitive: false),
          'Annual Maintenance Charge',
        )
        .trim();

    return ParsedNarration(
      transactionMode: 'ATM',
      direction: direction,
      upiRef: '',
      partyName: partyName.isEmpty ? 'ATM Charge' : partyName,
      partyBank: '',
      upiHandle: '',
      rawClean: clean,
    );
  }

  // ─────────────────────────────────────────────
  // INTEREST PARSER
  // ─────────────────────────────────────────────
  static ParsedNarration _parseInterest(String clean) {
    final isDebit = clean.toUpperCase().contains('DB');
    return ParsedNarration(
      transactionMode: 'INTEREST',
      direction: isDebit ? 'DR' : 'CR',
      upiRef: '',
      partyName: isDebit ? 'Interest Debit' : 'Interest Credit',
      partyBank: 'SBI',
      upiHandle: '',
      rawClean: clean,
    );
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  /// Title-case a name and strip trailing spaces/slashes.
  static String _cleanName(String raw) {
    return raw
        .trim()
        .replaceAll(RegExp(r'/+'), ' ') // strip trailing slashes
        .replaceAll(RegExp(r'\s+'), ' ') // collapse spaces
        .split(' ')
        .map(
          (w) => w.isEmpty
              ? ''
              : w[0].toUpperCase() + w.substring(1).toLowerCase(),
        )
        .join(' ')
        .trim();
  }

  // ---- for check if format is slash ---- //
  static bool _isSlashFormat(String s) {
    return s.contains('/') && RegExp(r'^[A-Z]+/').hasMatch(s);
  }

  static ParsedNarration _parseSlashFormat(String clean) {
    final parts = clean.split('/');

    final mode = parts.isNotEmpty ? parts[0].toUpperCase() : 'OTHER';
    final direction = parts.length > 1 ? parts[1].toUpperCase() : '';
    final ref = parts.length > 2 ? parts[2].trim() : '';
    final name = parts.length > 3 ? _cleanName(parts[3]) : '';
    final bank = parts.length > 4 ? parts[4].trim().toUpperCase() : '';

    return ParsedNarration(
      transactionMode: mode,
      direction: direction == 'DR' ? 'DR' : 'CR',
      upiRef: ref,
      partyName: name,
      partyBank: bank,
      upiHandle: '',
      rawClean: clean,
    );
  }

  static bool _isCharge(String s) =>
      s.contains(RegExp(r'CHG|CHARGE|FEE', caseSensitive: false));

  static ParsedNarration _parseCharge(String clean) {
    String partyName = clean
        .replaceAll(RegExp(r'CHG|CHARGE|FEE', caseSensitive: false), '')
        .replaceAll(RegExp(r'[/\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return ParsedNarration(
      transactionMode: 'CHARGE',
      direction: 'DR',
      upiRef: '',
      partyName: partyName.isEmpty ? 'Bank Charge' : partyName,
      partyBank: '',
      upiHandle: '',
      rawClean: clean,
    );
  }
}
