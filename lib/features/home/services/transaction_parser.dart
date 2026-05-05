
// ─────────────────────────────────────────────
// transaction_parser.dart — v4 (fully config-driven)
// ─────────────────────────────────────────────

class ParserConfig {
  /// UPI/IMPS/NEFT etc. keyword → transaction type
  /// Truly stable: these are RBI/NPCI protocol identifiers
  /// Even these can be overridden if needed
  final Map<String, String> typeKeywords;

  /// Bank token → display name  (e.g. "HDFC" → "HDFC Bank")
  final Map<String, String> bankTokens;

  /// Uppercase keyword → category  (e.g. "SWIGGY" → "Food")
  final Map<String, String> keywordCategories;

  /// Uppercase keyword → merchant display name  (e.g. "SWIGGY" → "Swiggy")
  final Map<String, String> merchantAliases;

  const ParserConfig({
    this.typeKeywords = const {},
    this.bankTokens = const {},
    this.keywordCategories = const {},
    this.merchantAliases = const {},
  });

  factory ParserConfig.fromJson(Map<String, dynamic> json) {
    return ParserConfig(
      typeKeywords: Map<String, String>.from(json['typeKeywords'] ?? {}),
      bankTokens: Map<String, String>.from(json['bankTokens'] ?? {}),
      keywordCategories: Map<String, String>.from(
        json['keywordCategories'] ?? {},
      ),
      merchantAliases: Map<String, String>.from(json['merchantAliases'] ?? {}),
    );
  }

  /// Merge two configs — useful for layering defaults + user overrides
  ParserConfig merge(ParserConfig other) => ParserConfig(
    typeKeywords: {...typeKeywords, ...other.typeKeywords},
    bankTokens: {...bankTokens, ...other.bankTokens},
    keywordCategories: {...keywordCategories, ...other.keywordCategories},
    merchantAliases: {...merchantAliases, ...other.merchantAliases},
  );
}

class TransactionParser {
  final ParserConfig config;

  // ── Only truly universal constants remain here ───────────────────────────

  /// Structural noise: grammar words + payment field labels.
  /// These are English/banking grammar, not business data.
  static const _noiseTokens = {
    'DR', 'CR', 'TXN', 'REF', 'NO', 'NUM', 'NUMBER',
    'TO', 'BY', 'FROM', 'VIA', 'FOR', 'AT', 'OF', 'AND',
    'TRANSFER', 'PAYMENT', 'TRANSACTION', 'MOBILE', 'INTERNET',
    'BANKING', 'AC', 'INR', 'RS', 'WDL', 'TFR',
    'DEBIT', 'CREDIT', 'DEBITED', 'CREDITED', 'RECEIVED', 'SENT',
    'BANK', // generic word — specific bank names come from config
  };

  /// Structural direction markers — part of SMS grammar, not config
  static const _creditMarkers = {'CR', 'CREDITED', 'RECEIVED', 'REFUND'};
  static const _debitMarkers = {'DR', 'DEBITED', 'SENT', 'PAID'};

  // Compiled once
  static final _refPattern = RegExp(r'\b(\d{9,16})\b');
  static final _amountPattern = RegExp(
    r'(?:RS\.?|INR\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );
  static final _upiIdPattern = RegExp(
    r'[\w.\-+]+@[\w.\-]+',
    caseSensitive: false,
  );
  static final _pureDigits = RegExp(r'^\d+$');
  static final _tokenSplit = RegExp(r'[^A-Z0-9]+');

  TransactionParser(this.config);

  // ── Public API ───────────────────────────────────────────────────────────

  Map<String, dynamic> parse(String raw) {
    if (raw.trim().isEmpty) return _empty(raw);
    // Defensive: normalise whitespace in case caller skipped pre-cleaning
    final cleanRaw = raw
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    if (cleanRaw.isEmpty) return _empty(raw);

    final desc = cleanRaw.toUpperCase();

    final type = _detectType(desc);
    final direction = _detectDirection(desc);

    return {
      'type': type,
      'direction': direction,
      'mode': _detectMode(desc, type),
      'bank': _detectBank(desc),
      'ref': _extractRef(desc),
      'amount': _extractAmount(raw),
      'merchant': extractMerchantName(raw),
      'upiId': _extractUpiId(raw),
      'category': _detectCategory(desc, type, direction),
      'raw': raw,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  String extractMerchantName(String raw) {
    final cleanRaw = raw
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    final desc = cleanRaw.toUpperCase();

    // 1. Config alias (highest priority)
    for (final entry in config.merchantAliases.entries) {
      if (desc.contains(entry.key)) return entry.value;
    }

    // 2. UPI ID parsing
    final upiId = _extractUpiId(raw);
    if (upiId.isNotEmpty) {
      final handle = upiId
          .split('@')
          .first
          .replaceAll(RegExp(r'\d'), '')
          .replaceAll(RegExp(r'[.\-_]'), ' ')
          .trim();

      final parts = handle.split(' ').where((s) => s.length > 2).toList();
      if (parts.isNotEmpty) return parts.map(_titleCase).join(' ');
    }

    // 3. Token-based extraction
    final tokens = desc.split(_tokenSplit).where((s) => s.isNotEmpty).toList();
    final refIdx = tokens.indexWhere((t) => _isRef(t));

    final ignore = {..._noiseTokens, ...config.bankTokens.keys};

    // ✅ helper: build multi-word name
    String? _collectName(int start) {
      List<String> result = [];

      for (int i = start; i < tokens.length; i++) {
        final t = tokens[i];

        if (ignore.contains(t)) continue;
        if (_pureDigits.hasMatch(t)) continue;
        if (t.length < 2) continue;

        // stop if bank appears after name
        if (config.bankTokens.containsKey(t)) break;

        result.add(t);

        // max 2–3 words (avoid garbage)
        if (result.length >= 3) break;
      }

      return result.isNotEmpty ? result.join(' ') : null;
    }

    // ✅ PRIORITY 1: AFTER REF (MOST IMPORTANT FIX)
    if (refIdx >= 0 && refIdx < tokens.length - 1) {
      final name = _collectName(refIdx + 1);
      if (name != null) return _titleCase(name);
    }

    // ✅ PRIORITY 2: BEFORE REF (fallback)
    if (refIdx > 0) {
      for (int i = refIdx - 1; i >= 0; i--) {
        final t = tokens[i];

        if (ignore.contains(t)) continue;
        if (_pureDigits.hasMatch(t)) continue;
        if (t.length < 2) continue;

        return _titleCase(t);
      }
    }

    // ✅ PRIORITY 3: FULL SCAN (last fallback)
    for (final t in tokens) {
      if (ignore.contains(t)) continue;
      if (_pureDigits.hasMatch(t)) continue;
      if (t.length < 2) continue;

      return _titleCase(t);
    }

    return 'Unknown';
  }

  // ── Private detection ────────────────────────────────────────────────────

  String _detectType(String desc) {
    for (final entry in config.typeKeywords.entries) {
      if (desc.contains(entry.key)) return entry.value;
    }
    // Pure structural fallbacks — not merchant/bank data
    if (desc.contains('SAL')) return 'SALARY';
    if (desc.contains('REVERSAL') || desc.contains('REFUND')) return 'REFUND';
    if (desc.contains('INT') && desc.contains('CREDIT')) return 'INTEREST';
    return 'OTHER';
  }

  String _detectDirection(String desc) {
    final tokens = desc.split(_tokenSplit).toSet();
    if (tokens.intersection(_creditMarkers).isNotEmpty) return 'CREDIT';
    if (tokens.intersection(_debitMarkers).isNotEmpty) return 'DEBIT';
    // Word-boundary safe check for standalone CR/DR
    if (RegExp(r'\bCR\b').hasMatch(desc)) return 'CREDIT';
    if (RegExp(r'\bDR\b').hasMatch(desc)) return 'DEBIT';
    return 'UNKNOWN';
  }

  /// Mode derived from type keywords in config — no hardcoded type list
  String _detectMode(String desc, String type) {
    if (desc.contains('ATM')) return 'OFFLINE';
    // If a type was resolved from config it's online (UPI/NEFT/IMPS/etc.)
    if (type != 'OTHER' && type != 'SALARY') return 'ONLINE';
    return 'UNKNOWN';
  }

  String _detectBank(String desc) {
    for (final entry in config.bankTokens.entries) {
      if (RegExp('\\b${RegExp.escape(entry.key)}\\b').hasMatch(desc)) {
        return entry.value;
      }
    }
    return 'UNKNOWN';
  }

  String _detectCategory(String desc, String type, String direction) {
    // Structural — derived from type/direction, not merchant names
    if (type == 'SALARY') return 'Income';
    if (type == 'INTEREST') return 'Income';
    if (type == 'REFUND' && direction == 'CREDIT') return 'Refund';
    if (type == 'AUTO_DEBIT') return 'Auto Debit';
    if (desc.contains('ATM')) return 'Cash Withdrawal';

    // Dynamic: from config
    for (final entry in config.keywordCategories.entries) {
      if (desc.contains(entry.key)) return entry.value;
    }

    return 'Others';
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  bool _isRef(String token) => _refPattern.hasMatch(token) && token.length >= 9;

  String _extractRef(String desc) =>
      _refPattern.firstMatch(desc)?.group(1) ?? '';

  String _extractAmount(String raw) =>
      _amountPattern.firstMatch(raw)?.group(1)?.replaceAll(',', '') ?? '';

  String _extractUpiId(String raw) =>
      _upiIdPattern.firstMatch(raw)?.group(0) ?? '';

  String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  Map<String, dynamic> _empty(String raw) => {
    'type': 'OTHER',
    'direction': 'UNKNOWN',
    'mode': 'UNKNOWN',
    'bank': 'UNKNOWN',
    'ref': '',
    'amount': '',
    'merchant': 'Unknown',
    'upiId': '',
    'category': 'Others',
    'raw': raw,
    'timestamp': DateTime.now().toIso8601String(),
  };
}
