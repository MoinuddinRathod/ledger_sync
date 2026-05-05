import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/service/dialog_service.dart';
import '../../../routes/app_routes.dart';
import '../controllers/bank_account_controller.dart';
import '../models/bank_account_model.dart';

class BankAccountsScreen extends GetWidget<BankAccountController> {
  const BankAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize controller if not already done in bindings
    Get.put(BankAccountController());

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencyFormatter = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 2,
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        title: Text(
          'My Accounts',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        onPressed: () {
          controller.initForm(null); // Null means Add mode
          Get.toNamed(
            AppRoutes.addEditBankAccountScreen,
            arguments: {"accountId": null},
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      ),
      body: Obx(() {
        if (controller.bankAccounts.isEmpty) {
          return _buildEmptyState(theme);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          itemCount: controller.bankAccounts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final account = controller.bankAccounts[index];
            return _buildAccountCard(
              context,
              theme,
              isDark,
              account,
              currencyFormatter,
            );
          },
        );
      }),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    BankAccountModel account,
    NumberFormat formatter,
  ) {
    // Generate a deterministic color for the logo based on the bank name length
    final colors = [
      Colors.deepPurpleAccent,
      Colors.redAccent,
      Colors.green,
      Colors.orange,
      Colors.blue,
    ];
    final logoColor = colors[account.bankName.length % colors.length];

    // Adaptive colors based on the dashboard card reference
    final topBgColor = isDark
        ? const Color(0xFF2A2D52)
        : const Color(0xFFE4E6FF);
    final bottomBgColor = isDark ? const Color(0xFF1A1C35) : Colors.white;

    final titleColor = theme.colorScheme.onSurface;
    final subtitleColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final balanceColor = theme.colorScheme.onSurface;
    final holderColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: () {
        Get.toNamed(
          AppRoutes.transactionsScreen,
          arguments: {'encryptedAccountNumber': account.encryptedAccountNumber},
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // --- TOP HALF: Bank Info & Actions ---
              Container(
                color: topBgColor,
                padding: const EdgeInsets.only(
                  left: 16,
                  top: 12,
                  bottom: 12,
                  right: 8,
                ),
                child: Row(
                  children: [
                    // Simulated blurred bank logo
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: logoColor.withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: logoColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.bankName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 2),

                          Obx(() {
                            final encryptedKey = account.encryptedAccountNumber;

                            final isVisible =
                                controller.accountVisibility[encryptedKey] ??
                                false;

                            final isLoading = controller.isRevealing.contains(
                              encryptedKey,
                            );

                            String displayText;

                            if (isVisible) {
                              displayText =
                                  controller.revealedNumbers[encryptedKey] ??
                                  '****';
                            } else {
                              displayText = controller.maskedDisplay(
                                account.lastFourDigits,
                              );
                            }

                            return Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    displayText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: titleColor.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),

                                // 👁 Eye button
                                isLoading
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : IconButton(
                                        icon: Icon(
                                          isVisible
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          controller.toggleVisibility(
                                            encryptedKey,
                                          );
                                        },
                                      ),
                              ],
                            );
                          }),

                          const SizedBox(height: 2),

                          Text(
                            account.accountType,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Delete Button
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: Colors.red.shade400,
                      onPressed: () {
                        DialogService.showDeleteDialog(
                          onConfirm: () {
                            controller.deleteBankAccount(
                              encryptedAccountNumber:
                                  account.encryptedAccountNumber,
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),

              // --- BOTTOM HALF: Balance & Account Holder ---
              Container(
                color: bottomBgColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatter.format(account.currentBalance),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: balanceColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            account.accountHolderName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: holderColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Visual cue that the card is editable
                    IconButton(
                      icon: const Icon(Icons.edit_note_sharp, size: 20),
                      color: subtitleColor,
                      onPressed: () {
                        controller.initForm(account);
                        Get.toNamed(
                          AppRoutes.addEditBankAccountScreen,
                          arguments: {
                            "accountId": account.encryptedAccountNumber,
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No Accounts Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your bank accounts to track\nyour balances easily.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
