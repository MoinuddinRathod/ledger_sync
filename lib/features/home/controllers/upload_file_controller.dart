import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/service/snackbar_service.dart';
import '../models/parsed_transaction_model.dart';
import '../parsers/bank_statement_parser.dart';
import '../parsers/parse_result.dart';
import '../parsers/sbi_parser.dart';
import '../../../routes/app_routes.dart';
import '../../bank_account/controllers/bank_account_controller.dart';
import '../views/bank_account_detect_dialog.dart';

enum FileUploadStatus { uploading, completed, failed }

class FileUploadItem {
  final String path;
  final String name;
  final int sizeInBytes;
  RxDouble progress;
  Rx<FileUploadStatus> status;

  FileUploadItem({
    required this.path,
    required this.name,
    required this.sizeInBytes,
    double initialProgress = 0.0,
    FileUploadStatus initialStatus = FileUploadStatus.uploading,
  }) : progress = initialProgress.obs,
       status = initialStatus.obs;

  String get sizeString {
    return _formatBytes(sizeInBytes);
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class UploadFileController extends GetxController {
  final RxList<FileUploadItem> uploadedFiles = <FileUploadItem>[].obs;
  List<ParsedTransactionModel> parsedTransactions = [];
  final RxBool isParsing = false.obs;

  /// Maximum size 55 MB
  final int maxSizeBytes = 55 * 1024 * 1024;

  Future<void> pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['csv', 'xls', 'xlsx'],
      );

      if (result != null) {
        for (var file in result.files) {
          if (file.path != null) {
            // Check size limits
            if (file.size > maxSizeBytes) {
              SnackbarService.showError(
                title: "File too large",
                message: "${file.name} exceeds the 55 MB limit",
              );
              continue;
            }

            final newItem = FileUploadItem(
              path: file.path!,
              name: file.name,
              sizeInBytes: file.size,
            );
            uploadedFiles.add(newItem);
            _simulateUpload(newItem);
          }
        }
      }
    } catch (e) {
      SnackbarService.showError(title: 'Error', message: "Failed to pick file");
    }
  }

  void removeFile(FileUploadItem item) {
    uploadedFiles.remove(item);
  }

  void retryUpload(FileUploadItem item) {
    item.status.value = FileUploadStatus.uploading;
    item.progress.value = 0.0;
    _simulateUpload(item);
  }

  void _simulateUpload(FileUploadItem item) {
    const totalDuration = Duration(seconds: 2);
    const steps = 100;
    final stepDuration = totalDuration.inMilliseconds ~/ steps;

    int currentStep = 0;
    Timer.periodic(Duration(milliseconds: stepDuration), (timer) {
      currentStep++;

      if (!uploadedFiles.contains(item)) {
        timer.cancel();
        return;
      }

      item.progress.value = currentStep / steps;

      if (currentStep >= steps) {
        timer.cancel();
        item.status.value = FileUploadStatus.completed;
        // Parse the file after upload completes
        _parseFile(item);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FILE PARSING
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _parseFile(FileUploadItem item) async {
    isParsing.value = true;

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      final BankStatementParser? detectedParser = await _detectParser(
        item.path,
      );
      if (detectedParser == null) {
        Get.back();
        SnackbarService.showError(
          title: 'Unsupported Format',
          message: 'Could not detect bank format. Please check the file.',
        );
        return;
      }

      final BankStatementParser parser = detectedParser;

      // Parse the file
      final ParseResult result = await parser.parse(item.path);

      if (Get.isDialogOpen ?? false) Get.back(); // Close loading dialog

      // Handle parse errors
      if (result.hasError) {
        SnackbarService.showError(
          title: "Parse Error",
          message: result.errorMessage!,
        );
        return;
      }

      // Handle empty file (allow opening-balance-only statements)
      if (result.isEmpty && !result.hasInitialBalance) {
        SnackbarService.showError(
          title: "Empty File",
          message: "File contains no transactions or opening balance.",
        );
        return;
      }
      String? bankAccountNumber;
      // Check if we detected an account number
      if (result.hasAccountNumber) {
        final bankCtrl = Get.find<BankAccountController>();
        final account = await bankCtrl.findAccountByNumber(
          result.accountNumber!,
        );
        final initialBal = result.currentBalance != null
            ? result.currentBalance!.toStringAsFixed(2)
            : (result.initialBalance != null
                  ? result.initialBalance!.toStringAsFixed(2)
                  : '');

        if (account == null) {
          // Account doesn't exist, show creation dialog
          final bool? success = await Get.dialog<bool>(
            BankAccountDetectDialog(
              accountNumber: result.accountNumber!,
              suggestedBankName: result.bankName ?? '',
              suggestedHolderName: result.accountName ?? '',
              initialBalance: initialBal,
            ),
            barrierDismissible: false,
          );
          if (success == true) {
            final bankCtrl = Get.find<BankAccountController>();

            final account = await bankCtrl.findAccountByNumber(
              result.accountNumber!,
            );
            bankAccountNumber = account?.encryptedAccountNumber;
            if (account != null) {
              bankCtrl.fetchBankAccounts(accountId: account.accountId);
            }
          }

          if (success != true) {
            // User cancelled account creation, abort navigation

            return;
          }
        } else {
          bankAccountNumber = account.encryptedAccountNumber;
        }
      }

      // Navigate to review transactions screen
      for (var txn in result.transactions) {
        txn.bankAccountNumber = bankAccountNumber;
      }
      parsedTransactions.assignAll(result.transactions);
      Get.toNamed(
        AppRoutes.reviewTransactions,
        arguments: {
          'transactions': result.transactions,
          'bankName': result.bankName ?? '',
          'fileName': item.name,
          'bankAccountNumber': bankAccountNumber,
          'parseResult': result,
        },
      );
    } catch (e) {
      Get.closeAllSnackbars();

      if (Get.isDialogOpen ?? false) Get.back(); // Close loading dialog
      SnackbarService.showError(
        title: 'Error',
        message: "Failed to parse file. Please check the format.",
      );
    } finally {
      isParsing.value = false;
    }
  }

  /// Returns the appropriate parser for the given bank name.
  /// Extend this method to support more banks in future.
  /// Tries each known parser and returns the first one that recognises the file.
  Future<BankStatementParser?> _detectParser(String filePath) async {
    final parsers = _allParsers();
    for (final parser in parsers) {
      if (await parser.canParse(filePath)) return parser;
    }
    return null;
  }

  /// Registry of all supported bank parsers.
  /// Add new parsers here as you support more banks.
  List<BankStatementParser> _allParsers() {
    return [
      SbiParser(),
      // HdfcParser(),
      // IciciParser(),
      // AxisParser(),
    ];
  }
}
