import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../../core/service/local_storage_service.dart';
import '../../bank_account/controllers/bank_account_controller.dart';
import '../services/transaction_parser.dart';
import 'dashboard_controller.dart';

class HomeController extends GetxController {
  // Observable variable
  final greeting = "".obs;
  Timer? _timer;
  @override
  void onInit() {
    super.onInit();
    _updateGreeting(); // Set initial value

    // Check every minute
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _updateGreeting(),
    );

    // fetch bank accounts
    Get.find<BankAccountController>().fetchBankAccounts(
      accountId: LocalStorageService.instance.accountId,
    );
  }

  @override
  void onReady() {
    super.onReady();
    // Refresh dashboard when the home screen is warm (after all controllers init)
    try {
      Get.find<DashboardController>().refreshDashboard();
    } catch (_) {}
  }

  @override
  void onClose() {
    _timer?.cancel(); // Cancel the timer when the controller is disposed
    super.onClose();
  }

  void _updateGreeting() {
    DateTime now = DateTime.now();
    String newGreeting;

    if (now.hour < 12) {
      newGreeting = "Good Morning,";
    } else if (now.hour < 16) {
      newGreeting = "Good Afternoon,";
    } else if (now.hour < 20) {
      newGreeting = "Good Evening,";
    } else {
      newGreeting = "Good Night,";
    }

    // Only update (and trigger rebuild) if the value actually changed
    if (greeting.value != newGreeting) {
      greeting.value = newGreeting;
    }
  }

  ////////////////////////////////////////////////////////////////////////////
  /////                                                                 //////
  /////                  Old Methods and functions                      //////
  /////                                                                 //////
  ////////////////////////////////////////////////////////////////////////////

  // for taking transaction as input from user
  TextEditingController transactionCTR = TextEditingController();

  // empty map for storing parsed transaction
  RxMap<String, dynamic> parsedTransaction = RxMap<String, dynamic>();

  // parse transaction
  Map<String, dynamic> parseTransaction() {
    String original = transactionCTR.text;
    String desc = original.toUpperCase();

    String type = "OTHER";
    String name = "Unknown";
    String ref = "";
    String category = "Others";
    String direction = "UNKNOWN"; // CREDIT / DEBIT
    String mode = "UNKNOWN"; // ONLINE / OFFLINE
    String bank = "UNKNOWN";

    // ---------------- TYPE DETECTION ----------------
    if (desc.contains("UPI")) {
      type = "UPI";
      mode = "ONLINE";
    } else if (desc.contains("IMPS")) {
      type = "IMPS";
      mode = "ONLINE";
    } else if (desc.contains("NEFT")) {
      type = "NEFT";
      mode = "ONLINE";
    } else if (desc.contains("RTGS")) {
      type = "RTGS";
      mode = "ONLINE";
    } else if (desc.contains("ATM")) {
      type = "ATM";
      mode = "OFFLINE";
    } else if (desc.contains("POS") || desc.contains("ECOM")) {
      type = "CARD";
      mode = "ONLINE";
    } else if (desc.contains("ACH") || desc.contains("ECS")) {
      type = "AUTO_DEBIT";
    } else if (desc.contains("SAL")) {
      type = "SALARY";
    }

    // ---------------- DIRECTION ----------------
    if (desc.contains('CR') || desc.contains("CREDIT")) {
      direction = "CREDIT";
    } else if (desc.contains('DR') || desc.contains("DEBIT")) {
      direction = "DEBIT";
    }

    // ---------------- REF NUMBER ----------------
    final refMatch = RegExp(r'\b\d{6,}\b').firstMatch(desc);
    if (refMatch != null) {
      ref = refMatch.group(0)!;
    }

    // ---------------- BANK DETECTION ----------------
    if (desc.contains("HDFC")) {
      bank = "HDFC";
    } else if (desc.contains("SBI")) {
      bank = "SBI";
    } else if (desc.contains("ICICI")) {
      bank = "ICICI";
    } else if (desc.contains("AXIS")) {
      bank = "AXIS";
    }

    // ---------------- NAME DETECTION ----------------
    List<String> words = desc
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();

    List<String> ignore = [
      "UPI",
      "IMPS",
      "NEFT",
      "RTGS",
      "ATM",
      "POS",
      "ECOM",
      'DR',
      'CR',
      "TXN",
      "TRANSFER",
      "PAYMENT",
      "TO",
      "BY",
      "FROM",
      "BANK",
    ];

    words.removeWhere((w) => ignore.contains(w) || RegExp(r'^\d+').hasMatch(w));

    if (words.isNotEmpty) {
      name = words.take(2).join(" ");
    }

    // ---------------- CATEGORY DETECTION ----------------
    if (desc.contains("AMAZON") || desc.contains("FLIPKART")) {
      category = "Shopping";
    } else if (desc.contains("SWIGGY") || desc.contains("ZOMATO")) {
      category = "Food";
    } else if (desc.contains("ATM")) {
      category = "Cash Withdrawal";
    } else if (desc.contains("SAL")) {
      category = 'Income';
    } else if (desc.contains("NETFLIX") || desc.contains("SPOTIFY")) {
      category = "Subscription";
    } else if (desc.contains("UBER") || desc.contains("OLA")) {
      category = "Travel";
    }

    // ---------------- FINAL MAP ----------------
    return {
      "type": type,
      "name": name,
      "ref": ref,
      "category": category,
      "direction": direction,
      "mode": mode,
      "bank": bank,
      "raw": original,
      "cleaned": desc,
      "timestamp": DateTime.now().toIso8601String(), // optional
    };
  }

  // Marchant name extracted
  String extractMerchantName(String desc) {
    String upper = desc.toUpperCase();

    // Step 1: Clean string
    String cleaned = upper.replaceAll(RegExp(r'[^A-Z0-9/]'), ' ');

    // Step 2: Split by / and space
    List<String> parts = cleaned
        .split(RegExp(r'[\/ ]+'))
        .where((e) => e.isNotEmpty)
        .toList();

    // Step 3: Identify reference number index
    int refIndex = parts.indexWhere((e) => RegExp(r'^\d{6,}').hasMatch(e));

    if (refIndex == -1) return "Unknown";

    // Step 4: Ignore keywords & bank codes
    List<String> ignore = [
      "UPI",
      "IMPS",
      "NEFT",
      "RTGS",
      'DR',
      'CR',
      "WDL",
      "TFR",
      "ATM",
      "POS",
      "ECOM",
      "PAYMENT",
      "TRANSFER",
      "AT",
    ];

    List<String> bankCodes = ["HDFC", "SBI", "ICICI", "AXIS", "YESB", "KOTAK"];

    // Step 5: Find first valid word after ref
    for (int i = refIndex + 1; i < parts.length; i++) {
      String word = parts[i];

      if (ignore.contains(word)) continue;
      if (bankCodes.contains(word)) continue;
      if (RegExp(r'^\d+').hasMatch(word)) continue;

      return word; // ✅ first valid merchant name
    }

    return "Unknown";
  }

  // trigger function and store it in map
  void triggerParse() {
    // ── Usage example ─────────────────────────────────────────────────────────

    // Load config from Firestore / Hive / local JSON — parser has zero merchant knowledge
    final config = ParserConfig.fromJson({
      'keywordCategories': {
        'SWIGGY': 'Food',
        'ZOMATO': 'Food',
        'AMAZON': 'Shopping',
        'NETFLIX': 'Subscriptions',
        'HPCL': 'Fuel',
      },
      'merchantAliases': {
        'SWIGGY': 'Swiggy',
        'AMAZON': 'Amazon',
        'NETFLIX': 'Netflix',
      },
    });

    final parser = TransactionParser(config);

    final result = parser.parse(transactionCTR.text);
    // → merchant: "Swiggy Foods", category: "Food", type: "UPI", direction: "DEBIT"
    parsedTransaction.assignAll(result);
  }
}
