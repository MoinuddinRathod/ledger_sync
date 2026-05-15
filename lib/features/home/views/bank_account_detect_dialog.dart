import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/service/local_storage_service.dart';
import '../../bank_account/controllers/bank_account_controller.dart';
import '../../../core/service/snackbar_service.dart';

class BankAccountDetectController extends GetxController {
  final String accountNumber;
  final String suggestedBankName;
  final String suggestedHolderName;
  final String initialBal;

  BankAccountDetectController({
    required this.accountNumber,
    required this.suggestedBankName,
    this.suggestedHolderName = '',
    this.initialBal = '',
  });

  final formKey = GlobalKey<FormState>();
  late final TextEditingController bankNameCtrl;
  late final TextEditingController holderNameCtrl;
  late final TextEditingController balanceCtrl;

  final accountTypes = ['Savings', 'Current'];
  final selectedAccountType = 'Savings'.obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    bankNameCtrl = TextEditingController(text: suggestedBankName);
    holderNameCtrl = TextEditingController(text: suggestedHolderName);
    balanceCtrl = TextEditingController(text: initialBal);
  }

  @override
  void onClose() {
    bankNameCtrl.dispose();
    holderNameCtrl.dispose();
    balanceCtrl.dispose();
    super.onClose();
  }

  Future<void> saveAccount() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    isLoading.value = true;

    try {
      final bankCtrl = Get.find<BankAccountController>();
      final model = await bankCtrl.createAccount(
        bankName: bankNameCtrl.text.trim(),
        plainNumber: accountNumber,
        holderName: holderNameCtrl.text.trim(),
        accountType: selectedAccountType.value,
        balance: double.tryParse(balanceCtrl.text) ?? 0.0,
      );

      isLoading.value = false;

      if (model != null) {
        Get.back(result: true); // Return true to close dialog first
        SnackbarService.showSuccess(
          title: 'Account Created',
          message: 'Successfully linked to your statement.',
        );
        bankCtrl.fetchBankAccounts(
          accountId: LocalStorageService.instance.accountId,
        );
      }
    } catch (e) {
      isLoading.value = false;
      SnackbarService.showError(
        title: 'Error',
        message: 'Failed to create account.',
      );
    }
  }
}

class BankAccountDetectDialog extends StatelessWidget {
  final String accountNumber;
  final String suggestedBankName;
  final String suggestedHolderName;
  final String initialBalance;

  const BankAccountDetectDialog({
    super.key,
    required this.accountNumber,
    required this.suggestedBankName,
    this.suggestedHolderName = '',
    this.initialBalance = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GetBuilder<BankAccountDetectController>(
      init: BankAccountDetectController(
        accountNumber: accountNumber,
        suggestedBankName: suggestedBankName,
        suggestedHolderName: suggestedHolderName,
        initialBal: initialBalance, // ✅ ADD THIS
      ),
      builder: (controller) {
        return Dialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: controller.formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 40,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      "New Bank Account Detected",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      "This statement belongs to an account we couldn't find in your profile. Please confirm details to add it.",
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Read-only Account Number
                  _buildInputLabel(theme, "Detected Account Number"),
                  TextFormField(
                    initialValue: accountNumber,
                    readOnly: true,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: _inputDecoration(theme, isDark, Icons.numbers),
                  ),
                  const SizedBox(height: 16),

                  _buildInputLabel(theme, 'Bank Name'),
                  TextFormField(
                    controller: controller.bankNameCtrl,
                    validator: (val) =>
                        val == null || val.isEmpty ? "Required" : null,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: _inputDecoration(
                      theme,
                      isDark,
                      Icons.account_balance,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildInputLabel(theme, 'Account Holder Name'),
                  TextFormField(
                    controller: controller.holderNameCtrl,
                    validator: (val) =>
                        val == null || val.isEmpty ? "Required" : null,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: _inputDecoration(
                      theme,
                      isDark,
                      Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInputLabel(theme, 'Account Type'),
                            Obx(
                              () => DropdownButtonFormField<String>(
                                value: controller.selectedAccountType.value,
                                dropdownColor: isDark
                                    ? const Color(0xFF1E213A)
                                    : Colors.white,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                ),
                                decoration: _inputDecoration(
                                  theme,
                                  isDark,
                                  Icons.category_outlined,
                                ),
                                items: controller.accountTypes.map((type) {
                                  return DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    controller.selectedAccountType.value = val;
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInputLabel(theme, "Balance"),
                            TextFormField(
                              controller: controller.balanceCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              validator: (val) {
                                if (val == null || val.isEmpty)
                                  return "Required";
                                if (double.tryParse(val) == null)
                                  return "Invalid";
                                return null;
                              },
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                              decoration: _inputDecoration(
                                theme,
                                isDark,
                                Icons.currency_rupee_sharp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Expanded(
                        child: Obx(
                          () => OutlinedButton(
                            onPressed: controller.isLoading.value
                                ? null
                                : () => Get.back(result: false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Obx(
                          () => ElevatedButton(
                            onPressed: controller.isLoading.value
                                ? null
                                : controller.saveAccount,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: controller.isLoading.value
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    "Save & Continue",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputLabel(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    ThemeData theme,
    bool isDark,
    IconData icon,
  ) {
    return InputDecoration(
      prefixIcon: Icon(
        icon,
        color: theme.colorScheme.primary.withValues(alpha: 0.7),
        size: 20,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF1A1C35) : const Color(0xFFFAFBFD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2A2D52) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade300, width: 1),
      ),
    );
  }
}
